class AppConstants {
  // BLE
  static const String BLE_DEVICE_NAME = 'ZERO_RING';
  static const String SERVICE_UUID = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String AUDIO_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String DISPLAY_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';
  static const String ACCEL_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26aa';
  static const String CAMERA_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26ab';
  static const String COMMAND_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26ac';

  // Model names shown to user
  static const String MODEL_NANO_NAME = 'Zero Nano (Qwen 0.6B)';
  static const String MODEL_AGENTIC_NAME = 'Zero Agentic Router';
  static const String MODEL_PRIME_NAME = 'Zero Prime (Gemma 2 9B-it)';
  static const String MODEL_VOICE_NAME = 'System Voice';

  // Download URLs
  static const String URL_QWEN = 'https://huggingface.co/drmcbride/Qwen3-0.6B-Q8_0-GGUF/resolve/main/qwen3-0.6b-q8_0.gguf?download=true';
  static const String URL_GEMMA = 'https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf?download=true';

  // Bump the cache version whenever the STT model source changes so the app
  // fetches the new file instead of reusing an older cached download.
  static const String URL_STT_WHISPER_MEDIUM = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin?download=true';

  // File names saved on device
  static const String FILE_QWEN = 'qwen3-0.6b-q8_0.gguf';
  static const String FILE_GEMMA = 'gemma-2-9b-it-Q4_K_M.gguf';

  static const String FILE_STT_WHISPER_MEDIUM = 'ggml-medium.bin';
  static const String FILE_STT_WHISPER_MEDIUM_LEGACY = 'ggml-model-whisper-medium-q5_0.bin';

  // Prefs keys
  static const String PREF_ONBOARDING_DONE = 'onboarding_complete';
  static const String PREF_MODELS_DOWNLOADED = 'models_downloaded';
  static const String PREF_USER_NAME = 'user_name';
  static const String PREF_TTS_SPEED = 'tts_speed';
  static const String PREF_TTS_PITCH = 'tts_pitch';
  static const String PREF_LANGUAGE = 'user_language';
  static const String PREF_SUB_KEY = 'zero_ring_sub_key';

  // BLE reconnect delays seconds
  static const List<int> RECONNECT_DELAYS = [1, 2, 4, 8, 30];
}
