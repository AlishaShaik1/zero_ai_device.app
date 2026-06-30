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
  static const String MODEL_NANO_NAME = 'Zero Nano';
  static const String MODEL_AGENTIC_NAME = 'Zero Agentic';
  static const String MODEL_PRIME_NAME = 'Zero Prime';
  static const String MODEL_VOICE_NAME = 'Zero Voice';

  // Download URLs
  static const String URL_QWEN = 'https://huggingface.co/Mohideen1/zero-ring-models/resolve/main/Qwen3-0.6B-IQ4_XS.gguf?download=true';
  static const String URL_GEMMA = 'https://huggingface.co/Mohideen1/intelligent_model/resolve/main/gemma-4-E2B-it.litertlm?download=true';
  static const String URL_TTS_EN_MODEL = 'https://huggingface.co/Mohideen1/amy_tts/resolve/main/en_US-amy-medium.onnx?download=true';
  static const String URL_TTS_EN_CONFIG = 'https://huggingface.co/Mohideen1/amy_tts/resolve/main/en_US-amy-medium.onnx.json?download=true';
  static const String URL_TTS_HI_MODEL = 'https://huggingface.co/Mohideen1/rohan_tts/resolve/main/hi_IN-rohan-medium.onnx?download=true';
  static const String URL_TTS_HI_CONFIG = 'https://huggingface.co/Mohideen1/rohan_tts/resolve/main/hi_IN-rohan-medium.onnx.json?download=true';
  
  static const String URL_STT_PREPROCESSOR = 'https://huggingface.co/Mohideen1/speech_to_text_model/resolve/main/preprocessor.tfl?download=true';
  static const String URL_STT_ENCODER = 'https://huggingface.co/Mohideen1/speech_to_text_model/resolve/main/encoder.tfl?download=true';
  static const String URL_STT_DECODER_INIT = 'https://huggingface.co/Mohideen1/speech_to_text_model/resolve/main/decoder_initial.tfl?download=true';
  static const String URL_STT_DECODER = 'https://huggingface.co/Mohideen1/speech_to_text_model/resolve/main/decoder.tfl?download=true';

  // File names saved on device
  static const String FILE_QWEN = 'qwen_v1.gguf';
  static const String FILE_GEMMA = 'gemma-4-E2B-it.litertlm';
  static const String FILE_TTS_EN_MODEL = 'en_US-amy-medium.onnx';
  static const String FILE_TTS_EN_CONFIG = 'en_US-amy-medium.onnx.json';
  static const String FILE_TTS_HI_MODEL = 'hi_IN-rohan-medium.onnx';
  static const String FILE_TTS_HI_CONFIG = 'hi_IN-rohan-medium.onnx.json';
  
  static const String FILE_STT_PREPROCESSOR = 'preprocessor.tfl';
  static const String FILE_STT_ENCODER = 'encoder.tfl';
  static const String FILE_STT_DECODER_INIT = 'decoder_initial.tfl';
  static const String FILE_STT_DECODER = 'decoder.tfl';

  // Prefs keys
  static const String PREF_ONBOARDING_DONE = 'onboarding_complete';
  static const String PREF_MODELS_DOWNLOADED = 'models_downloaded';
  static const String PREF_USER_NAME = 'user_name';
  static const String PREF_TTS_SPEED = 'tts_speed';
  static const String PREF_TTS_PITCH = 'tts_pitch';
  static const String PREF_LANGUAGE = 'user_language';

  // BLE reconnect delays seconds
  static const List<int> RECONNECT_DELAYS = [1, 2, 4, 8, 30];
}
