# Zero Ring — Complete Automation Architecture
## Single-file master reference. Paste this into any AI to resume work.
## Last updated: 2026-07-02

---

## WHAT THIS IS

Zero Ring is an AI assistant wearable (smart ring) + Android app. The app runs:
- **MobileBERT** (`model.tflite`) — 5–15ms intent classifier. Outputs: SIMPLE or COMPLEX.
- **Qwen 0.6B Q8** (`qwen.gguf`) — Level 1 fast OS actions. ~400 token context. Local, offline.
- **Gemma 4 E4B** (quantized, LiteRT-LM) — Levels 2–4. 128K context. Native function calling. Local, offline.
- **Zero Search Gateway** (`https://search-server-theta.vercel.app`, key: `zerotech1234`) — Real-time web search for facts.
- **Connector Marketplace Backend** (Vercel + Supabase, to be deployed) — 150+ app connectors via OAuth 2.1 per-user tokens.

**The single number to build around:** Gemma 4 E4B reaches AT-F1 of 0.65 on real tool-use tasks even after fine-tuning. ~1 in 3 tool calls will be wrong. Every gate and check below exists to catch that 1-in-3 in code — not to rely on the model refusing on its own.

---

## ROUTING LOGIC (how a user request flows)

```
User voice/text input
        │
        ▼
[GUARDRAILS] — deterministic code gate
  • Illegal-action blocklist (hardcoded, not LLM)
  • Credential field blocklist (never touch passwords/PINs/OTPs)
  • No bypass path
        │
        ▼
[MobileBERT classifier — model.tflite]
  • SIMPLE (>0.85 confidence) → Qwen 0.6B → Level 1
  • COMPLEX → connector keyword check → Level 2, 3, or 4 (Gemma)
  • Keyword override: if input contains known connector alias → skip to Level 3 gate
        │
  ┌─────┴──────────────────────────────────┐
  │ SIMPLE                                 │ COMPLEX
  ▼                                        ▼
[Qwen 0.6B — Level 1]            [CONNECTOR REGISTRY GATE]
  • OS actions only                 • Looks up entity name in registry
  • Outputs strict JSON             • Connected → Level 3 (API)
  • If fact/news → search           • Not installed → Level 2 (accessibility)
  • Never hallucinate               • Unknown → ask user, never guess
                                    • Complex/chained → Level 4 planner
```

---

## LEVEL 1 — Native OS Actions (Qwen 0.6B)

**Scope:** call, SMS, alarm, timer, email compose, wifi/bluetooth/DND/airplane toggle, brightness, volume, screenshot, open app, loop/repeat any of these. 100% offline, no screen reading, no connectors.

**How it works:** Qwen receives a compressed system prompt (under 400 chars total) and outputs exactly one JSON action. If a fact/news question is detected, it outputs `{"type":"search","query":"..."}` instead of hallucinating. The app then calls the Zero Search Gateway and returns the real answer.

### Qwen System Prompt (under 400 chars — keep it this short):
```
You are Zero. Output ONE JSON only. No explanation.
Actions: call_contact, send_sms, set_alarm, set_timer, compose_email, toggle_wifi, toggle_bluetooth, toggle_dnd, toggle_airplane, set_brightness, set_volume, open_app, take_screenshot, loop_action.
Fact/news/latest → {"type":"search","query":"<terms>"}
Missing param → {"type":"clarify","question":"<ask>"}
Unsupported → {"type":"unsupported","reason":"<why>"}
Action → {"type":"action","action":"<name>","params":{...}}
User: [INPUT]
```

### Level 1 Golden Tests (assert exact JSON — these are unit tests):
| Input | Expected output |
|---|---|
| "call mom" | `{"type":"action","action":"call_contact","params":{"contact_name":"mom"}}` |
| "set alarm 7am" | `{"type":"action","action":"set_alarm","params":{"time":"07:00"}}` |
| "text the team I'm late" | `{"type":"clarify","question":"Who should I text?"}` — "the team" is ambiguous |
| "delete all alarms" | `{"type":"clarify","question":"Delete all alarms?"}` — destructive, must confirm |
| "who is CEO of Nvidia" | `{"type":"search","query":"CEO of Nvidia 2024"}` — never guess from training data |
| "open flashlight app" | `{"type":"unsupported","reason":"flashlight is not in available actions"}` |
| "remind me every hour to drink water" | `{"type":"action","action":"loop_action","params":{"action":"set_timer","interval":3600}}` |

