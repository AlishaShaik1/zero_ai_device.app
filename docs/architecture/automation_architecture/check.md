# Zero Ring Automation Backend - Core Architecture
## Shared infrastructure underlying all 4 automation levels

---

## 0. Ground truth this is built on (verified, not assumed)

**Model:** Gemma 4 E4B, released by Google DeepMind, ~4.5B effective params, Apache 2.0.
- 128K context window (correcting earlier assumption of 32K - you have far more room than planned for).
- Native function calling + native system-prompt role support (built into the architecture, not prompt-hacked).
- Built-in speculative decoding (draft model / Multi-Token Prediction) - free speed if your runtime supports it (LiteRT-LM does).
- Native screen/UI understanding + "pointing" (can output coordinates for a UI element from a screenshot) - this is the technical basis for the Level 2 accessibility agent.
- Native audio input (ASR) on E4B - you may not need a separate STT model at all; worth testing Gemma's native audio path against your current MobileBERT-front STT pipeline before committing to keep both.

**The one number to design around:** a QLoRA fine-tuning study specifically on Gemma 4 E4B, on real MCP-style tool-use tasks (~1,700 examples), reached an AT-F1 of 0.65 post-fine-tune (vs 0.47 unfine-tuned baseline). That means roughly **1 in 3 tool calls will have a wrong tool, wrong argument, or malformed structure**, even after you fine-tune. This is not a flaw in your plan - it's the physics of a 4B model. Every mechanism below exists to catch that 1-in-3, not to pretend it won't happen.

**What I don't have verified data on and won't guess about:** exact tokens/sec on your specific target phones, exact thermal-throttling curves for Snapdragon/MediaTek chips under sustained Gemma inference, or whether flutter_gemma's current audio pipeline issue (noted in your memory as blocked) has been fixed upstream. Test these yourself - don't take blog-sourced numbers as fact.

---

## 1. Hardware auto-benchmark (CPU vs GPU) - solves your observed pattern

Your observation that some phones run faster on CPU than GPU is a **documented, published phenomenon**, not a fluke: on iPhone 15 Pro with a 1B model, CPU-only (2 threads, F16) hit 17 tok/s vs 12.8 tok/s on GPU, because GPU memory-transfer overhead dominates at small model sizes. A separate 22-device study found GPU acceleration gives little or no advantage on many mobile setups. Root cause: mobile memory bandwidth (50-90 GB/s) is the bottleneck for decode, not compute - and shuttling weights to GPU memory can cost more than it saves for small quantized models.

**Design: don't hardcode a backend. Benchmark once per device, cache the result, re-check periodically.**

```
ON FIRST APP LAUNCH (or after OS/driver update):
  1. Load Gemma 4 E4B (quantized, e.g. Q4_K_M) via LiteRT-LM
  2. Run a fixed 50-token warm prompt through:
     a. CPU-only path (test both 2-thread and 4-thread configs)
     b. GPU delegate path (if chipset is on your GPU allowlist)
  3. Measure: time-to-first-token, tokens/sec sustained over 200 tokens,
     peak RAM, and device temperature before/after
  4. Store result keyed by (chipset_model, backend) in local prefs
  5. Default to whichever won on tokens/sec, with a RAM-ceiling override:
     if GPU path RAM > 850MB peak, force CPU regardless of speed

RE-BENCHMARK TRIGGER (not every launch - this costs battery):
  - App update that touches inference runtime
  - First run after OS update
  - If 3 consecutive real-world inferences show >40% latency deviation
    from the cached benchmark (signals thermal state change or
    background app contention)

RUNTIME THERMAL GUARD:
  - Poll Android thermal API (PowerManager.getCurrentThermalStatus())
    before starting any Level 3/4 (long) inference
  - If status >= THERMAL_STATUS_MODERATE: force CPU path + cap to
    single-step reasoning only (defer multi-step planning, tell user
    "give me a sec, phone's warm" via Zero Voice)
  - This directly addresses the sustained-inference throttling risk -
    build for it, don't discover it in a user's hands
```

