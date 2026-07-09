import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ring_state.dart';
import '../services/ble_service.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../services/action_service.dart';
import '../services/personality_service.dart';
import '../ai/zero_nano_service.dart';
import '../ai/zero_agentic_service.dart';
import '../ai/zero_prime_service.dart';
import '../services/classifier_service.dart';
import '../services/model_lifecycle_manager.dart';
import '../services/voice_pipeline_service.dart';
import '../services/translation_service.dart';
import '../services/conversation_manager.dart';
import '../services/user_preferences_service.dart';
import '../utils/constants.dart';

class ZeroController with ChangeNotifier {
  RingState _ringState = RingState.initial();
  final BleService _bleService = BleService();
  final ZeroNanoService _nanoService = ZeroNanoService();
  final ZeroAgenticService _agenticService = ZeroAgenticService();
  final ZeroPrimeService _primeService = ZeroPrimeService();
  final TtsService _ttsService = TtsService();
  final AudioService _audioService = AudioService();
  final ActionService _actionService = ActionService();
  final ClassifierService _classifierService = ClassifierService();
  final PersonalityService _personalityService = PersonalityService();
  final UserPreferencesService _preferencesService = UserPreferencesService();

  // ModelLifecycleManager kept for debug screen and future use
  late final ModelLifecycleManager _lifecycleManager;
  final TranslationService _translationService = MockTranslationService();
  final ConversationManager _conversationManager = ConversationManager();
  late final VoicePipelineService _voicePipelineService;
  
  String _lastResponse = "";
  String _debugRouting = "";
  bool _isProcessing = false;
  ActiveModel _preferredModel = ActiveModel.nano;
  final List<StreamSubscription> _subs = [];
  Timer? _idleBehaviorTimer;

  RingState get ringState => _ringState;
  String get lastResponse => _lastResponse;
  String get debugRouting => _debugRouting;
  bool get isProcessing => _isProcessing;
  ActiveModel get preferredModel => _preferredModel;

  void togglePreferredModel() {
    _preferredModel = _preferredModel == ActiveModel.nano 
        ? ActiveModel.prime 
        : ActiveModel.nano;
    final modelName = _preferredModel == ActiveModel.nano ? "Qwen" : "Gemma";
    
    // Clear chat history to prevent KV cache/prompt contamination between different architectures
    _conversationManager.clear();
    
    final message = "Switched to $modelName. Ready to chat! ⚡";
    _conversationManager.addMessage('assistant', message);
    _updateResponse(message);
    _ttsService.speak("Model changed to $modelName");
    
    notifyListeners();
  }

  ClassifierService get classifierService => _classifierService;
  PersonalityService get personalityService => _personalityService;
  bool get isWakeWordListening => _audioService.isWakeWordListening;
  ConversationManager get conversationManager => _conversationManager;
  VoicePipelineService get voicePipelineService => _voicePipelineService;
  UserPreferencesService get preferencesService => _preferencesService;
  ModelLifecycleManager get lifecycleManager => _lifecycleManager;

  ZeroController() {
    _lifecycleManager = ModelLifecycleManager(_nanoService, _primeService, _ttsService);
    _voicePipelineService = VoicePipelineService(
      onCommandRecognized: (text) => handleTextCommand(text, isVoice: true),
      translationService: _translationService,
      conversationManager: _conversationManager,
      ttsService: _ttsService,
    );
  }

  bool _isHardwareInitialized = false;
  bool get isHardwareInitialized => _isHardwareInitialized;

  /// Lightweight initialization of local data settings only at boot.
  /// Does NOT touch hardware (mic, TTS, AI) to prevent permissions security crashes.
  Future<void> initState() async {
    try {
      // Load user preferences (language, etc.)
      await _preferencesService.init();
      // Init personality system
      await _personalityService.initialize();
      // Set greeting response
      _lastResponse = _personalityService.getGreeting();
      notifyListeners();
    } catch(e) {
      debugPrint('[ZeroController] Basic preferences boot error: $e');
    }
  }

