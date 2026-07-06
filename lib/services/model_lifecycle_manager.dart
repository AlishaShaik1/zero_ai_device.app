import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../ai/zero_nano_service.dart';
import '../ai/zero_prime_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';

enum ModelState { unloaded, loading, ready, inferencing, unloading, error }

class ModelLifecycleManager with ChangeNotifier {
  final ZeroNanoService _nanoService;
  final ZeroPrimeService _primeService;
  final TtsService _ttsService;

  ModelState _whisperState = ModelState.unloaded;
  ModelState _qwenState = ModelState.unloaded;
  ModelState _gemmaState = ModelState.unloaded;
  ModelState _ttsState = ModelState.unloaded;

  String? _loadedModelId;
  bool _isLowRamDevice = false;
  bool _isLocked = false;

  ModelLifecycleManager(this._nanoService, this._primeService, this._ttsService);

  ModelState get whisperState => _whisperState;
  ModelState get qwenState => _qwenState;
  ModelState get gemmaState => _gemmaState;
  ModelState get ttsState => _ttsState;
  String? get loadedModelId => _loadedModelId;
  bool get isLowRamDevice => _isLowRamDevice;

  void setLowRamDevice(bool val) {
    debugPrint('[Lifecycle Log] [US state change] RAM Tier set to: ${val ? "Low-RAM (181MB Profile)" : "High-RAM"}');
    _isLowRamDevice = val;
    notifyListeners();
  }

  void _logStateChange(String modelName, ModelState oldState, ModelState newState) {
    debugPrint('[Lifecycle Log] [US state change] [Animation Trigger] $modelName: $oldState ──► $newState');
  }

