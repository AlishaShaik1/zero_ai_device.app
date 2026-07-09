import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'translation_service.dart';
import 'conversation_manager.dart';
import 'tts_service.dart';

/// FIX #1: VoicePipelineService no longer calls the LLM directly.
/// Instead, it fires [onCommandRecognized] with the final transcribed text,
/// delegating routing/model selection entirely to ZeroController.
/// This fixes: voice input bypassing agentic routing + action execution.
class VoicePipelineService with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  final TranslationService _translationService;

  /// Callback fires with the final recognized text.
  /// ZeroController.handleTextCommand() is passed here, so the full
  /// agentic pipeline (intents → classifier → Qwen/Gemma) runs for voice.
  final Future<void> Function(String text) onCommandRecognized;

  bool _isListening = false;
  String _recognizedWords = '';

  bool get isListening => _isListening;
  String get recognizedWords => _recognizedWords;

  VoicePipelineService({
    required this.onCommandRecognized,
    required TranslationService translationService,
    required ConversationManager conversationManager,
    required TtsService ttsService,
  }) : _translationService = translationService {
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      await _speechToText.initialize(
        onError: (error) => debugPrint('[STT] Error: $error'),
        onStatus: (status) => debugPrint('[STT] Status: $status'),
      );
    } catch (e) {
      debugPrint('[STT] Failed to initialize: $e');
    }
  }

  Future<void> startListening({String localeId = "en_IN"}) async {
    if (!_speechToText.isAvailable) {
      debugPrint('[STT] Speech recognition not initialized, attempting to initialize...');
      try {
        final available = await _speechToText.initialize(
          onError: (error) => debugPrint('[STT] Error: $error'),
          onStatus: (status) => debugPrint('[STT] Status: $status'),
        );
        if (!available) {
          debugPrint('[STT] Speech recognition initialization failed.');
          return;
        }
      } catch (e) {
        debugPrint('[STT] Speech recognition initialization error: $e');
        return;
      }
    }

    _isListening = true;
    _recognizedWords = '';
    notifyListeners();

    // Use SpeechListenOptions to avoid deprecated named parameters
    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
      ),
      onResult: (result) async {
        _recognizedWords = result.recognizedWords;
        notifyListeners();

        if (result.finalResult && _recognizedWords.isNotEmpty) {
          _isListening = false;
          notifyListeners();
          // FIX #1: Delegate to ZeroController.handleTextCommand() via callback.
          // This ensures full agentic routing, action execution, and proper
          // model selection run for voice — not just a direct LLM call.
          await _processVoiceCommand(_recognizedWords, localeId);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _isListening = false;
    notifyListeners();
  }

  Future<void> _processVoiceCommand(String rawText, String sourceLocale) async {
    if (rawText.trim().isEmpty) return;
    try {
      // Optionally translate to English before passing to the controller.
      // MockTranslationService returns the text unchanged.
      final englishText = await _translationService.translate(rawText, sourceLocale, 'en_US');
      // Fire the controller callback — this runs the full pipeline.
      await onCommandRecognized(englishText.trim());
    } catch (e) {
      debugPrint('[VoicePipeline] Error processing command: $e');
    }
  }
}