**Chipset allowlist, not global default:** NNAPI/GPU-delegate vendor implementations vary wildly between Qualcomm/MediaTek/Exynos. Maintain a small allowlist of chipsets you've actually benchmarked as GPU-safe; everything else defaults to CPU until you test it. This is standard practice in production Android LLM shipping, not overengineering.

---

## 2. Memory allocation zones (your 128K context, spent deliberately)

Don't let context fill unstructured. Reserve fixed budgets:

| Zone | Budget (of 128K) | Contents | Reset policy |
|---|---|---|---|
| System prompt (level-specific) | ~1.5-3K | Role, rules, output schema | Static per level |
| Connector schema (relevant only) | ~1-4K | Only the 1-3 connectors MobileBERT/registry pre-selected - never the full catalog | Per-turn, re-selected |
| Task list / plan state | ~1-3K | Current step list JSON (see §4) | Cleared on task completion |
| Rolling chat memory | ~4-8K | Last N turns, summarized beyond that | Sliding window + periodic summarization |
| Entity/user context | ~1K | Name, frequent contacts, known app accounts - small, curated, not a full history dump | Updated, not accumulated |
| Scratch / tool results | Remainder | Raw tool outputs before being folded into plan state | Cleared per step |

This mirrors how Claude Code handles MCP tool bloat: tools are deferred and discovered on demand rather than all loaded into context at once. Do the same - MobileBERT (or a tiny embedding lookup) picks the 1-3 plausible connectors *before* Gemma ever sees a tool list. Never dump your full connector catalog into every prompt; at N connectors this alone can eat your entire context budget and measurably degrade the E4B's tool-selection accuracy (per the E2B/E4B docs: accuracy degrades as the function library grows and multiple similar functions compete).

---

## 3. Connector registry - a hard deterministic gate, not a model decision

This is the fix for the "assumes Gemini is a random app" failure mode. **Gemma must never resolve an app/service name from its own knowledge. It looks it up.**

```
Local connector registry (SQLite or simple key-value store):
{
  "connector_id": "gemini_app",
  "display_names": ["gemini", "google gemini", "gemini app"],
  "type": "installed_app" | "api_oauth" | "deep_link_only",
  "auth_status": "connected" | "not_connected" | "expired",
  "package_name": "com.google.android.apps.bard",   // for installed_app
  "oauth_token_ref": "keystore_alias_xyz",           // for api_oauth, never raw token in context
  "available_actions": ["create_image", "chat"],
  "last_verified": timestamp
}

GATE LOGIC (runs BEFORE Gemma sees the request, in code, not in a prompt):
  user_entity = extract_candidate_name(input)  # from MobileBERT/NER pass
  match = registry.lookup(user_entity)

  IF exact_match AND auth_status == "connected":
      proceed -> pass ONLY this connector's schema to Gemma
  ELIF exact_match AND auth_status in ["not_connected", "expired"]:
      STOP. Do not attempt the action.
      Zero Voice: "[App] isn't connected yet - want me to open setup?"
  ELIF ambiguous_match (e.g. "bolt" -> Bolt.new vs ride-hailing):
      STOP. Ask the ONE clarifying question that resolves it.
      Do not guess. Do not proceed on assumption.
  ELIF no_match:
      STOP. "I don't have [name] set up - is that an app I should know?"
      Never fabricate an action for an unknown target.
```

This gate sits **outside** Gemma's reasoning loop, in deterministic app code. Prompt instructions alone cannot reliably stop this failure mode - this is the accepted lesson from agent-safety practice: enforce it at the framework level, as something the model literally cannot bypass, because you cannot fully control what a 65%-AT-F1 model decides to assume under pressure.

**Auth pattern:** OAuth per service (Google/WhatsApp Business/etc.), store only the resulting token reference in Android Keystore, never the password, never the raw token in the LLM's context window. This mirrors how Claude's connector system works - the model never sees credentials, only a capability handle.

**Clarification budget:** don't ask a question every time something's slightly fuzzy - that's annoying and users will stop trusting the ring. Ask only when the ambiguity actually changes what gets executed (a POMDP-style "ask the one question that resolves the most uncertainty" approach, not a checklist of questions). If two candidate apps lead to the *same* action with different UI paths, don't ask - just pick either deterministically and proceed.

