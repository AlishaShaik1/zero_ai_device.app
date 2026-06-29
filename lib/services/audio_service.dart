import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>.broadcast();
  bool _isRecording = false;
  final List<int> _bleAudioBuffer = [];
  Timer? _silenceTimer;
  double _currentAudioLevel = 0.0;

  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  bool get isRecording => _isRecording;
  double get currentAudioLevel => _currentAudioLevel;

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
    stream.listen((data) {
      _phoneAudioBuffer.addAll(data);
      _currentAudioLevel = _calculateLevel(data);
      _resetSilenceTimer();
    });
  }

  Future<Uint8List> stopPhoneMicRecording() async {
    _isRecording = false;
    _silenceTimer?.cancel();
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
    // "Hey Zero" energy pattern
    double level = _calculateLevel(audio);
    return level > 0.3;  // basic threshold, improve in Phase 4
  }

  void dispose() {
    _recorder.dispose();
    _silenceTimer?.cancel();
    _audioStreamController.close();
  }
}
