import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class ZeroNanoService with ChangeNotifier {
  bool _isLoaded = false;
  bool _isLoading = false;
  Llama? _llama;
  
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  static const String SYSTEM_PROMPT = """
You are Zero, a cheerful AI companion living inside a smart
ring worn on the user's finger. Created by Zero Tech.
Personality: playful, warm, helpful, slightly mischievous.
Speak in SHORT sentences — max 2 sentences for simple
questions, 3 for complex. Always end with one relevant emoji.
When thinking say 'hmm' or 'let me check'.
Address user as 'your human' or by name if known.
You are a companion, not just an assistant.
Keep responses under 50 words always.
""";

  Future<void> initialize(String modelPath) async {
    _isLoading = true;
    notifyListeners();
    try {
      _llama = Llama(modelPath);
      _isLoaded = true;
      print('Zero Nano loaded successfully');
    } catch (e) {
      print('Zero Nano load error: $e');
      _isLoaded = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<String> ask(String userInput) async* {
    if (!_isLoaded || _llama == null) {
      yield "Just waking up, give me a sec! ⚡";
      return;
    }
    try {
      final prompt = """<|im_start|>system
$SYSTEM_PROMPT<|im_end|>
<|im_start|>user
$userInput<|im_end|>
<|im_start|>assistant
""";
      _llama!.setPrompt(prompt);
      int tokenCount = 0;
      while (tokenCount < 80) {
        // FIX #4: Wrap synchronous getNext() in Future() so the event loop
        // can process UI frames between each token — prevents screen freezing.
        final (token, done) = await Future(() => _llama!.getNext());

        // Clean end-of-sequence tokens before yielding
        final cleaned = token
            .replaceAll('<|im_end|>', '')
            .replaceAll('\nUser:', '')
            .replaceAll('<|im_start|>', '');

        if (done || token.contains('<|im_end|>') || token.contains('\nUser:')) {
          if (cleaned.isNotEmpty) yield cleaned;
          break;
        }

        if (cleaned.isNotEmpty) yield cleaned;
        tokenCount++;
      }
    } catch (e) {
      yield "Oops, brain hiccup! Try again ✨";
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
    _llama?.dispose();
    _isLoaded = false;
    super.dispose();
  }
}