  /// Initializes hardware-dependent services (TTS, STT, Wake-Word, BLE).
  /// Safe to call after onboarding permissions are granted.
  Future<void> initializeHardwareAndModels() async {
    if (_isHardwareInitialized) return;
    _isHardwareInitialized = true;
    debugPrint('[ZeroController] Initializing hardware and models...');

    try {
      // 1. Init TTS
      try {
        await _ttsService.initialize();
        await _ttsService.setLanguage(_preferencesService.selectedLanguage.ttsLocale);
      } catch (e) {
        debugPrint('[ZeroController] TTS initialization failed: $e');
      }
      
      // 2. Init Agentic & Prime
      try {
        await _agenticService.initialize();
      } catch (e) {
        debugPrint('[ZeroController] Agentic service initialization failed: $e');
      }
      try {
        await _primeService.initialize();
      } catch (e) {
        debugPrint('[ZeroController] Prime service initialization failed: $e');
      }

      // 3. Initialize Wake-Word engine (requires microphone permission)
      if (_preferencesService.isWakeWordEnabled) {
        try {
          await _audioService.initWakeWordEngine(() {
            _handleVoiceActivation();
          });
        } catch (e) {
          debugPrint('[ZeroController] Wake-word engine initialization failed: $e');
        }
      }

      // 4. Start BLE scan
      _subs.add(_bleService.connectionStream.listen((state) {
        _ringState = _ringState.copyWith(connectionState: state);
        if (state == RingConnectionState.connected) {
          _personalityService.onRingConnected();
          _ttsService.speak(_personalityService.getConnectionMessage());
          _updateEmotion(ZeroEmotion.excited);
          Future.delayed(const Duration(milliseconds: 2000), () => _updateEmotion(ZeroEmotion.happy));
        } else if (state == RingConnectionState.disconnected) {
          _personalityService.onRingDisconnected();
        }
        notifyListeners();
      }));

      // 5. Listen to BLE audio from ring
      _subs.add(_bleService.audioStream.listen((audioData) {
        _audioService.processBleAudioChunk(audioData);
        if (_audioService.detectWakeWord(audioData)) {
          _handleVoiceActivation();
        }
      }));

      // 6. Listen to accel data — gravity reactivity
      _subs.add(_bleService.accelStream.listen((accel) {
        _handleSensorData(accel);
        if (_ringState.isMouseModeActive) {
          _handleMouseMovement(accel);
        }
      }));

      // 7. Start idle behavior timer
      _startIdleBehaviors();

      // 8. Start BLE scanning
      _bleService.startScan();

      notifyListeners();
    } catch (e) {
      debugPrint('[ZeroController] Hardware initialization critical failure: $e');
    }
  }

  // ═══ SENSOR REACTIVITY ═══

  void _handleSensorData(List<double> accel) {
    if (accel.length < 3) return;
    final ax = accel[0];
    final ay = accel[1];
    final az = accel[2];
    
    // Detect orientation
    final magnitude = sqrt(ax * ax + ay * ay + az * az);
    
    // Upside down detection (z < -0.7g)
    if (az < -0.7 && !_isProcessing) {
      _personalityService.onUpsideDown();
      if (_ringState.currentEmotion != ZeroEmotion.surprised) {
        _updateEmotion(ZeroEmotion.surprised);
        _updateResponse(_personalityService.getReaction('upside_down'));
        Future.delayed(const Duration(seconds: 3), () {
          if (_ringState.currentEmotion == ZeroEmotion.surprised) {
            _updateEmotion(ZeroEmotion.happy);
          }
        });
      }
    }
    
    // Shake detection (high magnitude change)
    if (magnitude > 2.5 && !_isProcessing) {
      _personalityService.onShake();
      _updateEmotion(ZeroEmotion.excited);
      _updateResponse(_personalityService.getReaction('shake'));
      Future.delayed(const Duration(seconds: 2), () {
        _updateEmotion(ZeroEmotion.happy);
      });
    }
    
    // Stillness detection for idle/sleeping
    _personalityService.updateMotionState(magnitude);
    
    // Update audio level from accel magnitude for UI
    _ringState = _ringState.copyWith(
      audioLevel: (magnitude / 3.0).clamp(0.0, 1.0),
    );
    notifyListeners();
  }