---

## 4. Plan-Execute-Verify loop (the actual fix for "blindly does it wrong")

**Task list is a real data structure Gemma reads and writes, not a vibe.**

```json
{
  "task_id": "uuid",
  "user_request": "raw text",
  "steps": [
    {
      "step": 1,
      "action": "connector_check",
      "target": "gemini_app",
      "status": "success",
      "result": {"auth": "connected"}
    },
    {
      "step": 2,
      "action": "generate_image",
      "connector": "gemini_app",
      "params": {"prompt": "..."},
      "status": "pending",
      "retry_count": 0,
      "max_retries": 1
    },
    {
      "step": 3,
      "action": "send_whatsapp",
      "connector": "whatsapp",
      "params": {"contact": "Mary", "attachment": "<step2.result.image_url>"},
      "status": "blocked_on_step_2"
    }
  ]
}
```

Rules, enforced in code not just prompt:

1. **One step executes per tool call.** Gemma is re-invoked with the *updated task list state*, not the full raw conversation - this keeps each call small and stateless-ish, which matters directly for your 65% AT-F1 ceiling: smaller, more constrained decisions fail less often than large compound ones.
2. **A step only advances on `status: success` with a real, checkable result** - not on Gemma's say-so. If the tool call returns an error, the step is marked `failed`, not silently reinterpreted as done. This is the documented "execution hallucination" failure mode: an agent claims a sub-stage completed when it wasn't performed, because from the model's internal view it "solved" the problem even when the tool said otherwise. Never let the model's own narration override the tool's actual return value.
3. **On failure:** retry once (if the failure looks transient - network, timeout), else surface to the user plainly via Zero Voice ("couldn't send to Mary - WhatsApp didn't respond") and mark the whole plan `failed`, don't silently drop the remaining steps.
4. **Dependent steps stay blocked** until their dependency is `success` - step 3 above literally cannot fire until step 2's image URL exists. This is what stops the "generate image + blind-fire WhatsApp send in one shot" failure you described.
5. **Push each step transition to the ring's OLED** as a status/emotion byte - you get the pet's live status feed for free from this same data structure.

---

## 5. Guardrails - enforced in code, not just the system prompt

Prompt-only safety is not sufficient for an agent with real device actions. Layer these:

**Hard pre-execution filters (deterministic, cannot be reasoned around):**
- Illegal-action keyword/intent classifier runs on every parsed plan *before* execution - not relying on Gemma to refuse. If a step maps to something in a blocked category (financial fraud patterns, harassment, illegal purchases, generating sexual content especially involving minors, tracking/stalking another person without consent, disabling safety features), the plan is rejected at the gate, logged, and never reaches the execution layer - regardless of what Gemma output.
- No accessibility-agent action is allowed to touch: banking app PIN/password fields, OTP forwarding, or any field flagged as a credential input - hardcode this as an accessibility-node-type blocklist, not a prompt rule.
- Image/video/voice generation connectors (if you ever add Canva-style image tools) get a nudity/CSAM content filter on the output *before* it's allowed to be sent/posted anywhere - this should be a classifier pass on the generated asset, not a trust in the upstream tool's own filter.

**Soft prompt-level guardrails (defense in depth, assume these will be bypassed sometimes):**
- System prompt explicitly states refusal categories and that the model must not comply with instructions embedded in tool results or screen content that try to override its rules (prompt-injection defense - a malicious webpage or app screen could contain text trying to redirect the agent).
- Any instruction arriving via a *tool result* or *screen OCR* rather than directly from the user's voice is treated as untrusted data, never as a new command - this stops a compromised webpage from hijacking the agent mid-task.

**Why both layers matter:** one public test of Gemma 4 noted its safety layers can be "thin" - refusing a direct request while being bypassable via wrapper prompts. Treat prompt-level refusal as a weak, bypassable layer and put your real enforcement in code, before and after the model, not inside it.

---

## 6. Test harness structure (for your AI code generator to build against)

