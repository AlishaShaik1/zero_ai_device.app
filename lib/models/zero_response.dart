import 'ring_state.dart';

class ZeroResponse {
  final String responseText;
  final ZeroEmotion emotion;
  final String? actionToTake;
  final Map<String, dynamic>? actionParameters;
  final double confidence;
  final int processingTimeMs;
  final ActiveModel modelUsed;

  const ZeroResponse({
    required this.responseText,
    required this.emotion,
    this.actionToTake,
    this.actionParameters,
    required this.confidence,
    required this.processingTimeMs,
    required this.modelUsed,
  });

  factory ZeroResponse.empty() {
    return const ZeroResponse(
      responseText: '',
      emotion: ZeroEmotion.happy,
      actionToTake: null,
      actionParameters: null,
      confidence: 0.0,
      processingTimeMs: 0,
      modelUsed: ActiveModel.none,
    );
  }

  factory ZeroResponse.thinking() {
    return const ZeroResponse(
      responseText: 'hmm...',
      emotion: ZeroEmotion.thinking,
      actionToTake: null,
      actionParameters: null,
      confidence: 1.0,
      processingTimeMs: 0,
      modelUsed: ActiveModel.none,
    );
  }
}
