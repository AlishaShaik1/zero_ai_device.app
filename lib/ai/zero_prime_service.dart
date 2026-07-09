import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../utils/constants.dart';

class ZeroPrimeService {
  bool _isInitialized = false;
  String? _lastLoadError;
  
  LlamaEngine? _engine;
  EngineSession? _session;

  bool get isInitialized => _isInitialized;
  String? get lastLoadError => _lastLoadError;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/${AppConstants.FILE_GEMMA}';
      
      final file = File(modelPath);
      if (!await file.exists()) {
        debugPrint('[Zero Prime] ❌ Model file not found at dynamic path: $modelPath');
        return;
      }

      if (Platform.isAndroid) {
        _engine = await LlamaEngine.spawn(
          libraryPath: 'libllama.so',
          modelParams: ModelParams(path: modelPath),
          contextParams: const ContextParams(nCtx: 4096),
        );
      } else {
        _engine = await LlamaEngine.spawnFromProcess(
          modelParams: ModelParams(path: modelPath),
          contextParams: const ContextParams(nCtx: 4096),
        );
      }
      
      _isInitialized = true;
      _lastLoadError = null;
      debugPrint('[Zero Prime] ✅ Model engine initialized successfully from: $modelPath');
    } catch (e) {
      _lastLoadError = e.toString();
      debugPrint('Error initializing Zero Prime: $e');
    }
  }

  /// The main boss function that solves complex problems using multimodal input
  Stream<String> solveComplexProblem({
    required String prompt,
    String? imagePath,
    String? audioPath,
  }) async* {
    if (!_isInitialized || _engine == null) {
      yield "Zero Prime is currently offline. Please ensure the model is downloaded.";
      return;
    }

    EngineSession? session;
    try {
      session = await _engine!.createSession();
      debugPrint('Zero Prime processing prompt: $prompt');
      if (imagePath != null) debugPrint('Zero Prime attached image: $imagePath');
      if (audioPath != null) debugPrint('Zero Prime attached audio: $audioPath');

      final gemmaPrompt = """<start_of_turn>user
$prompt<end_of_turn>
<start_of_turn>model
""";

      await for (final event in session.generate(
        prompt: gemmaPrompt,
        maxTokens: 1024,
      )) {
        if (event is TokenEvent) {
          final cleaned = event.text
              .replaceAll('<end_of_turn>', '')
              .replaceAll('<start_of_turn>', '');

          if (cleaned.isNotEmpty) yield cleaned;
        }
      }
    } catch (e) {
      debugPrint('Zero Prime error: $e');
      yield "Zero Prime encountered a complex error: $e";
    } finally {
      if (session != null) {
        await session.dispose();
      }
    }
  }

  void dispose() {
    _engine?.dispose();
    _isInitialized = false;
  }
}