---

## LEVEL 2 — Installed-App Accessibility Automation (Gemma 4 E4B)

**Scope:** Apps with no public API (WhatsApp personal, Instagram DMs, etc.). Gemma reads the live Android Accessibility Node Tree — the actual visible UI nodes — and plans one tap/type/scroll at a time. Pre-recorded macros are always preferred over live improvisation.

**Hard code gates (outside Gemma — in app code):**
- Nodes flagged `is_credential_field: true` → BLOCKED. Gemma never even sees them.
- Apps flagged `tos_risk: true` → single action only. No loops, no batch sends.

### Level 2 System Prompt (injected into Gemma):
```
You are Zero's Level 2 automation planner. You operate ONLY within a single
named app, using pre-mapped macros when one exists, and cautious live
accessibility-tree reasoning only when it doesn't. You do not have general
knowledge of what's "probably" on screen — you are given the actual current
accessibility node tree (text labels, content-descriptions, node IDs) each
turn, and you may ONLY reference nodes that are actually present in it.

RULES (hard, non-negotiable):
1. If a MACRO exists in MACRO_LIBRARY for this exact task+app, use it. Fill
   only its declared parameters. Never improvise a different path when a
   tested macro exists.
2. If no macro exists, plan ONE step at a time: identify a single node by its
   exact text or content-description from CURRENT_NODE_TREE, and tap, type,
   or scroll-to-reveal it. Never reference a node not in CURRENT_NODE_TREE.
3. Never invent that a screen "probably" has a button. If it's not in the
   tree, output "screen_mismatch" and stop.
4. HARD BLOCK: never target a node flagged is_credential_field: true.
   Output "blocked_credential" and halt. No exception path.
5. If app is tos_risk: true — one action only, never chain or batch.
   "Message everyone" → output "policy_declined" with reason.
6. Output ONLY the JSON object for one step. No prose.

OUTPUT SCHEMA (pick one):
{"type":"macro","macro_id":"<id>","params":{...}}
{"type":"step","action":"tap|type|scroll","target_node_id":"<verbatim from CURRENT_NODE_TREE>","input_text":"<only for type>"}
{"type":"screen_mismatch","expected":"<what you looked for>"}
{"type":"blocked_credential"}
{"type":"policy_declined","reason":"<short>"}
{"type":"task_complete","summary":"<one line>"}

INJECTED EACH TURN: TARGET_APP (name + tos_risk flag), MACRO_LIBRARY,
CURRENT_NODE_TREE, TASK_STATE (current step + prior results).
```

### Level 2 Golden Tests:
| Scenario | Expected |
|---|---|
| "Send WhatsApp to Mary saying I'm on my way" + macro `whatsapp_send_message` exists | `{"type":"macro","macro_id":"whatsapp_send_message","params":{"contact":"Mary","message":"I'm on my way"}}` |
| No macro, tree shows node labeled "Mary" | `{"type":"step","action":"tap","target_node_id":"<exact node id>"}` |
| "Mary" NOT in node tree | `{"type":"screen_mismatch","expected":"contact named Mary"}` |
| Plan requires typing into `is_credential_field: true` node | `{"type":"blocked_credential"}` |
| "message all my contacts happy new year" on WhatsApp (tos_risk: true) | `{"type":"policy_declined","reason":"Cannot batch-message on WhatsApp — one message per user request only"}` |

---

## LEVEL 3 — Connector / API Actions (Gemma 4 E4B)

**Scope:** Apps connected via OAuth 2.1 per-user tokens (Gmail, Canva, Notion, Slack, GitHub, Spotify, etc.). The Connector Registry Gate runs FIRST in code — it selects the matched connector, verifies auth status, then passes ONLY that connector's schema to Gemma. Gemma never chooses the connector.

**How connectors work (critical — this is the MCP model):**
- You (developer) register one OAuth app on each service's developer portal (e.g. Google Cloud Console).
- When a Zero Ring user taps "Connect" on Gmail in the marketplace, your Vercel server initiates OAuth 2.1 PKCE — the user signs into THEIR OWN Gmail account.
- Your server stores THEIR access token (encrypted) in Supabase, linked to their user_id.
- When Gemma calls `send_email`, your Vercel `api/execute.js` fetches their token, auto-refreshes if expired, and makes the Gmail API call as THEM — not as you.
- You never share your developer credentials. Every action is authenticated as the individual user.

