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

  Future<void> loadModel() async {
    try {
      // 1. Load vocab from tokenizer.json
      final jsonStr = await rootBundle.loadString('assets/ml/tokenizer.json');
      final jsonObj = json.decode(jsonStr);
      Map<String, dynamic> vocabRaw = jsonObj['model']['vocab'];
      for (var entry in vocabRaw.entries) {
        final val = entry.value as int;
        _vocab[entry.key] = val;
        _reverseVocab[val] = entry.key;
      }
      _clsId = _vocab['[CLS]'] ?? 101;
      _sepId = _vocab['[SEP]'] ?? 102;
      _unkId = _vocab['[UNK]'] ?? 100;

      // 2. Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/ml/model.tflite');
      if (kDebugMode) {
        print("✅ Zero AI MobileBERT Classifier loaded!");
        print("--- MODEL TENSOR DIAGNOSTICS ---");
        for (var tensor in _interpreter!.getInputTensors()) {
          print("Input: ${tensor.name} | Shape: ${tensor.shape} | Type: ${tensor.type}");
        }
        for (var tensor in _interpreter!.getOutputTensors()) {
          print("Output: ${tensor.name} | Shape: ${tensor.shape} | Type: ${tensor.type}");
        }
        print("--------------------------------");
        
        // Run automatic test to verify int32/int64
        await _runSelfTest();
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Failed to load classifier: $e");
      }
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
