import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _flutterTts.setLanguage('en-IN');
    // 0.5 is a natural, comfortable conversational speed on Android.
    // 0.85 was far too fast and made speech hard to understand.
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() => _isSpeaking = true);
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
    _flutterTts.setCancelHandler(() => _isSpeaking = false);
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  Future<void> speak(String text, {String? language}) async {
    final cleaned = _cleanText(text);
    if (cleaned.isEmpty) return;
    // Stop any running speech before starting new one to prevent audio overlap
    if (_isSpeaking) await stop();
    // Only change language if explicitly requested;
    // don't auto-detect per-message as it overrides the user's language setting.
    if (language != null) await _flutterTts.setLanguage(language);
    await _flutterTts.speak(cleaned);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }


  String _cleanText(String text) {
    // Remove LLM control tokens that may leak through from Qwen or Gemma
    // Remove emojis and markdown symbols for cleaner TTS output
    return text
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<start_of_turn>', '')
        .replaceAll('<end_of_turn>', '')
        .replaceAll(RegExp(r'\n(User|user|assistant|system):'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[*_`#~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> setLanguage(String lang) async {
    await _flutterTts.setLanguage(lang);
  }

  Future<void> setSpeed(double speed) async {
    await _flutterTts.setSpeechRate(speed);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  bool get isSpeaking => _isSpeaking;
}
