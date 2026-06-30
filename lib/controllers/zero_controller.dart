import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  
  String _lastResponse = "";
  String _debugRouting = "";
  bool _isProcessing = false;
  final List<StreamSubscription> _subs = [];
  Timer? _idleBehaviorTimer;

  RingState get ringState => _ringState;
  String get lastResponse => _lastResponse;
  String get debugRouting => _debugRouting;
  bool get isProcessing => _isProcessing;
  ClassifierService get classifierService => _classifierService;
  PersonalityService get personalityService => _personalityService;

  Future<void> initState() async {
    // 1. Init personality system
    await _personalityService.initialize();
    
    // 2. Init TTS
    await _ttsService.initialize();
    
    // 3. Init Agentic & Prime
    await _agenticService.initialize();
    await _primeService.initialize();
    
    // 4. Load classifier
    await _classifierService.loadModel();
    
    // 5. Set initial greeting based on personality
    _lastResponse = _personalityService.getGreeting();
    
    // 6. Start BLE scan
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
    
    // 7. Listen to BLE audio from ring
    _subs.add(_bleService.audioStream.listen((audioData) {
      _audioService.processBleAudioChunk(audioData);
      if (_audioService.detectWakeWord(audioData)) {
        _handleVoiceActivation();
      }
    }));
    
    // 8. Listen to accel data — gravity reactivity
    _subs.add(_bleService.accelStream.listen((accel) {
      _handleSensorData(accel);
      if (_ringState.isMouseModeActive) {
        _handleMouseMovement(accel);
      }
    }));
    
    // 9. Start idle behavior timer
    _startIdleBehaviors();
    
    _bleService.startScan();
    notifyListeners();
  }

  /// Initialize the Qwen Nano model with a given path
  Future<void> initNanoModel(String modelPath) async {
    await _nanoService.initialize(modelPath);
    if (_nanoService.isLoaded) {
      _updateResponse("Zero Nano ready! I'm online ✨");
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

  Future<void> handleVoiceInput(Uint8List audioBytes) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _updateEmotion(ZeroEmotion.thinking);
    _ringState = _ringState.copyWith(isRecording: false);
    notifyListeners();

    try {
      // TODO: Replace with actual STT when models are downloaded
      // For now, fallback to a friendly message
      _updateResponse("I heard you! Voice transcription coming soon 🎙️");
      await _ttsService.speak("I heard you, but I need my speech models first!");
      _updateEmotion(ZeroEmotion.happy);
    } catch(e) {
      _updateResponse("Oops, something went wrong! 😅");
      _updateEmotion(ZeroEmotion.surprised);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // DIRECT TEXT COMMAND (works without ring hardware)
  Future<void> handleTextCommand(String text) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _updateEmotion(ZeroEmotion.thinking);
    _personalityService.onInteraction();
    notifyListeners();

    try {
      // 1. Agentic / Tool Calling execution
      final intent = await _agenticService.parseIntent(text);
      if (intent.action != ZeroAction.unknown) {
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
          _updateResponse(actionResult);
          await _ttsService.speak(actionResult);

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

      // 2. Fallback to conversational models (Qwen Nano)
      final routing = await _classifierService.classify(text);
      _debugRouting = routing;
      bool isSimple = routing == "SIMPLE";
      bool isComplex = routing == "COMPLEX";

      if (isSimple && _nanoService.isLoaded) {
        _ringState = _ringState.copyWith(activeModel: ActiveModel.nano);
        notifyListeners();

        final response = await _nanoService.ask(text);
        _updateResponse(response);
        await _ttsService.speak(response);
        _updateEmotion(ZeroEmotion.happy);
      } else if (isComplex) {
        _ringState = _ringState.copyWith(activeModel: ActiveModel.prime);
        notifyListeners();

        if (_primeService.isInitialized) {
          final response = await _primeService.solveComplexProblem(prompt: text);
          _updateResponse(response);
          await _ttsService.speak(response);
          _updateEmotion(ZeroEmotion.excited);
        } else {
          final bridge = _nanoService.getBridgeResponse();
          _updateResponse(bridge);
          await _ttsService.speak(bridge);
          _updateResponse("Zero Prime integration coming soon! 🚀");
        }
      } else if (_nanoService.isLoaded) {
        _ringState = _ringState.copyWith(activeModel: ActiveModel.nano);
        notifyListeners();

        final response = await _nanoService.ask(text);
        _updateResponse(response);
        await _ttsService.speak(response);
        _updateEmotion(ZeroEmotion.happy);
      } else {
        // No model loaded — friendly fallback
        final fallback = _personalityService.getNoModelResponse(text);
        _updateResponse(fallback);
        await _ttsService.speak(fallback);
        _updateEmotion(ZeroEmotion.happy);
      }
    } catch(e) {
      _updateResponse("Brain hiccup! Try again ✨");
      _updateEmotion(ZeroEmotion.surprised);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // ═══ RECORDING ═══

  Future<void> startRecording() async {
    await _audioService.startPhoneMicRecording();
    _ringState = _ringState.copyWith(
      isRecording: true,
      currentEmotion: ZeroEmotion.listening
    );
    notifyListeners();
  }

  Future<void> stopRecording() async {
    final audioBytes = await _audioService.stopPhoneMicRecording();
    _ringState = _ringState.copyWith(isRecording: false);
    notifyListeners();
    if (audioBytes.isNotEmpty) {
      await handleVoiceInput(audioBytes);
    }
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
      );
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

  void _handleVoiceActivation() {
    if (!_isProcessing) {
      _updateEmotion(ZeroEmotion.listening);
      _ringState = _ringState.copyWith(isRecording: true);
      notifyListeners();
    }
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
