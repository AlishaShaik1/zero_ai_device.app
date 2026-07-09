import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>.broadcast();
  bool _isRecording = false;
  final List<int> _bleAudioBuffer = [];
  Timer? _silenceTimer;
  StreamSubscription<Uint8List>? _phoneMicSubscription;
  double _currentAudioLevel = 0.0;

  final SpeechToText _speechToText = SpeechToText();
  bool _isWakeWordListening = false;
  VoidCallback? _onWakeWordDetected;

  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  bool get isRecording => _isRecording;
  double get currentAudioLevel => _currentAudioLevel;
  bool get isWakeWordListening => _isWakeWordListening;

  final List<int> _phoneAudioBuffer = [];

  Future<void> startPhoneMicRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw 'Microphone permission denied';
    
    _isRecording = true;
    _phoneAudioBuffer.clear();
    final config = const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );
    final stream = await _recorder.startStream(config);
    await _phoneMicSubscription?.cancel();
    _phoneMicSubscription = stream.listen((data) {
      _phoneAudioBuffer.addAll(data);
      _currentAudioLevel = _calculateLevel(data);
      _resetSilenceTimer();
    });
  }

  Future<Uint8List> stopPhoneMicRecording() async {
    _isRecording = false;
    _silenceTimer?.cancel();
    await _phoneMicSubscription?.cancel();
    _phoneMicSubscription = null;
    await _recorder.stop();
    final bytes = Uint8List.fromList(_phoneAudioBuffer);
    _phoneAudioBuffer.clear();
    return bytes;
  }

  void processBleAudioChunk(Uint8List chunk) {
    _bleAudioBuffer.addAll(chunk);
    _resetSilenceTimer();
    _currentAudioLevel = _calculateLevel(chunk);
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_bleAudioBuffer.isNotEmpty) {
        _audioStreamController.add(Uint8List.fromList(_bleAudioBuffer));
        _bleAudioBuffer.clear();
      }
    });
  }

  double _calculateLevel(Uint8List data) {
    if (data.isEmpty) return 0.0;
    int sum = 0;
    for (int byte in data) {
      sum += byte.abs();
    }
    return (sum / data.length / 128).clamp(0.0, 1.0);
  }

  bool detectWakeWord(Uint8List audio) {
    // Energy threshold wake word detection
    double level = _calculateLevel(audio);
    return level > 0.3;  
  }

  Future<void> initWakeWordEngine(VoidCallback onWakeWordDetected) async {
    _onWakeWordDetected = onWakeWordDetected;
    try {
      bool available = await _speechToText.initialize(
        onError: (error) => debugPrint('[STT WakeWord] Error: $error'),
        onStatus: (status) => debugPrint('[STT WakeWord] Status: $status'),
      );
      if (available) {
        _startContinuousListening();
      } else {
        debugPrint("STT not available for wake word.");
      }
    } catch (e) {
      debugPrint("Error initializing wake word engine: $e");
    }
  }

  void _startContinuousListening() {
    if (_isWakeWordListening) return;
    _isWakeWordListening = true;

    // CRASH FIX #1: Use SpeechListenOptions instead of deprecated named params.
    // CRASH FIX #5: Use 30s window + auto-restart so the mic is released regularly,
    // preventing it from being permanently locked and blocking VoicePipelineService.
    try {
      _speechToText.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase();
          if (words.contains('hey zero') ||
              words.contains('hey hero') ||
              words.contains('ok zero') ||
              words.contains('hello zero')) {
            debugPrint('Wake word detected via STT!');
            _speechToText.stop();
            _isWakeWordListening = false;
            _onWakeWordDetected?.call();
            // Do not auto-resume here; the controller will resume it
            // when it is done processing the command.
          }
        },
      ).then((_) {
        // When the 30s window ends without a wake word, restart automatically
        if (_isWakeWordListening) {
          _isWakeWordListening = false;
          Future.delayed(const Duration(milliseconds: 500), _startContinuousListening);
        }
      }).catchError((e) {
        debugPrint('[STT WakeWord] Listener error: $e');
        _isWakeWordListening = false;
      });
    } catch (e) {
      debugPrint('[STT WakeWord] Failed to start listening: $e');
      _isWakeWordListening = false;
    }
  }

  void stopWakeWordEngine() {
    _speechToText.cancel();
    _isWakeWordListening = false;
  }

  void resumeWakeWordEngine() {
    if (!_isRecording) {
      _startContinuousListening();
    }
  }

  void dispose() {
    stopWakeWordEngine();
    _recorder.dispose();
    _silenceTimer?.cancel();
    _phoneMicSubscription?.cancel();
    _audioStreamController.close();
  }
}
