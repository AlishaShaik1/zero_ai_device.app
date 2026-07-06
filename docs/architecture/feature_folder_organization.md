# Feature Folder Organization Blueprint

This folder defines a stable feature-first structure without breaking existing imports.

## Target Structure
- `lib/features/auth/`
  - Login/session state, auth guard, setup gate trigger
- `lib/features/model_setup/`
  - Mandatory setup modal, manifest verification, download UI orchestration
- `lib/features/voice/`
  - Wake-word event handling, audio capture, voice transaction context
- `lib/features/stt/`
  - Whisper adapters, Telugu->English STT+translation pipeline
- `lib/features/reasoning/`
  - Task complexity router, Qwen/Gemma orchestration
- `lib/features/tts/`
  - Google TTS adapter and playback lifecycle control
- `lib/features/automation/`
  - Connector routing and task execution pipeline

## Migration Rule
Use incremental migration only:
1. Add new feature modules.
2. Redirect call sites from controller/services in small batches.
3. Keep old paths until all references are moved.
4. Delete old modules only after tests pass.

## Why This Is Safe
- No immediate file moves are required.
- Existing app behavior remains stable.
- New architecture can be layered in gradually.