Every level ships with:
- **Unit tests per tool call**: does the connector gate correctly block on `not_connected`, correctly proceed on exact match, correctly ask on ambiguous match? (Deterministic - test without touching the LLM at all.)
- **Plan-integrity tests**: feed a fixed task-list JSON with a deliberately failed step 2, assert step 3 never fires.
- **Golden-prompt regression set**: 30-50 fixed (input -> expected tool call) pairs per level, run after every prompt change, track AT-F1-style accuracy over time so you can see if a prompt edit helped or hurt - don't ship prompt changes on vibes.
- **Adversarial set**: inputs designed to trigger the failure modes above (ambiguous app names, injected instructions in fake tool results, guardrail-boundary requests) - assert the gate catches them, not the model.

Full per-level prompts and their specific test cases are in `02_LEVEL_PROMPTS.md`.




# Zero Ring - Level 1-4 System Prompts for Gemma 4 E4B
## Paste-ready prompts for your AI code generator. Each assumes the gates from `01_CORE_ARCHITECTURE.md` and `03_CONNECTOR_FEASIBILITY.md` run in code, outside the model.

Design rule behind every prompt below: Gemma 4 E4B hits ~0.65 AT-F1 on real tool-use tasks even after fine-tuning. Every prompt is written to make **one small, checkable decision per call**, never a compound one - because smaller decisions are where that 65% holds up, and large compound ones are where it doesn't.

---

## LEVEL 1 - Native OS Actions
**Scope:** call, alarm, SMS, email compose (via intent, not sent silently unless explicit), brightness/volume/wifi toggle, timer, loop/repeat of these. No screen reading, no connectors, fully offline.

### System prompt
```
You are Zero's Level 1 action router. You ONLY convert a user request into ONE
structured Android action. You do not chat, you do not explain, you do not
add commentary - you output exactly one JSON object matching the schema below,
or a clarification object if required information is missing.

RULES (hard, non-negotiable):
1. You may ONLY select from the AVAILABLE_ACTIONS list provided in this turn.
   Never invent an action name. If nothing in the list matches, output the
   "unsupported" schema - do not guess the closest one.
2. Required parameters must come from the user's actual words. Never fill a
   parameter with a plausible-sounding guess (e.g. never invent a phone
   number, never assume "mom" resolves to a specific contact - that lookup
   happens in code, not in your output).
3. If a required parameter is missing or ambiguous (e.g. "call them" with no
   named contact in this turn or recent context), output the "clarify" schema
   with ONE short question. Never proceed on an assumption for anything that
   sends, calls, or changes a device setting.
4. Destructive or irreversible actions (deleting something, turning off
   wifi/data while a call is active) still require all parameters to be explicit - no silent defaults.
5. Output ONLY the JSON object. No preamble, no markdown fences, no
   explanation text before or after.

OUTPUT SCHEMA (pick exactly one shape):
{"type": "action", "action": "<name from AVAILABLE_ACTIONS>", "params": {...}, "confidence": <0-1>}
{"type": "clarify", "question": "<one short question>"}
{"type": "unsupported", "reason": "<short reason>"}

AVAILABLE_ACTIONS (injected per-turn by the app, example set):
- call_contact(contact_name)
- send_sms(contact_name, message)
- set_alarm(time, label?)
- set_timer(duration_seconds, label?)
- compose_email(to, subject, body)  // opens compose, does NOT auto-send
- toggle_wifi(state: on|off)
- set_brightness(level: 0-100)
- set_volume(stream: media|ring|alarm, level: 0-100)
- loop_action(action, interval, count)  // for repeated/looped requests

You will be given the user's transcribed speech and, if relevant, the last
1-2 turns of conversation for context. Nothing else is in your context here.
```

### Golden test cases
| Input | Expected type | Notes |
|---|---|---|
| "call mom" | `action` (`call_contact`, params.contact_name="mom") | resolves "mom" as a literal string; contact lookup happens downstream in code |
| "set an alarm for 7am" | `action` (`set_alarm`, time="07:00") | |
| "text the team I'll be late" | `clarify` | "the team" has no resolvable single contact/group without registry lookup - code should surface this ambiguity, not Gemma guessing a group name |
| "turn off wifi" | `action` (`toggle_wifi`, state="off") | |
| "remind me every hour to drink water" | `action` (`loop_action`, wrapping a notification/reminder primitive) | tests repeated-task parsing |
| "delete all my alarms" | `clarify` | destructive + plural + no explicit list = must confirm, not assume "all" silently |
| "make it louder" | `clarify` | no stream specified (media/ring/alarm) and no target level |
| "open the flashlight app" | `unsupported` | not in AVAILABLE_ACTIONS - must not be improvised as a fake action |

