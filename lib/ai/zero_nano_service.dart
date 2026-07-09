import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class ZeroNanoService with ChangeNotifier {
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _lastLoadError;
  
  LlamaEngine? _engine;
  
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get lastLoadError => _lastLoadError;


  Future<void> initialize(String modelPath) async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('[Zero Nano] Attempting to load native model from path: $modelPath');
      
      final threads = max(1, Platform.numberOfProcessors - 2);
      if (Platform.isAndroid) {
        _engine = await LlamaEngine.spawn(
          libraryPath: 'libllama.so',
          modelParams: ModelParams(path: modelPath),
          contextParams: ContextParams(nCtx: 2048, nThreads: threads),
        );
      } else {
        _engine = await LlamaEngine.spawnFromProcess(
          modelParams: ModelParams(path: modelPath),
          contextParams: ContextParams(nCtx: 2048, nThreads: threads),
        );
      }
      
      _isLoaded = true;
      _lastLoadError = null;
      debugPrint('[Zero Nano] ✅ Native Llama.cpp engine loaded successfully from: $modelPath');
    } catch (e) {
      _lastLoadError = e.toString();
      debugPrint('[Zero Nano] ❌ Native model load error at $modelPath: $e');
      _isLoaded = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<String> ask(String userInput) async* {
    if (!_isLoaded || _engine == null) {
      debugPrint('[Zero Nano] ⚠️ Cannot ask, model is not loaded yet!');
      yield "Just waking up, give me a sec! ⚡";
      return;
    }
    debugPrint('[Zero Nano] ⚡ Sending prompt to native LLM engine: "$userInput"');
    
    EngineSession? session;
    try {
      session = await _engine!.createSession();
      final prompt = """<|im_start|>user
$userInput<|im_end|>
<|im_start|>assistant
""";

      await for (final event in session.generate(
        prompt: prompt,
        maxTokens: 512,
      )) {
        if (event is TokenEvent) {
          final cleaned = event.text
              .replaceAll('<|im_end|>', '')
              .replaceAll('\nUser:', '')
              .replaceAll('<|im_start|>', '');

          if (cleaned.isNotEmpty) yield cleaned;
        }
      }
    } catch (e) {
      debugPrint('[Zero Nano] ❌ Generation error: $e');
      yield "Oops, brain hiccup! Try again ✨";
    } finally {
      if (session != null) {
        await session.dispose();
      }
    }
  }

  Future<bool> isComplexTask(String input) async {
    final complexTriggers = [
      'order', 'buy', 'pay', 'download', 'book',
      'post', 'upload', 'share', 'zomato', 'swiggy',
      'phonepe', 'gpay', 'paytm', 'ola', 'uber',
      'youtube', 'instagram', 'amazon', 'flipkart',
      'summarize', 'explain in detail', 'write a',
      'translate this', 'find and', 'go to and',
      'open and then', 'search and buy'
    ];
    return complexTriggers.any((t) =>
      input.toLowerCase().contains(t));
  }

  Future<bool> isToolTask(String input) async {
    final toolTriggers = [
      'call', 'text', 'message', 'whatsapp', 'sms',
      'email', 'open', 'timer', 'remind', 'alarm',
      'weather', 'wifi', 'bluetooth', 'volume',
      'brightness', 'music', 'play', 'pause', 'next',
      'notification', 'translate', 'mouse', 'cursor'
    ];
    return toolTriggers.any((t) =>
      input.toLowerCase().contains(t));
  }

  String getBridgeResponse() {
    final responses = [
      "Loading Zero Prime for this one, hold on! 🧠",
      "Complex task — warming up the big brain ⚡",
      "On it! Zero Prime coming online now 🚀",
      "Give me a moment, pulling full power 💪"
    ];
    return responses[Random().nextInt(responses.length)];
  }

  @override
  void dispose() {
    _engine?.dispose();
    _isLoaded = false;
    super.dispose();
  }
}