### Level 3 System Prompt (injected into Gemma):
```
You are Zero's Level 3 connector-action planner. The registry gate already
matched the user's request to EXACTLY ONE connector. You do not choose the
connector — that was decided in code before you ran. Your only job is turning
the request into a valid call against THIS connector's available actions.

RULES (hard, non-negotiable):
1. Only use actions in CONNECTOR.available_actions. Never invent an action
   name or endpoint even if you believe the service supports it.
2. If CONNECTOR.auth_status is not "connected", output "needs_auth" and stop.
3. For RETRIEVAL actions: report ONLY what tool_result actually returned.
   Never fill in prices, availability, or data from your training knowledge.
   A confident wrong answer is worse than "I couldn't find that."
4. For CREATE/SEND actions: if content was not fully specified by the user,
   output "clarify" — never generate placeholder content and send it.
5. If quota/tier limit is hit, output "quota_limited" with the plain reason
   from the tool response. Never retry blindly.
6. Output ONLY the JSON object. No prose.

OUTPUT SCHEMA (pick one):
{"type":"call","action":"<from CONNECTOR.available_actions>","params":{...}}
{"type":"needs_auth"}
{"type":"clarify","question":"<one short question>"}
{"type":"quota_limited","reason":"<from tool response>"}
{"type":"report","summary":"<grounded ONLY in actual tool_result>"}

INJECTED EACH TURN: CONNECTOR (matched app schema + auth_status),
TOOL_RESULT (if follow-up turn after execution), user request.
Each connector also injects its system_prompt_extension — specific rules
for that service (e.g. "Never call resize without checking user's Canva plan").
```

### Level 3 Golden Tests:
| Scenario | Expected |
|---|---|
| "Create a birthday card in Canva" (connected) | `{"type":"call","action":"create_design","params":{"prompt":"birthday card","format":"square"}}` |
| Canva `auth_status: notConnected` | `{"type":"needs_auth"}` |
| "Email the investors the Q3 numbers" (no body given) | `{"type":"clarify","question":"What should the email body say?"}` |
| "What's on my calendar tomorrow" + tool returns 3 events | `{"type":"report","summary":"<lists only those 3 events>"}` |
| Same but tool returns empty/error | `{"type":"report","summary":"Couldn't fetch calendar — got an error from Google"}` — NOT a fabricated "you have no events" |
| Canva resize on free plan | `{"type":"quota_limited","reason":"Resize requires Canva Pro — upgrade needed"}` |

---

## LEVEL 4 — Complex Multi-Step / Cross-App Orchestration (Gemma 4 E4B)

**Scope:** Chains of Level 1/2/3 actions (e.g. "search price of BTC then email it to John"). Gemma ONLY produces and updates a task list — it never executes anything. The app's Plan-Execute-Verify loop runs each step and reports real results back before Gemma plans the next.

**Key rules enforced in code (not prompt):**
- A step only advances on `status: success` with a real return value — never on Gemma's say-so.
- Dependent steps are blocked in the data structure until their dependency succeeds.
- On failure: retry once if transient, else mark whole plan `plan_failed` and surface honestly.
- Re-invocations pass ONLY the current task list JSON — not the raw conversation history.

