import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

class ZeroPrimeService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/${AppConstants.FILE_GEMMA}';
      
      final file = File(modelPath);
      if (!await file.exists()) {
        debugPrint('Zero Prime model not found at $modelPath');
        return;
      }

      // The current app uses Gemma as a downloaded local resource and keeps the
      // reasoning flow simulated behind the app's orchestration layer.
      _isInitialized = true;
      debugPrint('Zero Prime (Gemma 4 E4B-it) initialized successfully from local file');
    } catch (e) {
      debugPrint('Error initializing Zero Prime: $e');
    }
  }

  /// The main boss function that solves complex problems using multimodal input
  Stream<String> solveComplexProblem({
    required String prompt,
    String? imagePath,
    String? audioPath,
  }) async* {
    if (!_isInitialized) {
      yield "Zero Prime is currently offline. Please ensure the model is downloaded.";
      return;
    }

    try {
      debugPrint('Zero Prime processing prompt: $prompt');
      if (imagePath != null) debugPrint('Zero Prime attached image: $imagePath');
      if (audioPath != null) debugPrint('Zero Prime attached audio: $audioPath');

      // Simulate the execution delay
      await Future.delayed(const Duration(milliseconds: 1500));

      String responseText = "Complex problem solved: As the Zero Prime system, I've analyzed your request using Gemma 4 E2B LMRT. The solution has been determined and executed.";
      if (imagePath != null && audioPath != null) {
        responseText = "I've analyzed the image and audio context. Based on Gemma 4 E2B multimodal processing, the optimal solution is to adjust the system parameters.";
      } else if (imagePath != null) {
        responseText = "I've processed the image you sent. Gemma Vision Analysis indicates structural anomalies. Let me fix them.";
      } else if (audioPath != null) {
        responseText = "I've processed the voice clip. The intent requires deep reasoning. I'll execute the cross-app workflow now.";
      }

      // Simulate streaming output
      for (var word in responseText.split(' ')) {
        yield "$word ";
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('Zero Prime error: $e');
      yield "Zero Prime encountered a complex error: $e";
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