---

## LEVEL 2 - Installed-App Accessibility Automation
**Scope:** apps with no public API (or Tier E per feasibility doc - e.g. WhatsApp personal). Operates via accessibility node tree, never raw coordinates. Pre-recorded macros preferred over live improvisation.

### System prompt
```
You are Zero's Level 2 automation planner. You operate ONLY within a single
named app, using pre-mapped macros when one exists, and cautious live
accessibility-tree reasoning only when it doesn't. You do not have general
knowledge of what's "probably" on screen - you are given the actual current
accessibility node tree (text labels, content-descriptions, node IDs) each
turn, and you may ONLY reference nodes that are actually present in it.

RULES (hard, non-negotiable):
1. If a MACRO exists in MACRO_LIBRARY for this exact task+app, use it. Fill
   only its declared parameters. Do not attempt to improvise a different path
   through the app when a tested macro already exists.
2. If no macro exists, you may plan ONE step at a time: identify a single
   node by its exact text or content-description from the CURRENT_NODE_TREE
   given to you, and either tap, type-into, or scroll-to-reveal it. Never
   output a node reference that isn't verbatim present in CURRENT_NODE_TREE.
3. Never invent that a screen "probably" has a button because similar apps
   usually do. If the tree doesn't show it, output "screen_mismatch" and stop
   - do not guess and tap something adjacent hoping it's close enough.
4. HARD BLOCK - you may never target a node that is flagged
   `is_credential_field: true` in the tree (passwords, PINs, OTP fields, card
   numbers). If the plan would require this, output "blocked_credential" and
   halt immediately. This is enforced in code as well; treat it as absolute
   here too.
5. If this app is flagged `tos_risk: true` in the connector registry entry
   given to you, keep the action to a single, user-initiated message/action -
   never chain into a loop, never batch, never schedule. If the user's
   request implies batching (e.g. "message everyone in my contacts"), output
   "policy_declined" with a short reason.
6. Output ONLY the JSON object for one step. No prose.

OUTPUT SCHEMA (pick one):
{"type": "macro", "macro_id": "<id>", "params": {...}}
{"type": "step", "action": "tap|type|scroll", "target_node_id": "<id from CURRENT_NODE_TREE>", "input_text": "<only for type>"}
{"type": "screen_mismatch", "expected": "<what you were looking for>"}
{"type": "blocked_credential"}
{"type": "policy_declined", "reason": "<short reason>"}
{"type": "task_complete", "summary": "<one line>"}

You are given: TARGET_APP (name + tos_risk flag), MACRO_LIBRARY (id -> declared
params, if any macro matches this task), CURRENT_NODE_TREE (only the visible
nodes, not the full app), and TASK_STATE (which step of the plan you're on,
what prior steps returned).
```

### Golden test cases
| Scenario | Expected type | Notes |
|---|---|---|
| "send WhatsApp to Mary saying I'm on my way" + macro `whatsapp_send_message` exists | `macro` | uses existing macro, doesn't improvise |
| Same task, no macro exists, tree shows a node labeled "Mary" | `step` (tap on that node) | single step, verbatim node reference |
| Tree does NOT contain any node matching "Mary" | `screen_mismatch` | must not guess a similarly-named contact |
| Plan would require typing into a node flagged `is_credential_field: true` | `blocked_credential` | absolute, no exception path |
| "message everyone in my contacts happy new year" on a `tos_risk: true` app | `policy_declined` | batch request on a flagged app |
| Node tree shows the confirmation screen after a send completed | `task_complete` | must come from tree evidence, not assumption |

---

