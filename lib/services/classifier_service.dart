import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetailedClassificationResult {
  final String label;
  final double simpleLogit;
  final double complexLogit;
  final double simpleProbability;
  final double complexProbability;
  final int inferenceTimeMs;
  final List<int> tokenIds;
  final List<String> tokenStrings;

  DetailedClassificationResult({
    required this.label,
    required this.simpleLogit,
    required this.complexLogit,
    required this.simpleProbability,
    required this.complexProbability,
    required this.inferenceTimeMs,
    required this.tokenIds,
    required this.tokenStrings,
  });
}

class ClassifierService {
  Interpreter? _interpreter;
  Map<String, int> _vocab = {};
  final Map<int, String> _reverseVocab = {};
  int _clsId = 101;
  int _sepId = 102;
  int _unkId = 100;
  final int maxLen = 64;

  Interpreter? get interpreter => _interpreter;
  Map<String, int> get vocab => _vocab;
  int get maxSequenceLength => maxLen;
  /// True once both tokenizer.json and model.tflite loaded successfully.
  bool get isLoaded => _interpreter != null && _vocab.isNotEmpty;

  Future<void> loadModel() async {
    // ── Stage 1: vocab / tokenizer ───────────────────────────────────────────
    try {
      final jsonStr = await rootBundle.loadString('assets/ml/tokenizer.json');
      final jsonObj = json.decode(jsonStr);
      final Map<String, dynamic> vocabRaw =
          jsonObj['model']['vocab'] as Map<String, dynamic>;
      for (var entry in vocabRaw.entries) {
        final val = entry.value as int;
        _vocab[entry.key] = val;
        _reverseVocab[val] = entry.key;
      }
      _clsId = _vocab['[CLS]'] ?? 101;
      _sepId = _vocab['[SEP]'] ?? 102;
      _unkId = _vocab['[UNK]'] ?? 100;
      debugPrint('[Classifier] Vocab loaded: ${_vocab.length} tokens');
    } catch (e) {
      debugPrint('[Classifier] ❌ tokenizer.json missing or malformed — '
          'classifier will default to COMPLEX routing. Error: $e');
      return; // no point loading the model without a vocab
    }

    // ── Stage 2: TFLite model ────────────────────────────────────────────────
    try {
      _interpreter = await Interpreter.fromAsset('assets/ml/model.tflite');
      debugPrint('[Classifier] ✅ MobileBERT classifier ready.');
      if (kDebugMode) {
        debugPrint('--- MODEL TENSOR DIAGNOSTICS ---');
        for (var tensor in _interpreter!.getInputTensors()) {
          debugPrint(
              'Input: ${tensor.name} | Shape: ${tensor.shape} | Type: ${tensor.type}');
        }
        for (var tensor in _interpreter!.getOutputTensors()) {
          debugPrint(
              'Output: ${tensor.name} | Shape: ${tensor.shape} | Type: ${tensor.type}');
        }
        debugPrint('--------------------------------');
        await _runSelfTest();
      }
    } on ArgumentError catch (e) {
      // Thrown when the .tflite file is found but is not a valid FlatBuffer.
      debugPrint('[Classifier] ❌ model.tflite is corrupt or wrong format: $e');
    } catch (e) {
      // Covers UnsatisfiedLinkError (libtensorflowlite.so missing from APK),
      // FileNotFoundException (asset not bundled), and any other TFLite error.
      debugPrint('[Classifier] ❌ Failed to load TFLite interpreter — '
          'likely a native .so linkage issue or missing asset. Error: $e');
    }
  }

  Future<void> _runSelfTest() async {
    print("🧪 Running automatic inference tests...");
    String res1 = await classify("open youtube");
    print("Test 1 ('open youtube') -> Expected: SIMPLE, Got: $res1");
    
    String res2 = await classify("every morning send report to boss");
    print("Test 2 ('every morning...') -> Expected: COMPLEX, Got: $res2");
    
    print("✅ Self-test complete!");
  }

  // WordPiece style tokenizer
  List<int> tokenize(String text) {
    text = text.toLowerCase();
    text = text.replaceAll(RegExp(r'[^\w\s]'), '');
    final words = text.split(RegExp(r'\s+'));
    
    List<int> tokens = [_clsId]; // [CLS]
    
    for (var word in words) {
      if (word.isEmpty) continue;
      
      int start = 0;
      while (start < word.length) {
        int end = word.length;
        bool found = false;
        while (start < end) {
          String subStr = word.substring(start, end);
          if (start > 0) subStr = "##$subStr";
          
          if (_vocab.containsKey(subStr)) {
            tokens.add(_vocab[subStr]!);
            start = end;
            found = true;
            break;
          }
          end--;
        }
        if (!found) {
          tokens.add(_unkId); // [UNK]
          break;
        }
      }
    }
    tokens.add(_sepId); // [SEP]
    return tokens;
  }