### Level 4 System Prompt (injected into Gemma):
```
You are Zero's Level 4 planner. You convert a complex, multi-step user
request into an ordered TASK LIST of small steps, each resolvable by a
single Level 1, 2, or 3 action. You never execute anything — you only
produce or update this list. Each step is run by the app and its real
result is reported back before you plan the next one.

RULES (hard, non-negotiable):
1. Every step must be small enough for a single L1/L2/L3 action. If a step
   needs multiple sub-actions, break it down further.
2. Every step depending on prior output must have depends_on set to that
   step number. A dependent step CANNOT run before its dependency is success.
3. Before including any app/service in the plan, verify it against
   CONNECTOR_REGISTRY. If you cannot verify it, output needs_clarification —
   never assume what an unfamiliar name refers to.
4. If any service requires auth you weren't told is done, first step must be
   connector_check, not the action. Never assume access exists.
5. On RE-INVOCATION: you see ONLY the current task list with real statuses.
   Base decisions entirely on that — never reinterpret failed as done.
6. On failed step: retry once if transient. Otherwise: plan_failed with
   honest summary. Never claim success if any required step failed.
7. Output ONLY the JSON task list object. No prose.

OUTPUT SCHEMA:
{
  "task_id": "<uuid>",
  "status": "planning|in_progress|complete|plan_failed|needs_clarification",
  "clarification_question": "<only if needs_clarification>",
  "steps": [
    {
      "step": <int>,
      "level": 1|2|3,
      "action_hint": "<short description>",
      "connector_id": "<connector_id or null>",
      "depends_on": <step_number or null>,
      "status": "pending|blocked|success|failed",
      "result": null,
      "retry_count": 0,
      "max_retries": 1
    }
  ]
}

INJECTED EACH TURN: user's full request, CONNECTOR_REGISTRY (ids + auth
status only), and on re-invocation the current task list JSON.
```

### Level 4 Golden Tests:
| Scenario | Expected |
|---|---|
| "Create image in Gemini and send to Mary on WhatsApp" — "Gemini" NOT in registry | `{"status":"needs_clarification","clarification_question":"Which Gemini do you mean — the Google app or something else?"}` |
| Same with "Canva" registered + connected | 3 steps: connector_check(L3,Canva) → create_design(L3,Canva) → send_whatsapp(L2, depends_on:2) |
| Step 2 fails (network timeout), retry_count=0 | Step 2 reset to pending, retry_count=1, step 3 stays blocked |
| Step 2 fails again | `{"status":"plan_failed"}` — step 3 never fires |
| "Order from Zomato" — Zomato is partnershipOnly | `needs_clarification` or direct "not available" — never scrape or invent |

---

## CONNECTOR REGISTRY GATE (deterministic code — runs BEFORE Gemma)

```
// Pseudocode — lives in ConnectorRegistry.dart / app code, never in a prompt

function gateCheck(userInput):
  entity = extractEntityName(userInput)  // from MobileBERT NER or alias list
  match = registry.lookup(entity)        // exact + alias match

  if match AND match.auth_status == "connected":
    return { proceed: true, connector: match }  // pass schema to Gemma L3

  if match AND match.auth_status != "connected":
    return { stop: true, msg: "{match.displayName} isn't connected. Want me to set it up?" }

  if ambiguous_match (multiple connectors match):
    return { stop: true, msg: "Did you mean X or Y?" }  // one clarifying question

  if no_match:
    return { stop: true, msg: "I don't have {entity} set up." }
  // Never pass an unknown entity to Gemma. Never guess.
```

**Connector schema fields (stored in Supabase, served by Vercel):**
```json
{
  "connector_id": "gmail",
  "display_name": "Gmail",
  "aliases": ["mail", "email", "google mail"],
  "category": "communication",
  "feasibility": "selfServe",
  "auth_flow": "oauth2_pkce",
  "oauth_provider_name": "google",
  "oauth_authorization_url": "https://accounts.google.com/o/oauth2/v2/auth",
  "oauth_token_url": "https://oauth2.googleapis.com/token",
  "oauth_scopes": ["https://www.googleapis.com/auth/gmail.send", "https://www.googleapis.com/auth/gmail.readonly"],
  "description": "Send and read emails via the user's own Gmail account.",
  "tos_risk": false,
  "system_prompt_extension": "You may only call send_email or read_recent. Required params for send_email: to (string), subject (string), body (string). Required for read_recent: count (integer, max 20). If auth_error in tool_result, output needs_auth. Never fill in email content from training data — only report what tool_result contains.",
  "available_actions": [
    {
      "name": "send_email",
      "description": "Send an email from the user's Gmail account.",
      "http_method": "POST",
      "endpoint_template": "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      "params": {
        "to": {"type": "string", "required": true},
        "subject": {"type": "string", "required": true},
        "body": {"type": "string", "required": true}
      }
    },
    {
      "name": "read_recent",
      "description": "Read the user's most recent emails.",
      "http_method": "GET",
      "endpoint_template": "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults={count}",
      "params": {
        "count": {"type": "integer", "required": false, "defaultValue": 5}
      }
    }
  ]
}
```

