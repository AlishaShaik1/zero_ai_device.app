# Zero Ring App

Flutter app for Zero Ring AI companion with model download, local inference, and automation routing.

## Project Layout

- `lib/ai/`: current AI service adapters (Qwen/Gemma placeholders and orchestration helpers)
- `lib/controllers/`: app orchestration and interaction flow
- `lib/services/`: platform and app services (download, BLE, TTS, audio, etc.)
- `lib/screens/`: UI screens including splash and model download
- `lib/automation/`: connector catalog, registry, and task execution pipeline
- `lib/features/`: feature-first organization blueprint for incremental migration
- `docs/architecture/`: architecture and integration documents

## Architecture Docs

- Multi-model architecture: `docs/architecture/multi_model_ai_app_architecture.md`
- Feature-folder blueprint: `docs/architecture/feature_folder_organization.md`

## Local Development

### Prerequisites
- Flutter SDK (stable)
- Android/iOS toolchains as needed

### Commands
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter run`

## Notes

- Model files are runtime-downloaded and validated during setup flow.
- Keep heavy model lifecycle operations behind a centralized manager to avoid memory pressure and regressions.
