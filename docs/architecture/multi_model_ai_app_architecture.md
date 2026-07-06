# Comprehensive Technical Architecture: Multi-Model AI App Architecture

This document provides the definitive implementation plan and technical specifications for on-device multi-model management, routing, memory optimization, and lifecycle orchestration within the Zero Ring app.

---

## 1. Scope
This document defines the implementation architecture for a Flutter app that:
- Downloads AI models only during an explicit setup modal flow.
- Runs speech and reasoning with strict model lifecycle control.
- Routes reasoning requests between Qwen (simple) and Gemma (complex).
- Minimizes memory footprint by loading models just-in-time and unloading aggressively.

---

## 2. Current Code Mapping
Primary integration points in this repository:
- App entry and providers: `lib/main.dart`
- Routing shell: `lib/app.dart`
- Startup gate and navigation: `lib/screens/splash_screen.dart`
- Setup/download UI: `lib/screens/download_screen.dart`
- Download manager: `lib/services/download_service.dart`
- Download model catalog: `lib/models/download_model.dart`
- Runtime orchestrator: `lib/controllers/zero_controller.dart`
- Qwen adapter: `lib/ai/zero_nano_service.dart`
- Gemma adapter: `lib/ai/zero_prime_service.dart`
- TTS adapter: `lib/services/tts_service.dart`
- Model constants and URLs: `lib/utils/constants.dart`

---

## 3. Model Inventory and Version Contract
Use a manifest-first approach. Each model entry must include id, version, quantization/profile, file name, URL, sha256, min RAM tier, and fallback policy.

Required model set:
- **Whisper Medium**: Primary STT + Telugu to English translation.
- **Whisper Small Q5 (181 MB)**: Fallback profile for resource-constrained devices.
- **Qwen 0.6B GGUF**: Primary lightweight reasoning.
- **Gemma 4-E4B**: Complex reasoning and agentic workflows.
- **Google TTS**: Platform text-to-speech engine integration.

---

## 4. Modal-Based Download System (vs Bundling)
### Traditional Bundling
- Large APK/IPA size.
- Slow installs and app-store update friction.
- Higher first-launch storage pressure on all users.

### Modal Setup (Required)
- User enters app/login, then mandatory setup modal appears.
- Only selected/required artifacts are downloaded at runtime.
- Enables per-device profile selection (Whisper Medium vs Small Q5 fallback).

Implementation rules:
- Setup modal blocks home screen access until all mandatory artifacts are validated.
- Every downloaded file must pass size and SHA-256 checksum validation.

---

## 5. Authentication Integration
Auth and model setup are separate concerns with a hard gate between them.

Flow:
1. App starts.
2. Auth state resolves.
3. If not authenticated -> redirect to login.
4. If authenticated -> check model storage and manifest validation.
5. If setup incomplete -> present mandatory setup modal.
6. On setup success -> navigate to main app.

Logout behavior:
- Clears auth session tokens.
- Keeps downloaded models cached by default.
- Optional "Delete model data" action in settings.

---

## 6. Runtime Model Lifecycle Strategy & Memory Mutex

To ensure memory safety and maintain low latency, the app employs a strict **Just-In-Time (JIT)** loading and immediate unloading strategy. Models are not kept active in memory unless they are performing active inference.

```
       [ Wake Word / User Audio Input ]
                      │
                      ▼
             [ LOAD STT Model ] ──► (Whisper Medium )
                      │
                      ▼
             [ Perform STT Inference ]
                      │
                      ▼
             [ UNLOAD STT Model ] ──► (Free Memory)
                      │
                      ▼
          [ Evaluate Task Complexity ]
                 /         \
    (Simple)    /           \    (Complex)
               ▼             ▼
       [ LOAD Qwen ]     [ LOAD Gemma ]
               │             │
               ▼             ▼
          [ Inference ]   [ Inference ]
               │             │
               ▼             ▼
       [ UNLOAD Qwen ]   [ UNLOAD Gemma ] ──► (Free Memory)
                      │
                      ▼
             [ LOAD TTS Model ] ──► (Platform Speech Engine)
                      │
                      ▼
             [ Audio Synthesis ]
                      │
                      ▼
             [ UNLOAD TTS Model ] ──► (Free Memory)
```

### Whisper Unloading
* **Native Context Disposal**: Unloading Whisper invokes native destructor wrappers (`whisper_free`) to destroy the C/C++ memory context.

### GGUF Models Memory-Mapping (mmap)
* **Zero-Copy RAM**: The GGUF reasoning engines use memory mapping (`mmap = true`) via llama_cpp_dart native flags, mapping weights straight into virtual address memory.

### Google TTS Clarification
* **Platform TTS Integration**: The app uses platform built-in engines via `FlutterTts`, avoiding the high overhead of running an ONNX interpreter in RAM.

### Wake-Word Detection
* **Continuous Energy Detection**: Awake state is monitored via a dedicated, lightweight amplitude/energy envelope detector in `audio_service.dart`. Whisper remains dormant until triggered.

### Memory Mutex
* **Safe Mutex**: Instantiations use try-catch-finally blocks to ensure cleanup. A 5-second watchdog timer automatically invokes `forceCleanup()` in the event of an inference hang.