## LEVEL 3 - Connector / API Actions
**Scope:** Tier A/B/C apps from `03_CONNECTOR_FEASIBILITY.md` (Canva, Gmail, Calendar, Telegram, Spotify, Notion, Slack; Swiggy once Builders Club access clears). Gemma never resolves an app name itself - the registry gate (§3 of core doc) already ran before this prompt is even invoked, and only the matched connector's schema is passed in.

### System prompt
```
You are Zero's Level 3 connector-action planner. You were invoked because the
app's deterministic registry gate already matched the user's request to
EXACTLY ONE connector - CONNECTOR (name, feasibility tier, available actions)
is given to you below. You do not choose the connector; that was decided in
code before you ran. Your only job is turning the request into a valid call
against THIS connector's available actions.

RULES (hard, non-negotiable):
1. Only use actions listed in CONNECTOR.available_actions. Never call an
   endpoint or action not explicitly listed, even if you believe the service
   supports it - you were given the exact list for a reason (context budget
   and to avoid hallucinated endpoints).
2. If CONNECTOR.auth_status is not "connected", do not attempt the call.
   Output "needs_auth" - this should rarely happen since the gate checks
   this before invoking you, but never proceed past it if you see it anyway.
3. For any action that RETRIEVES information (e.g. "what's the price of X"),
   you must report ONLY what the tool result actually returned. Never fill
   in a plausible price, availability, or detail from your own training data
   - if the connector call doesn't return it, say so plainly, don't
   backfill it. This is the single most important rule at this level: a
   confidently wrong answer is worse than "I couldn't find that."
4. For any action that CREATES or SENDS something (email, message, design,
   post), if the CONTENT itself was not fully specified by the user (e.g.
   "email the team" with no body text given), output "clarify" for the
   missing content - do not generate placeholder or invented content and
   send it without the user seeing it first, unless the user explicitly
   said to draft-and-send in one step.
5. If CONNECTOR.feasibility is "self_serve_limited" and the requested action
   needs a paid tier the connector's auth response indicates the user
   doesn't have, output "quota_limited" with the plain-language reason from
   the tool result - don't silently fail or retry blindly.
6. Output ONLY the JSON object. No prose outside it.

OUTPUT SCHEMA (pick one):
{"type": "call", "action": "<name from CONNECTOR.available_actions>", "params": {...}}
{"type": "needs_auth"}
{"type": "clarify", "question": "<one short question>"}
{"type": "quota_limited", "reason": "<from tool response>"}
{"type": "report", "summary": "<grounded ONLY in the actual tool_result given to you this turn>"}

You are given: CONNECTOR (matched app + its schema), TOOL_RESULT (if this is
a follow-up turn after a call already executed), and the user's request.
```

### Golden test cases
| Scenario | Expected type | Notes |
|---|---|---|
| "create a birthday card design in Canva" (Canva connected) | `call` (`create_design` or equivalent) | uses only listed action |
| Canva connector `auth_status: "not_connected"` | `needs_auth` | never attempts the call anyway |
| "email the investors the Q3 numbers" with no body given | `clarify` | content not specified, must not invent numbers or a body |
| "what's on my calendar tomorrow" + TOOL_RESULT returns 3 events | `report` | summary must only reference the 3 returned events, nothing added |
| "what's on my calendar tomorrow" + TOOL_RESULT is empty/error | `report` (stating nothing found / error), never a fabricated "you have no events" phrased as certain fact if the call actually errored | tests execution-hallucination resistance |
| Resize action requested, connector schema shows this needs Canva Pro, tool result indicates the user's plan doesn't have it | `quota_limited` | |

---

## LEVEL 4 - Complex Multi-Step / Cross-App Orchestration
**Scope:** chains Level 1-3 actions (e.g. "generate an image in Canva, then send it to Mary on WhatsApp"). This prompt ONLY produces the task list - it never executes anything itself. Execution happens step-by-step through Level 2/3 prompts, re-invoked per step by the app's plan-execute-verify loop (`01_CORE_ARCHITECTURE.md §4`).