  Future<String> classify(String text) async {
    if (_interpreter == null) {
      if (kDebugMode) print("Classifier not loaded, defaulting to COMPLEX");
      return "COMPLEX";
    }

    final tokens = tokenize(text);
    
    // Create tensors (Int32 format)
    List<List<int>> inputIds = List.generate(1, (_) => List.filled(maxLen, 0));
    List<List<int>> attentionMask = List.generate(1, (_) => List.filled(maxLen, 0));
    List<List<int>> tokenTypeIds = List.generate(1, (_) => List.filled(maxLen, 0));
    
    for (int i = 0; i < tokens.length && i < maxLen; i++) {
      inputIds[0][i] = tokens[i];
      attentionMask[0][i] = 1;
    }

    final inputs = <Object>[];
    for (var tensor in _interpreter!.getInputTensors()) {
      if (tensor.name.contains('input_ids')) {
        inputs.add(inputIds);
      } else if (tensor.name.contains('attention_mask')) {
        inputs.add(attentionMask);
      } else if (tensor.name.contains('token_type_ids')) {
        inputs.add(tokenTypeIds);
      } else {
        inputs.add(inputIds); // fallback
      }
    }
    
    // Output tensor [1, 2]
    var output = {0: List.generate(1, (_) => List.filled(2, 0.0))};
    
    try {
      _interpreter!.runForMultipleInputs(inputs, output);
    } catch (e) {
      if (kDebugMode) print("Inference error: $e");
      return "COMPLEX";
    }
    
    final logits = (output[0] as List)[0] as List<double>;
    double simpleLogit = logits[0];
    double complexLogit = logits[1];
    
    // Numerically stable softmax
    double maxLogit = simpleLogit > complexLogit ? simpleLogit : complexLogit;
    double expSimple = exp(simpleLogit - maxLogit);
    double expComplex = exp(complexLogit - maxLogit);
    double sumExp = expSimple + expComplex;
    double probSimple = expSimple / sumExp;
    
    if (kDebugMode) {
      print("Classification logits: Simple: $simpleLogit, Complex: $complexLogit");
      print("Classification prob (Simple): ${probSimple.toStringAsFixed(3)}");
    }

    if (probSimple < 0.85) {
      return "COMPLEX";
    } else {
      return "SIMPLE";
    }
  }

  Future<DetailedClassificationResult> detailedClassify(String text) async {
    final stopwatch = Stopwatch()..start();
    
    if (_interpreter == null) {
      return DetailedClassificationResult(
        label: "NOT LOADED",
        simpleLogit: 0.0,
        complexLogit: 0.0,
        simpleProbability: 0.5,
        complexProbability: 0.5,
        inferenceTimeMs: 0,
        tokenIds: [],
        tokenStrings: [],
      );
    }

    final tokens = tokenize(text);
    final tokenStrings = tokens.map((id) => _reverseVocab[id] ?? '[UNK]').toList();

    // Create tensors (Int32 format)
    List<List<int>> inputIds = List.generate(1, (_) => List.filled(maxLen, 0));
    List<List<int>> attentionMask = List.generate(1, (_) => List.filled(maxLen, 0));
    List<List<int>> tokenTypeIds = List.generate(1, (_) => List.filled(maxLen, 0));
    
    for (int i = 0; i < tokens.length && i < maxLen; i++) {
      inputIds[0][i] = tokens[i];
      attentionMask[0][i] = 1;
    }

    final inputs = <Object>[];
    for (var tensor in _interpreter!.getInputTensors()) {
      if (tensor.name.contains('input_ids')) {
        inputs.add(inputIds);
      } else if (tensor.name.contains('attention_mask')) {
        inputs.add(attentionMask);
      } else if (tensor.name.contains('token_type_ids')) {
        inputs.add(tokenTypeIds);
      } else {
        inputs.add(inputIds); // fallback
      }
    }
    
    // Output tensor [1, 2]
    var output = {0: List.generate(1, (_) => List.filled(2, 0.0))};
    
    try {
      _interpreter!.runForMultipleInputs(inputs, output);
    } catch (e) {
      if (kDebugMode) print("Inference error: $e");
      return DetailedClassificationResult(
        label: "ERROR",
        simpleLogit: 0.0,
        complexLogit: 0.0,
        simpleProbability: 0.5,
        complexProbability: 0.5,
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
        tokenIds: tokens,
        tokenStrings: tokenStrings,
      );
    }
    
    final logits = (output[0] as List)[0] as List<double>;
    double simpleLogit = logits[0];
    double complexLogit = logits[1];
    
    // Numerically stable softmax
    double maxLogit = simpleLogit > complexLogit ? simpleLogit : complexLogit;
    double expSimple = exp(simpleLogit - maxLogit);
    double expComplex = exp(complexLogit - maxLogit);
    double sumExp = expSimple + expComplex;
    double simpleProbability = expSimple / sumExp;
    double complexProbability = expComplex / sumExp;
    
    stopwatch.stop();
    final inferenceTimeMs = stopwatch.elapsedMilliseconds;

    final String label = (simpleProbability < 0.85) ? "COMPLEX" : "SIMPLE";

    return DetailedClassificationResult(
      label: label,
      simpleLogit: simpleLogit,
      complexLogit: complexLogit,
      simpleProbability: simpleProbability,
      complexProbability: complexProbability,
      inferenceTimeMs: inferenceTimeMs,
      tokenIds: tokens,
      tokenStrings: tokenStrings,
    );
  }
}