  /// Lock mechanism supporting cancellation, exception safety, and timeout recovery.
  Future<void> _acquireExclusiveMemory(String targetModelId) async {
    debugPrint('[Lifecycle Log] [US state change] Requesting memory lock for $targetModelId');
    while (_isLocked) {
      debugPrint('[Lifecycle Log] Memory lock is held. Waiting 100ms...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _isLocked = true;
    
    if (_loadedModelId != null && _loadedModelId != targetModelId) {
      debugPrint('[Lifecycle Log] [US state change] Unloading active model $_loadedModelId to ensure exclusive allocation');
      await _unloadModel(_loadedModelId!);
    }
  }

  void _releaseLock() {
    _isLocked = false;
    debugPrint('[Lifecycle Log] [US state change] Memory lock released');
  }

  Future<void> forceCleanup() async {
    debugPrint('[Lifecycle Log] [Forced Cleanup] Triggering emergency native cleanups...');
    await _unloadModel('whisper');
    await _unloadModel('qwen');
    await _unloadModel('gemma');
    await _unloadModel('tts');
    _loadedModelId = null;
    _isLocked = false;
    notifyListeners();
  }

  Future<void> _unloadModel(String modelId) async {
    try {
      if (modelId == 'whisper') {
        _logStateChange('Whisper', _whisperState, ModelState.unloading);
        _whisperState = ModelState.unloading;
        notifyListeners();
        
        debugPrint('[Lifecycle Log] Native Whisper context (whisper_free) destroyed.');
        _whisperState = ModelState.unloaded;
        _logStateChange('Whisper', ModelState.unloading, ModelState.unloaded);
      } else if (modelId == 'qwen') {
        _logStateChange('Qwen', _qwenState, ModelState.unloading);
        _qwenState = ModelState.unloading;
        notifyListeners();
        
        _nanoService.dispose();
        debugPrint('[Lifecycle Log] Native llama.cpp GGUF context destroyed, memory unmapped.');
        _qwenState = ModelState.unloaded;
        _logStateChange('Qwen', ModelState.unloading, ModelState.unloaded);
      } else if (modelId == 'gemma') {
        _logStateChange('Gemma', _gemmaState, ModelState.unloading);
        _gemmaState = ModelState.unloading;
        notifyListeners();
        
        _primeService.dispose();
        debugPrint('[Lifecycle Log] Native Gemma LiteRT/TFLite interpreter context destroyed.');
        _gemmaState = ModelState.unloaded;
        _logStateChange('Gemma', ModelState.unloading, ModelState.unloaded);
      } else if (modelId == 'tts') {
        _logStateChange('System Voice', _ttsState, ModelState.unloading);
        _ttsState = ModelState.unloading;
        notifyListeners();
        
        await _ttsService.stop();
        debugPrint('[Lifecycle Log] Platform system voice engine released.');
        _ttsState = ModelState.unloaded;
        _logStateChange('System Voice', ModelState.unloading, ModelState.unloaded);
      }
    } catch (e) {
      debugPrint('[Lifecycle Log] Error during unloading model $modelId: $e');
    }
  }

  // Note: Whisper STT methods have been removed in favor of native speech_to_text.
  // The whisper model download logic remains untouched in download_service.dart.

  /// Dynamic load and execute for reasoning models with memory-mapped GGUF option
  Stream<String> executeReasoning(String text) async* {
    final isComplex = await _nanoService.isComplexTask(text);
    
    if (isComplex && !_isLowRamDevice) {
      yield* _executeGemma(text);
    } else {
      yield* _executeQwen(text);
    }
  }

  Timer? _qwenIdleTimer;
  Timer? _gemmaIdleTimer;
  static const Duration _idleTimeout = Duration(minutes: 5);

  void _resetQwenIdleTimer() {
    _qwenIdleTimer?.cancel();
    _qwenIdleTimer = Timer(_idleTimeout, () async {
      debugPrint('[Lifecycle Log] Qwen idle timeout reached. Unloading.');
      await _acquireExclusiveMemory('cleanup');
      await _unloadModel('qwen');
      if (_loadedModelId == 'qwen') _loadedModelId = null;
      _releaseLock();
    });
  }

  void _resetGemmaIdleTimer() {
    _gemmaIdleTimer?.cancel();
    _gemmaIdleTimer = Timer(_idleTimeout, () async {
      debugPrint('[Lifecycle Log] Gemma idle timeout reached. Unloading.');
      await _acquireExclusiveMemory('cleanup');
      await _unloadModel('gemma');
      if (_loadedModelId == 'gemma') _loadedModelId = null;
      _releaseLock();
    });
  }

  Stream<String> _executeQwen(String text) async* {
    await _acquireExclusiveMemory('qwen');
    try {
      _resetQwenIdleTimer();

      if (_qwenState != ModelState.ready) {
        _logStateChange('Qwen', _qwenState, ModelState.loading);
        _qwenState = ModelState.loading;
        notifyListeners();

        final dir = await getApplicationDocumentsDirectory();
        final modelPath = '${dir.path}/${AppConstants.FILE_QWEN}';
        
        debugPrint('[Lifecycle Log] Loading Qwen GGUF model with mmap enabled from $modelPath');
        await _nanoService.initialize(modelPath);
        _qwenState = ModelState.ready;
        _loadedModelId = 'qwen';
        _logStateChange('Qwen', ModelState.loading, ModelState.ready);
        notifyListeners();
      }

      _logStateChange('Qwen', _qwenState, ModelState.inferencing);
      _qwenState = ModelState.inferencing;
      notifyListeners();
      
      yield* _nanoService.ask(text);
    } catch (e) {
      _qwenState = ModelState.error;
      _logStateChange('Qwen', ModelState.inferencing, ModelState.error);
      notifyListeners();
      yield "Oops, something went wrong!";
    } finally {
      if (_qwenState == ModelState.inferencing) {
        _qwenState = ModelState.ready;
        _logStateChange('Qwen', ModelState.inferencing, ModelState.ready);
      }
      _releaseLock();
      notifyListeners();
    }
  }

  Stream<String> _executeGemma(String text) async* {
    await _acquireExclusiveMemory('gemma');
    try {
      _resetGemmaIdleTimer();

      if (_gemmaState != ModelState.ready) {
        _logStateChange('Gemma', _gemmaState, ModelState.loading);
        _gemmaState = ModelState.loading;
        notifyListeners();

        await _primeService.initialize();
        _gemmaState = ModelState.ready;
        _loadedModelId = 'gemma';
        _logStateChange('Gemma', ModelState.loading, ModelState.ready);
        notifyListeners();
      }

      _logStateChange('Gemma', _gemmaState, ModelState.inferencing);
      _gemmaState = ModelState.inferencing;
      notifyListeners();
      
      yield* _primeService.solveComplexProblem(prompt: text);
    } catch (e) {
      _gemmaState = ModelState.error;
      _logStateChange('Gemma', ModelState.inferencing, ModelState.error);
      notifyListeners();
      yield "Oops, something went wrong!";
    } finally {
      if (_gemmaState == ModelState.inferencing) {
        _gemmaState = ModelState.ready;
        _logStateChange('Gemma', ModelState.inferencing, ModelState.ready);
      }
      _releaseLock();
      notifyListeners();
    }
  }

  /// JIT Speak via the platform system voice engine
  Future<void> speakWithTts(String text) async {
    await _acquireExclusiveMemory('tts');
    try {
      _logStateChange('System Voice', _ttsState, ModelState.loading);
      _ttsState = ModelState.loading;
      notifyListeners();

      await _ttsService.initialize();
      _ttsState = ModelState.ready;
      _loadedModelId = 'tts';
      _logStateChange('System Voice', ModelState.loading, ModelState.ready);
      notifyListeners();

      _logStateChange('System Voice', _ttsState, ModelState.inferencing);
      _ttsState = ModelState.inferencing;
      notifyListeners();
      
      await _ttsService.speak(text);
    } catch (e) {
      _ttsState = ModelState.error;
      _logStateChange('System Voice', ModelState.inferencing, ModelState.error);
      notifyListeners();
      rethrow;
    } finally {
      await _unloadModel('tts');
      _loadedModelId = null;
      _releaseLock();
      notifyListeners();
    }
  }
}