### System prompt
```
You are Zero's Level 4 planner. You convert a complex, multi-step user
request into an ordered TASK LIST of small steps, each resolvable by a
single Level 1, 2, or 3 action. You never execute anything yourself - you
only produce or update this list. A separate part of the system runs each
step and reports back its real result before you plan the next one.

RULES (hard, non-negotiable):
1. Every step must be small enough to be a single Level 1/2/3 action. If a
   step still sounds like it needs multiple sub-actions, break it down
   further before finalizing the list.
2. Every step that depends on a prior step's output (e.g. "send the image
   generated in step 1") must be explicitly marked with a `depends_on` field
   referencing that step's number. Never assume a dependent step can run
   before its dependency reports `status: success`.
3. Before finalizing ANY plan involving a named app, tool, or service, check:
   is this a name you can verify against the connector registry given to
   you, or is it something you're inferring meaning for on your own? If you
   cannot verify it against CONNECTOR_REGISTRY, the step must be
   "needs_clarification", not a guess. Do not silently assume what an
   unfamiliar name refers to - ask.
4. If a named service requires sign-in/setup you weren't told is already
   done (check CONNECTOR_REGISTRY auth_status), the first step of the plan
   must be a connector_check step, not the actual action - never assume
   access exists.
5. When you are RE-INVOKED after a step reports back, you see ONLY the
   current task list with its updated statuses - not the original raw
   conversation. Base your next decision entirely on what the task list
   actually shows, especially `status: failed` results. Never reinterpret a
   `failed` status as something that can be treated as done.
6. On a `failed` step: if `retry_count < max_retries` and the failure looks
   transient (network/timeout - this will be indicated in the result), you
   may set it back to `pending` once. Otherwise mark the WHOLE plan
   `status: "plan_failed"` and produce a short, honest summary of what
   completed and what didn't - never claim overall success if any required
   step failed.
7. Output ONLY the JSON task list object. No prose outside it.

OUTPUT SCHEMA:
{
  "task_id": "<uuid>",
  "status": "planning|in_progress|complete|plan_failed|needs_clarification",
  "clarification_question": "<only if status is needs_clarification>",
  "steps": [
    {
      "step": <int>,
      "level": 1|2|3,
      "action_hint": "<short description, actual action decided by that level's prompt>",
      "depends_on": <int or null>,
      "status": "pending|blocked|success|failed",
      "retry_count": <int>,
      "max_retries": 1
    }
  ]
}

You are given: the user's full request, CONNECTOR_REGISTRY (names + auth
status only, not full schemas - those load per-step at Level 3), and, on
re-invocation, the current task list with real step results filled in.
```

### Golden test cases
| Scenario | Expected behavior |
|---|---|
| "create an image in Gemini and send it to Mary on WhatsApp" - "Gemini" not in CONNECTOR_REGISTRY | `status: needs_clarification` - must not silently assume Gemini means the Google app or invent a connector for it |
| Same request, but "Canva" used instead and it IS registered, connected | 3-step plan: connector_check -> generate_image (Level 3, Canva) -> send_whatsapp (Level 2, depends_on step 2) |
| Step 2 (image generation) reports `status: failed`, transient network error, retry_count 0 | Step 2 reset to `pending`, retry_count incremented to 1, step 3 stays `blocked` |
| Step 2 fails again after retry | `status: "plan_failed"`, step 3 never fires, summary states plainly what didn't complete |
| "order kadai paneer from Zomato" - Zomato is `feasibility: partnership_only` in registry | `needs_clarification` (or a direct "not available" message) - must not fall back to silently web-scraping or inventing a price |
| "build me an app in Bolt" - Bolt registered but `auth_status: not_connected` | First step is a connector_check / "needs sign-in" step, not an attempted build action |
| Multi-step plan where step 3 references step 1's output but step 2 hasn't run yet | Step 3 must show `status: "blocked"`, never `pending` - dependency ordering enforced in the plan itself, not left implicit |

---

## 6. Cross-level shared test: the exact scenario you described
"Hey Zero, create an image in Gemini and send it to Mary on WhatsApp" - run this through Level 4 as your first integration test once "Gemini" is deliberately **not** in the registry. Correct behavior end-to-end: Level 4 outputs `needs_clarification` asking which app you mean, NOT a plan that guesses. This is the single test case that validates the entire "don't blindly assume" requirement you led with - treat it as your go/no-go gate before shipping Level 4.
