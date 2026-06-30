import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _flutterTts.setLanguage('en-IN');
    await _flutterTts.setSpeechRate(0.85);
    await _flutterTts.setPitch(1.1);
    await _flutterTts.setVolume(1.0);
    
    _flutterTts.setStartHandler(() => _isSpeaking = true);
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
    _flutterTts.setCancelHandler(() => _isSpeaking = false);
  }

  Future<void> speak(String text, {String? language}) async {
    if (_isSpeaking) await stop();
    final lang = language ?? _detectedLanguage(text);
    await _flutterTts.setLanguage(lang);
    await _flutterTts.speak(_cleanText(text));
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  String _detectedLanguage(String text) {
    // Detect Telugu characters
    if (text.runes.any((r) => r >= 0x0C00 && r <= 0x0C7F)) {
      return 'te-IN';
    }
    // Detect Hindi/Devanagari
    if (text.runes.any((r) => r >= 0x0900 && r <= 0x097F)) {
      return 'hi-IN';
    }
    return 'en-IN';
  }

  String _cleanText(String text) {
    // Remove emojis for cleaner TTS
    return text.replaceAll(RegExp(
      r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim();
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