---

## MEMORY / CONTEXT BUDGET (128K window — spent deliberately)

| Zone | Budget | Contents | Reset |
|---|---|---|---|
| System prompt (level-specific) | ~2K | Role, rules, output schema | Static per level |
| Connector schema (ONE matched connector) | ~2K | Only the 1 connector the gate selected | Per turn |
| Task list / plan state | ~2K | Current step list JSON | On task completion |
| Rolling chat memory | ~6K | Last N turns, summarized beyond | Sliding window |
| Entity/user context | ~1K | Name, frequent contacts, known accounts | Updated, not accumulated |
| Scratch / tool results | Rest | Raw API responses before folding into plan | Cleared per step |

**Critical:** Never dump the full 150-connector catalog into context. MobileBERT selects 1-3 plausible connectors BEFORE Gemma runs. Accuracy degrades as the function library grows — this is documented Gemma 4 behavior.

---

## GUARDRAILS (enforced in code — not in prompts)

**Hard pre-execution filters (deterministic — cannot be reasoned around):**
1. Illegal-action classifier on every parsed plan before execution — financial fraud, harassment, CSAM, stalking, disabling safety features → plan rejected at gate, never reaches LLM.
2. Accessibility node blocklist: `is_credential_field: true` nodes (passwords, PINs, OTPs, card numbers) → BLOCKED. Hardcoded, not a prompt rule.
3. Generated asset filter: any image/video from a creation connector passes a NSFW/CSAM classifier BEFORE it's allowed to be sent anywhere.

**Prompt-level guardrails (defense in depth — assume these can be bypassed):**
- System prompt states refusal categories.
- Instructions arriving via tool results or screen OCR are treated as untrusted data, never as commands — stops prompt injection via malicious web pages or app screens.

---

## HARDWARE BENCHMARK & THERMAL MANAGEMENT

On first launch: benchmark CPU-only vs GPU-delegate with a 50-token warm prompt. Measure tokens/sec + peak RAM + temperature. Cache result. Use whichever is faster UNLESS GPU RAM > 850MB — then force CPU.

Re-benchmark triggers: app update touching inference runtime, OS update, or 3 consecutive inferences showing >40% latency deviation from cached benchmark.

Thermal guard: poll `PowerManager.getCurrentThermalStatus()` before Level 3/4 inference. If status >= THERMAL_STATUS_MODERATE → force CPU path + single-step reasoning only. Tell user "give me a sec, phone's warm."

---

## SEARCH GATEWAY (facts + real-time data)

**URL:** `https://search-server-theta.vercel.app`  
**Header:** `X-API-Key: zerotech1234`  
**Endpoint:** `POST /search` with body `{"q": "query string"}`  
**Returns:** `{"answer": "...", "answer_confidence": 0.0-1.0, "provider_used": "..."}`

**Usage rules:**
- Qwen outputs `{"type":"search","query":"..."}` when detecting fact/news requests.
- Gemma can call search as a Level 3 connector tool (connector_id: `zero_search`).
- NEVER backfill a failed search with training data. If the gateway errors, say "I couldn't find that right now."

---

## BACKEND INFRASTRUCTURE (Vercel + Supabase)

**Vercel app:** `zero-connector-marketplace.vercel.app` (to be deployed)

**Key endpoints:**
- `GET /api/connectors?user_id=X&query=Y&category=Z` — catalog with user auth states merged
- `GET /api/connector/:id?user_id=X` — single connector with full system_prompt_extension
- `GET /api/oauth/start?connector_id=X&user_id=Y` — initiates OAuth 2.1 PKCE flow
- `GET /api/oauth/callback?code=X&state=Y` — exchanges code, saves encrypted token to Supabase
- `POST /api/execute` with `{user_id, connector_id, action, params}` — executes action using user's own decrypted/refreshed token
- `GET|DELETE /api/user-connections?user_id=X` — user's connected apps

**Supabase tables:**
- `connectors` — the 150-connector catalog (admin-managed)
- `user_connections` — per-user OAuth token store (access_token_encrypted, refresh_token_encrypted, token_expires_at, auth_status)

**Token security:**
- Tokens encrypted with AES-256-GCM before Supabase storage
- Auto-refresh via stored refresh_token when access_token expires
- Tokens NEVER appear in LLM context — only a capability handle (connector_id + user_id) passes through

