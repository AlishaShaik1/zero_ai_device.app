import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';
import '../services/classifier_service.dart';
import '../theme/app_colors.dart';

class ClassifierTestScreen extends StatefulWidget {
  const ClassifierTestScreen({Key? key}) : super(key: key);

  @override
  State<ClassifierTestScreen> createState() => _ClassifierTestScreenState();
}

class _ClassifierTestScreenState extends State<ClassifierTestScreen> {
  final TextEditingController _inputController = TextEditingController();
  DetailedClassificationResult? _result;
  bool _isProcessing = false;
  String? _errorMessage;

  final List<Map<String, String>> _presets = [
    {'text': 'say hello', 'type': 'Simple'},
    {'text': 'tell me a joke', 'type': 'Simple'},
    {'text': 'turn on the wifi', 'type': 'Simple'},
    {'text': 'good morning zero', 'type': 'Simple'},
    {'text': 'every morning send report to boss', 'type': 'Complex'},
    {'text': 'order pizza from zomato and pay using gpay', 'type': 'Complex'},
    {'text': 'summarize the latest news and draft an email', 'type': 'Complex'},
    {'text': 'explain quantum computing in simple sentences', 'type': 'Complex'},
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _runInference(String text, ClassifierService service) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final res = await service.detailedClassify(text);
      setState(() {
        _result = res;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Inference error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ZeroController>(
      builder: (context, controller, _) {
        final classifier = controller.classifierService;
        final isLoaded = classifier.interpreter != null;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, AppColors.backgroundGradientEnd],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Model Diagnostics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        _buildStatusIndicator(isLoaded),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          // Model Details Card
                          _buildModelDetailsCard(classifier, isLoaded),
                          const SizedBox(height: 16),

                          // Text Input Card
                          _buildInputCard(classifier, isLoaded),
                          const SizedBox(height: 16),

                          // Presets Card
                          _buildPresetsCard(classifier, isLoaded),
                          const SizedBox(height: 16),

                          // Error Message if any
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                border: Border.all(color: AppColors.error),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Inference Diagnostics Result
                          if (_result != null) ...[
                            _buildResultCard(),
                            const SizedBox(height: 16),
                            _buildTokenizationCard(),
                            const SizedBox(height: 16),
                            _buildRawLogitsCard(),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(bool isLoaded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLoaded ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLoaded ? AppColors.success : AppColors.error, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLoaded ? AppColors.success : AppColors.error,
              boxShadow: [
                BoxShadow(
                  color: isLoaded ? AppColors.success.withValues(alpha: 0.5) : AppColors.error.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 2,
                )
              ]
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLoaded ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isLoaded ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelDetailsCard(ClassifierService service, bool isLoaded) {
    final vocabSize = service.vocab.length;
    final maxLen = service.maxSequenceLength;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Interpreter Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.surfaceLight),
          _buildDetailRow('Model Asset', 'assets/ml/model.tflite'),
          _buildDetailRow('Vocabulary Size', '$vocabSize tokens'),
          _buildDetailRow('Max Sequence Length', '$maxLen tokens'),
          if (isLoaded && service.interpreter != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Input Tensors:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            ...service.interpreter!.getInputTensors().map((t) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• ${t.name} (${t.shape}) | ${t.type}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
              ),
            )),
            const SizedBox(height: 8),
            const Text(
              'Output Tensors:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            ...service.interpreter!.getOutputTensors().map((t) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• ${t.name} (${t.shape}) | ${t.type}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
              ),
            )),
          ],
          if (!isLoaded) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  setState(() => _isProcessing = true);
                  await service.loadModel();
                  setState(() => _isProcessing = false);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Load Model Interpreter', style: TextStyle(fontSize: 12)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildInputCard(ClassifierService service, bool isLoaded) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Query Input',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            enabled: isLoaded && !_isProcessing,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isLoaded 
                  ? 'Type query to classify (e.g. "open zomato and buy chicken roll")...' 
                  : 'Please load model to test...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: (isLoaded && !_isProcessing) 
                  ? () => _runInference(_inputController.text, service) 
                  : null,
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bolt, size: 18),
                        SizedBox(width: 8),
                        Text('Classify Query', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsCard(ClassifierService service, bool isLoaded) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Interactive Presets',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((preset) {
              final isSimple = preset['type'] == 'Simple';
              return ActionChip(
                backgroundColor: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSimple 
                        ? AppColors.success.withValues(alpha: 0.3) 
                        : AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSimple ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      preset['text']!,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
                onPressed: (isLoaded && !_isProcessing) ? () {
                  _inputController.text = preset['text']!;
                  _runInference(preset['text']!, service);
                } : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    final isSimple = result.label == 'SIMPLE';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Classification Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              // Latency
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${result.inferenceTimeMs} ms',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentLight),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.surfaceLight),
          
          // Predicted Badge
          Center(
            child: Column(
              children: [
                const Text(
                  'ROUTED MODEL TARGET',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSimple 
                        ? AppColors.success.withValues(alpha: 0.15) 
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSimple ? AppColors.success : AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSimple ? Icons.face : Icons.psychology, 
                        color: isSimple ? AppColors.success : AppColors.primaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSimple ? 'QWEN CHAT (SIMPLE)' : 'PRIME ROUTE (COMPLEX)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSimple ? AppColors.success : AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSimple 
                      ? 'Triggers local Qwen 0.6B chat sessions' 
                      : 'Triggers larger Prime model/agent workflows',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confidence Progress Bars
          _buildProbabilityRow('SIMPLE (Qwen)', result.simpleProbability, AppColors.success),
          const SizedBox(height: 12),
          _buildProbabilityRow('COMPLEX (Prime)', result.complexProbability, AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildProbabilityRow(String label, double probability, Color color) {
    final percent = (probability * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: probability,
            minHeight: 8,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenizationCard() {
    final result = _result!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.code, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text(
                'WordPiece Tokenization Breakdown',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.surfaceLight),
          
          Text(
            'Tokens generated: ${result.tokenIds.length} (Max seq: 64)',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(result.tokenIds.length, (idx) {
              final tokenStr = result.tokenStrings[idx];
              final tokenId = result.tokenIds[idx];
              final isSpecial = tokenStr == '[CLS]' || tokenStr == '[SEP]' || tokenStr == '[UNK]' || tokenStr.startsWith('[PAD]');
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSpecial ? AppColors.surfaceLight : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSpecial 
                        ? AppColors.textSecondary.withValues(alpha: 0.2) 
                        : AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tokenStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSpecial ? AppColors.textSecondary : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tokenId',
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRawLogitsCard() {
    final result = _result!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bar_chart, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Raw Output Logits',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.surfaceLight),
          
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.surfaceLight, width: 1)),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Class', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Raw Logit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Softmax Prob', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('SIMPLE (Qwen)', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      result.simpleLogit.toStringAsFixed(4),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      result.simpleProbability.toStringAsFixed(6),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.success),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('COMPLEX (Prime)', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      result.complexLogit.toStringAsFixed(4),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      result.complexProbability.toStringAsFixed(6),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.primaryLight),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
