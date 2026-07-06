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