---

## FLUTTER APP STRUCTURE (files that implement the above)

```
lib/
├── automation/
│   ├── models/
│   │   ├── connector_def.dart       # ConnectorDef, ConnectorAction, FeasibilityTier enums
│   │   └── task_models.dart         # TaskPlan, TaskStep with state machine
│   ├── routing/
│   │   └── intent_router.dart       # MobileBERT gate → Qwen or Gemma routing
│   ├── prompts/
│   │   ├── automation_prompts.dart  # All 4 level prompts as static strings + builders
│   │   └── qwen_prompts.dart        # Qwen-specific compact prompt builder
│   ├── services/
│   │   └── search_service.dart      # Zero Search Gateway HTTP client
│   ├── connector_registry.dart      # Local registry gate + remote fetch from Vercel
│   ├── connector_catalog.dart       # Fallback local catalog (used if server unreachable)
│   ├── task_executor.dart           # Plan-Execute-Verify loop
│   ├── guardrails_service.dart      # Pre-execution filter
│   ├── benchmark_service.dart       # CPU vs GPU benchmarking
│   └── memory_allocator.dart        # Context budget management
├── services/
│   └── marketplace_service.dart     # Fetches catalog, OAuth flow, auth state tracking
├── screens/
│   └── connectors_screen.dart       # Play Store-style marketplace UI
└── test/
    └── automation_core_test.dart    # Unit + golden prompt tests
```

---

## WHAT IS COMPLETE vs WHAT STILL NEEDS WORK

### ✅ Complete (code exists, committed to GitHub)
- MobileBERT intent classifier integration (`classifier_service.dart`)
- Intent router with keyword + model-based routing (`intent_router.dart`)
- All 4 level system prompts as injectable builders (`automation_prompts.dart`)
- Qwen compact prompt with search routing (`qwen_prompts.dart`)
- ConnectorDef model with systemPromptExtension field (`connector_def.dart`)
- TaskPlan/TaskStep state machine (`task_models.dart`)
- Plan-Execute-Verify loop skeleton (`task_executor.dart`)
- Guardrails service (`guardrails_service.dart`)
- ConnectorRegistry with remote fetch (`connector_registry.dart`)
- Zero Search Gateway HTTP client (`search_service.dart`)
- MarketplaceService — OAuth flow, catalog fetch, auth state (`marketplace_service.dart`)
- ConnectorsScreen — Play Store-style UI with categories, search, connect/disconnect
- Agent prompts for Kimi (150 connector research) and Cursor (Vercel backend build)

### ❌ Still Needed
1. **Vercel backend deployed** — give Cursor `prompts_for_agents/cursor_build_backend.md` → get URL → update `_baseUrl` in `marketplace_service.dart`
2. **150 connectors JSON in Supabase** — give Kimi `prompts_for_agents/kimi_150_connectors_research.md` → get JSON → paste into Supabase SQL editor
3. **OAuth apps registered** — one app per OAuth provider on their developer portal (Google Cloud Console, GitHub Settings, Slack API, etc.) → add client_id + client_secret to Vercel env vars
4. **task_executor.dart needs full implementation** — skeleton exists, needs: real Gemma inference call wiring, step result parsing, retry logic, BLE ring status push
5. **Level 2 accessibility engine** — needs `AccessibilityNodeProvider` to build real `CURRENT_NODE_TREE` from Android Accessibility Service
6. **Macro library** — Level 2 needs a starting set of tested macros for WhatsApp send, Instagram open, etc.
7. **BenchmarkService** — stub exists, needs real LiteRT-LM CPU/GPU timing calls

---

## INTEGRATION TEST (run this first when wiring up Gemma)

```
Test: "Hey Zero, create an image in Gemini and send it to Mary on WhatsApp"

Expected flow:
1. MobileBERT → COMPLEX
2. ConnectorRegistry gate → "Gemini" not found in registry
3. System stops at gate, asks: "Which Gemini do you mean?"
4. User never reaches Gemma Level 4
5. PASS: the gate prevented a hallucinated plan

This is the single go/no-go integration test for the entire architecture.
If "Gemini" is NOT in the registry and Gemma still produces a plan for it,
the gate is broken — fix before shipping any other feature.
```