  void _startIdleBehaviors() {
    _idleBehaviorTimer?.cancel();
    _idleBehaviorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isProcessing && _ringState.currentEmotion == ZeroEmotion.happy) {
        final behavior = _personalityService.getIdleBehavior();
        if (behavior != null) {
          _updateEmotion(behavior.emotion);
          if (behavior.message != null) {
            _updateResponse(behavior.message!);
          }
          Future.delayed(Duration(seconds: behavior.durationSeconds), () {
            if (!_isProcessing) {
              _updateEmotion(ZeroEmotion.happy);
            }
          });
        }
      }
    });
  }

  // ═══ VOICE / TEXT PROCESSING ═══

  // handleVoiceInput() is now obsolete — VoicePipelineService calls
  // handleTextCommand() directly via the onCommandRecognized callback.
  // Keeping this stub for BLE raw audio fallback only.
  Future<void> handleVoiceInput(Uint8List audioBytes) async {
    debugPrint('[ZeroController] Raw BLE audio received — STT handled by VoicePipelineService.');
  }

  Future<void> handleTextCommand(String text, {bool isVoice = false}) async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    // Stop recording immediately to prevent voice feedback/audio overlap
    if (_ringState.isRecording) {
      await stopRecording();
    }

    // Pause wake word engine to prevent it from self-triggering while Zero speaks/thinks
    _audioService.stopWakeWordEngine();

    _updateEmotion(ZeroEmotion.thinking);
    _personalityService.onInteraction();
    notifyListeners();

    try {
      // 1. Agentic / Tool Calling execution
      final intent = await _agenticService.parseIntent(text);
      if (intent.action != ZeroAction.unknown) {
        if (intent.action == ZeroAction.searchWeb && !_preferencesService.isWebSearchEnabled) {
          final disabledMsg = "Web search is disabled in settings 🌐";
          _conversationManager.addMessage('user', text);
          _conversationManager.addMessage('assistant', disabledMsg);
          _updateResponse(disabledMsg);
          if (isVoice) {
            await _ttsService.speak(disabledMsg);
          }
          _updateEmotion(ZeroEmotion.happy);
          return;
        }

        _updateResponse('Executing command...');

        // Signal ring: start thinking
        if (intent.action == ZeroAction.searchWeb) {
          await _bleService.sendDisplayCommand(Uint8List.fromList([0x11]));
        }

        final actionResult = await _actionService.execute(intent);

        if (actionResult == 'MOUSE_ENABLE') {
          toggleMouseMode();
        } else if (actionResult == 'MOUSE_DISABLE') {
          if (_ringState.isMouseModeActive) toggleMouseMode();
        } else {
          _conversationManager.addMessage('user', text);
          _conversationManager.addMessage('assistant', actionResult);
          _updateResponse(actionResult);
          if (isVoice) {
            await _ttsService.speak(actionResult);
          }

          // ── Send answer to ring OLED for searchWeb ──────────────────────
          if (intent.action == ZeroAction.searchWeb) {
            // Truncate to OLED limit (~38 chars readable across 4 lines)
            final oledText = actionResult.length > 38
                ? actionResult.substring(0, 38)
                : actionResult;
            final textBytes = utf8.encode(oledText);
            final cmd = Uint8List(textBytes.length + 1);
            cmd[0] = 0x01; // firmware showText() command
            cmd.setRange(1, cmd.length, textBytes);
            await _bleService.sendDisplayCommand(cmd);
          }
        }
        _updateEmotion(ZeroEmotion.happy);
        _personalityService.recordAction(intent.action.name);
        return;
      }

      // 2. Direct LLM Processing (Classifier removed per user request)
      //    Respects _preferredModel toggle.
      
      bool isPrimeEnabled = _preferencesService.isPrimeEnabled;
      bool tryNanoFirst = _preferredModel == ActiveModel.nano || !isPrimeEnabled;
      bool handled = false;

      if (tryNanoFirst) {
        if (!_nanoService.isLoaded) {
          _updateResponse('Waking up Qwen... this might take a few seconds ⚡');
          notifyListeners();
          final dir = await getApplicationDocumentsDirectory();
          final nanoPath = '${dir.path}/${AppConstants.FILE_QWEN}';
          await _nanoService.initialize(nanoPath);
        }

        if (_nanoService.isLoaded) {
          _debugRouting = 'NANO (Direct)';
          _ringState = _ringState.copyWith(activeModel: ActiveModel.nano);
          notifyListeners();
          await _streamNanoResponse(text, isVoice: isVoice);
          _updateEmotion(ZeroEmotion.happy);
          handled = true;
        }
      } else if (isPrimeEnabled) {
        if (!_primeService.isInitialized) {
          _updateResponse('Waking up Gemma... this might take a few seconds ⚡');
          notifyListeners();
          await _primeService.initialize();
        }
        
        if (_primeService.isInitialized) {
          _debugRouting = 'PRIME (Direct)';
          _ringState = _ringState.copyWith(activeModel: ActiveModel.prime);
          notifyListeners();
          
          await _streamPrimeResponse(text, isVoice: isVoice);
          handled = true;
        }
      }

      // Fallbacks if preferred model wasn't available
      if (!handled) {
        if (tryNanoFirst) {
          // Fallback to Prime
          if (isPrimeEnabled) {
            if (!_primeService.isInitialized) {
              _updateResponse('Qwen is missing! Waking up Gemma instead... this might take a few seconds ⚡');
              notifyListeners();
              await _primeService.initialize();
            }
            if (_primeService.isInitialized) {
              _debugRouting = 'PRIME (Fallback)';
              _ringState = _ringState.copyWith(activeModel: ActiveModel.prime);
              notifyListeners();
              
              await _streamPrimeResponse(text, isVoice: isVoice);
              handled = true;
            }
          }
        } else {
          // Fallback to Nano
          if (!_nanoService.isLoaded) {
            _updateResponse('Gemma is missing! Waking up Qwen instead... this might take a few seconds ⚡');
            notifyListeners();
            final dir = await getApplicationDocumentsDirectory();
            final nanoPath = '${dir.path}/${AppConstants.FILE_QWEN}';
            await _nanoService.initialize(nanoPath);
          }
          if (_nanoService.isLoaded) {
            _debugRouting = 'NANO (Fallback)';
            _ringState = _ringState.copyWith(activeModel: ActiveModel.nano);
            notifyListeners();
            await _streamNanoResponse(text, isVoice: isVoice);
            _updateEmotion(ZeroEmotion.happy);
            handled = true;
          }
        }
      }

      if (!handled) {
        String fallback = _personalityService.getNoModelResponse(text);

        if (tryNanoFirst && _nanoService.lastLoadError != null) {
          fallback = "Oops! I tried to start Qwen, but the AI engine crashed. Error: ${_nanoService.lastLoadError}";
        } else if (!tryNanoFirst && _primeService.lastLoadError != null) {
          fallback = "Oops! I tried to start Gemma, but the AI engine crashed. Error: ${_primeService.lastLoadError}";
        } else if (_nanoService.lastLoadError != null && _primeService.lastLoadError != null) {
          fallback = "Both AI engines crashed! Nano: ${_nanoService.lastLoadError} | Prime: ${_primeService.lastLoadError}";
        }

        _conversationManager.addMessage('user', text);
        _conversationManager.addMessage('assistant', fallback);
        _updateResponse(fallback);
        if (isVoice) {
          await _ttsService.speak(fallback);
        }
        _updateEmotion(ZeroEmotion.surprised);
      }
    } catch(e) {
      _updateResponse("Brain hiccup! Try again ✨");
      _updateEmotion(ZeroEmotion.surprised);
    } finally {
      _isProcessing = false;
      // Resume wake word engine if it is enabled in settings
      if (_preferencesService.isWakeWordEnabled) {
        _audioService.resumeWakeWordEngine();
      }
      notifyListeners();
    }
  }

  /// FIX #5: Stream Qwen tokens live to the chat UI.
  /// UI shows each word as it's generated (like ChatGPT streaming).
  /// TTS speaks the full response only after generation completes.
  Future<void> _streamNanoResponse(String text, {bool isVoice = false}) async {
    final buffer = StringBuffer();
    _conversationManager.addMessage('user', text);
    _conversationManager.startStreamingAssistantMessage();

    await for (final token in _nanoService.ask(text)) {
      buffer.write(token);
      _lastResponse = buffer.toString();
      _conversationManager.appendStreamingToken(token);
      // ConversationManager now throttles its own notifyListeners,
      // so we don't call notifyListeners() here to avoid double-rebuilds.
    }

    _conversationManager.finishStreamingAssistantMessage();
    final fullResponse = _cleanForTts(buffer.toString().trim());
    if (isVoice && fullResponse.isNotEmpty) {
      await _ttsService.speak(fullResponse);
    }
  }

  Future<void> _streamPrimeResponse(String text, {bool isVoice = false}) async {
    final buffer = StringBuffer();
    _conversationManager.addMessage('user', text);
    _conversationManager.startStreamingAssistantMessage();
    
    _updateResponse('Loading Zero Prime... ⚡');

    await for (final token in _primeService.solveComplexProblem(prompt: text)) {
      buffer.write(token);
      _lastResponse = buffer.toString();
      _conversationManager.appendStreamingToken(token);
      // ConversationManager now throttles its own notifyListeners.
    }

    _conversationManager.finishStreamingAssistantMessage();
    final fullResponse = _cleanForTts(buffer.toString().trim());
    if (isVoice && fullResponse.isNotEmpty) {
      await _ttsService.speak(fullResponse);
    }
    _updateEmotion(ZeroEmotion.excited);
  }

  /// Strip any model control tokens that leaked into the final response
  /// before sending to TTS. The TTS service has its own cleanup too,
  /// but this prevents obviously broken strings from reaching it.
  String _cleanForTts(String text) {
    return text
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<start_of_turn>', '')
        .replaceAll('<end_of_turn>', '')
        .replaceAll(RegExp(r'\n(User|user|assistant|system):'), '')
        .trim();
  }

  // ═══ RECORDING ═══

  Future<void> startRecording() async {
    _ringState = _ringState.copyWith(
      isRecording: true,
      currentEmotion: ZeroEmotion.listening
    );
    notifyListeners();
    // Use the locale saved by the user in Settings.
    // Defaults to en_IN on first launch (set in UserPreferencesService).
    final locale = _preferencesService.sttLocale;
    await _voicePipelineService.startListening(localeId: locale);
  }

  Future<void> stopRecording() async {
    _ringState = _ringState.copyWith(isRecording: false);
    notifyListeners();
    await _voicePipelineService.stopListening();
  }

  // ═══ INTERACTIONS ═══

  void onPetTapped() {
    _personalityService.onPetted();
    _updateEmotion(ZeroEmotion.excited);
    final response = _personalityService.getPetResponse();
    _ttsService.speak(response);
    _updateResponse(response);
    Future.delayed(const Duration(milliseconds: 2000), () => _updateEmotion(ZeroEmotion.happy));
  }

  void toggleMouseMode() {
    final newState = !_ringState.isMouseModeActive;
    _ringState = _ringState.copyWith(isMouseModeActive: newState);
    if (newState) {
      _bleService.sendRingCommand(Uint8List.fromList([0x08]));
      _updateResponse("Air mouse activated! Tilt to move 🖱️");
      _ttsService.speak("Air mouse on!");
    } else {
      _bleService.sendRingCommand(Uint8List.fromList([0x09]));
      _updateResponse("Air mouse off 🖱️");
    }
    notifyListeners();
  }

  void _handleMouseMovement(List<double> accel) {
    // Send mouse deltas to native Android BLE HID
    // Implemented in Phase 5
  }

  Future<void> captureAndAnalyze() async {
    _updateEmotion(ZeroEmotion.thinking);
    _updateResponse("Looking at what you see... 👀");
    await _ttsService.speak("Let me see!");
    // Send camera capture command to ring
    _bleService.sendRingCommand(Uint8List.fromList([0x05]));
    
    // Simulate image arrival and Prime processing it
    Future.delayed(const Duration(seconds: 2), () async {
      _updateResponse("Analyzing image with Zero Prime...");
      final response = await _primeService.solveComplexProblem(
        prompt: "Analyze this scene",
        imagePath: "/simulated/image.jpg"
      ).join("");
      _updateResponse(response);
      await _ttsService.speak(response);
      _updateEmotion(ZeroEmotion.happy);
    });
  }

  // ═══ INTERNAL ═══

  void _updateResponse(String text) {
    _lastResponse = text;
    notifyListeners();
  }

  void _updateEmotion(ZeroEmotion emotion) {
    _ringState = _ringState.copyWith(currentEmotion: emotion);
    _bleService.sendEmotionToRing(emotion);
    notifyListeners();
  }

  Future<void> _handleVoiceActivation() async {
    if (!_isProcessing) {
      _updateEmotion(ZeroEmotion.listening);
      _ringState = _ringState.copyWith(isRecording: true);
      notifyListeners();
      
      // Step 1: Greeting Acknowledgment
      _updateResponse("Hey! How are you?");
      await _ttsService.speak("Hey! How are you?", language: 'en-US');
      
      // Step 2: Automatically kick off the voice pipeline for command
      _updateResponse("Listening for command...");
      await startRecording();
    }
  }

  Future<void> toggleWakeWordEnabled(bool enabled) async {
    await _preferencesService.setWakeWordEnabled(enabled);
    if (enabled) {
      try {
        await _audioService.initWakeWordEngine(() {
          _handleVoiceActivation();
        });
      } catch (e) {
        debugPrint('[ZeroController] Dynamic wake-word enable failed: $e');
      }
    } else {
      _audioService.stopWakeWordEngine();
    }
    notifyListeners();
  }

  Future<void> togglePrimeEnabled(bool enabled) async {
    await _preferencesService.setPrimeEnabled(enabled);
    notifyListeners();
  }

  Future<void> toggleWebSearchEnabled(bool enabled) async {
    await _preferencesService.setWebSearchEnabled(enabled);
    notifyListeners();
  }

  Future<void> toggleAutoUpdateEnabled(bool enabled) async {
    await _preferencesService.setAutoUpdateEnabled(enabled);
    notifyListeners();
  }

  @override
  void dispose() {
    _idleBehaviorTimer?.cancel();
    for (var sub in _subs) { sub.cancel(); }
    _bleService.dispose();
    _nanoService.dispose();
    _ttsService.stop();
    super.dispose();
  }
}