---

## 7. Decision Logic: Qwen vs. Gemma Routing

The routing logic classifies task complexity to optimize execution latency and device battery life.

```
                       [ Input Query Text ]
                                │
                                ▼
                 ( Contains complex keywords or )
                 (      token count > 120 ?     )
                            /         \
                   [YES]   /           \   [NO]
                          ▼             ▼
                    Route to GEMMA    Route to QWEN
                     (Complex UI)      (Simple UI)
```

### Classifier Logic
* **Keyword Matching**: Scans for advanced verbs (e.g., `order`, `buy`, `summarize`, `book`, `pay`, `upload`).
* **Length Check**: Any query exceeding 120 characters or an estimated 150 tokens automatically routes to the larger reasoning model (Gemma).
* **Model-based Fallback**: If Gemma fails to initialize due to memory pressure, route immediately to Qwen and add a clarifying prefix ("Analyzing this with quick brain: ...").

| Route Target | Criteria | Primary Purpose | Memory Limit |
|---|---|---|---|
| **Qwen 0.6B** | Simple commands, time check, music control, basic QA. | Quick latency responses, low context size. | ~450 MB RAM |
| **Gemma 4-E4B** | Agentic workflows (booking/ordering), long descriptions, multi-step. | High intelligence reasoning, tool actions. | ~2.7 GB RAM |

---

## 8. Memory Optimization Policies

To avoid OS termination via OOM (Out Of Memory) killers, we implement the following rules:

1. **Mutual Exclusion Invariant**:
   `Active(Whisper) + Active(Qwen) + Active(Gemma) <= 1`
2. **Aggressive Unload**:
   Unload Whisper immediately after transcription finalization. Unload TTS immediately after speech generation/playback completion.
3. **RAM Tier Selection**:
   * Always load and run **Whisper Medium** and allow routing dynamically to **Gemma 4-E4B** or **Qwen 0.6B** based on task complexity.

---

## 9. End-to-End Event Sequence

```
User          App UI / Auth          ModelLifecycleManager      Native Model (Whisper/LLM/TTS)
 │                  │                          │                              │
 ├─► Login/Open ───►│                          │                              │
 │                  ├─► Check Manifest ───────►│                              │
 │                  │   (Required models?)     │                              │
 │                  │◄─ Setup Modal required ──┤                              │
 │                  │                          │                              │
 │  (Setup Modal)   │                          │                              │
 ├─► Tap Download ─►├─► Download JIT ─────────►│                              │
 │                  │◄─ Download Finished ─────┤                              │
 │                  │                          │                              │
 │  (Normal Use)    │                          │                              │
 ├─► "Hey Zero" ───►├─► Wake word detected ────►│                              │
 │                  │                          ├─► Load Whisper ─────────────►│
 │                  │                          │◄─ Whisper Loaded ────────────┤
 │                  │                          ├─► Translate & Transcribe ───►│
 │                  │                          │◄─ Transcript Finalized ──────┤
 │                  │                          ├─► Unload Whisper ───────────►│
 │                  │                          ├─► Decide Route (Qwen/Gemma)  │
 │                  │                          ├─► Load Selected LLM ────────►│
 │                  │                          │◄─ LLM Loaded ────────────────┤
 │                  │                          ├─► Ask/Solve query ──────────►│
 │                  │                          │◄─ Text response generated ───┤
 │                  │                          ├─► Unload LLM ───────────────►│
 │                  │                          ├─► Load Google TTS ──────────►│
 │                  │                          ├─► Synthesize & Speak ───────►│
 │                  │                          │◄─ Audio completed ───────────┤
 │                  │                          ├─► Unload TTS ───────────────►│
 │◄─ Voice Response ┼◄─────────────────────────┤                              │
```

---

## 10. Concrete Integration Plan in This Repo
### Phase 1 (Safe Refactor)
- Add `ModelLifecycleManager` and `ModelManifestService` under AI/services layer.
- Keep existing `DownloadService`, but add checksum/manifest verification hooks.

### Phase 2 (Startup Gate)
- Keep current `Splash -> Download -> Home` route behavior.
- Convert download screen presentation into mandatory setup modal wrapper if auth exists.

### Phase 3 (Voice Path)
- Implement Whisper adapter service and attach to `ZeroController.handleVoiceInput`.
- Replace placeholder text path with real STT pipeline and immediate unload.

---

## 11. Reliability and Observability
Emit structured events:
- `setup_modal_opened`
- `model_download_started`
- `model_download_completed`
- `model_verify_failed`
- `model_load_started`
- `model_load_completed`
- `route_decision_made`
- `model_unloaded`
- `voice_transaction_completed`

Operational requirements:
- Every failure path must return a user-safe message.
- Retry paths for network errors and corrupt files.
- Avoid silent fallback that hides model availability issues.

---

## 12. Acceptance Checklist
- First authenticated launch blocks on setup until required models are valid.
- No heavy model pre-bundled by default.
- Voice flow performs load -> infer -> unload for Whisper every interaction.
- Routing consistently selects Qwen for simple and Gemma for complex tasks.
- TTS resources are released after playback.
- Test suite and analyzer remain green.
