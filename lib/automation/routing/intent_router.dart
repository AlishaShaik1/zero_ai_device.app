import 'package:flutter/foundation.dart';
import 'package:zero_ring_app/services/classifier_service.dart';

/// Routes user intents to the correct model and automation level.
///
/// Architecture:
///   User speech → MobileBERT classifier (your trained model.tflite)
///     → SIMPLE → Qwen (lightweight, Level 1 OS intents)
///     → COMPLEX → Gemma 4 E4B (Levels 2-4, connectors, multi-step)
///
/// The classifier runs BEFORE any LLM is invoked — this is the first gate.
/// It costs ~5-15ms on-device, saving full Gemma inference for simple tasks.

enum TargetModel { qwen, gemma }
enum AutomationLevel { level1, level2, level3, level4 }

class IntentRoute {
  final TargetModel model;
  final AutomationLevel level;
  final double confidence;
  final String rawClassification; // "SIMPLE" or "COMPLEX"

  const IntentRoute({
    required this.model,
    required this.level,
    required this.confidence,
    required this.rawClassification,
  });

  @override
  String toString() =>
    'IntentRoute(model: ${model.name}, level: ${level.name}, '
    'confidence: ${confidence.toStringAsFixed(3)}, raw: $rawClassification)';
}

class IntentRouter {
  final ClassifierService _classifier;

  /// Keywords that indicate connector/app involvement → skip to Gemma
  static const _connectorKeywords = {
    'canva', 'spotify', 'notion', 'slack', 'gmail', 'calendar',
    'telegram', 'whatsapp', 'instagram', 'drive', 'youtube',
    'twitter', 'discord', 'zoom', 'teams', 'outlook', 'trello',
    'github', 'figma', 'asana', 'todoist', 'reddit', 'linkedin',
    'pinterest', 'tiktok', 'snapchat', 'swiggy', 'zomato',
    'uber', 'ola', 'paytm', 'phonepe', 'gpay', 'amazon',
    'flipkart', 'netflix', 'maps', 'search', 'web', 'find out',
  };

  /// Keywords that indicate multi-step or chained actions → Gemma Level 4
  static const _multiStepIndicators = {
    'then', 'after that', 'and also', 'followed by', 'next',
    'first', 'second', 'finally', 'once done', 'when done',
    'every day', 'every morning', 'every hour', 'schedule',
    'create and send', 'generate and', 'make and',
  };

  /// Level 1 OS-intent verbs — these are the actions Qwen handles
  static const _level1Verbs = {
    'call', 'dial', 'phone', 'ring',
    'text', 'sms', 'message',
    'alarm', 'timer', 'remind', 'reminder',
    'email', 'mail',
    'wifi', 'bluetooth', 'brightness', 'volume', 'flashlight',
    'silent', 'vibrate', 'dnd', 'airplane',
    'screenshot', 'screen',
  };

  IntentRouter(this._classifier);

  /// Route an intent to the correct model and level.
  ///
  /// Decision flow:
  /// 1. Run MobileBERT classifier → SIMPLE or COMPLEX
  /// 2. If SIMPLE + no connector keywords → Qwen Level 1
  /// 3. If SIMPLE + has connector keyword → Gemma Level 3 (simple API call)
  /// 4. If COMPLEX + multi-step indicators → Gemma Level 4
  /// 5. If COMPLEX + connector keyword → Gemma Level 3
  /// 6. If COMPLEX + no connector → Gemma Level 2 (accessibility)
  Future<IntentRoute> route(String userInput) async {
    final result = await _classifier.detailedClassify(userInput);
    final inputLower = userInput.toLowerCase();

    if (kDebugMode) {
      debugPrint('🧠 IntentRouter: "${userInput.length > 50 ? '${userInput.substring(0, 50)}...' : userInput}"');
      debugPrint('   MobileBERT → ${result.label} '
          '(simple: ${result.simpleProbability.toStringAsFixed(3)}, '
          'complex: ${result.complexProbability.toStringAsFixed(3)}, '
          '${result.inferenceTimeMs}ms)');
    }

    // Check for connector and multi-step keywords
    final hasConnector = _connectorKeywords.any(
      (kw) => inputLower.contains(kw),
    );
    final isMultiStep = _multiStepIndicators.any(
      (kw) => inputLower.contains(kw),
    );
    final hasLevel1Verb = _level1Verbs.any(
      (v) => inputLower.split(RegExp(r'\s+')).contains(v),
    );

    IntentRoute route;

    if (result.label == 'SIMPLE') {
      if (hasConnector) {
        // Simple request but targeting a specific app → Level 3
        route = IntentRoute(
          model: TargetModel.gemma,
          level: AutomationLevel.level3,
          confidence: result.simpleProbability,
          rawClassification: result.label,
        );
      } else if (hasLevel1Verb) {
        // Pure OS intent → Qwen Level 1 (fast, lightweight)
        route = IntentRoute(
          model: TargetModel.qwen,
          level: AutomationLevel.level1,
          confidence: result.simpleProbability,
          rawClassification: result.label,
        );
      } else {
        // Simple but doesn't match Level 1 verbs → still try Qwen
        // with fallback to Gemma if Qwen can't handle it
        route = IntentRoute(
          model: TargetModel.qwen,
          level: AutomationLevel.level1,
          confidence: result.simpleProbability,
          rawClassification: result.label,
        );
      }
    } else {
      // COMPLEX classification
      if (isMultiStep) {
        // Multi-step / chained actions → Gemma Level 4 planner
        route = IntentRoute(
          model: TargetModel.gemma,
          level: AutomationLevel.level4,
          confidence: result.complexProbability,
          rawClassification: result.label,
        );
      } else if (hasConnector) {
        // Complex + targets a specific connector → Gemma Level 3
        route = IntentRoute(
          model: TargetModel.gemma,
          level: AutomationLevel.level3,
          confidence: result.complexProbability,
          rawClassification: result.label,
        );
      } else {
        // Complex + no connector → Gemma Level 2 (accessibility automation)
        route = IntentRoute(
          model: TargetModel.gemma,
          level: AutomationLevel.level2,
          confidence: result.complexProbability,
          rawClassification: result.label,
        );
      }
    }

    if (kDebugMode) {
      debugPrint('   → Routed to: ${route.model.name} / ${route.level.name}');
    }

    return route;
  }
}
