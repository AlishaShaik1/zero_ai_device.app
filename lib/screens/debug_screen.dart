import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ZeroController>();
    final state = controller.ringState;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Developer Debug', style: TextStyle(fontFamily: 'monospace', color: Colors.lightGreenAccent, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.lightGreenAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTerminalBlock('SYSTEM STATE', [
              'Connection: ${state.connectionState.name}',
              'Emotion: ${state.currentEmotion.name}',
              'Is Recording: ${state.isRecording}',
              'Is Processing: ${controller.isProcessing}',
              'Active Model: ${state.activeModel.name}',
              'Air Mouse Active: ${state.isMouseModeActive}',
            ]),
            const SizedBox(height: 16),
            _buildTerminalBlock('VOICE PIPELINE', [
              'Wake Word Engine: ${controller.isWakeWordListening ? "ACTIVE" : "INACTIVE"}',
              'STT Engine: ${controller.voicePipelineService.isListening ? "LISTENING" : "IDLE"}',
              'Last Transcript: "${controller.voicePipelineService.recognizedWords}"',
            ]),
            const SizedBox(height: 16),
            _buildTerminalBlock('ROUTING & MODELS', [
              'Last Router Output: ${controller.debugRouting.isEmpty ? "N/A" : controller.debugRouting}',
              'Qwen Nano: ${controller.lifecycleManager.qwenState.name.toUpperCase()}',
              'Gemma Prime: ${controller.lifecycleManager.gemmaState.name.toUpperCase()}',
              'TTS Engine: ${controller.lifecycleManager.ttsState.name.toUpperCase()}',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalBlock(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.lightGreenAccent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[$title]', style: const TextStyle(color: Colors.lightGreenAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          const Divider(color: Colors.lightGreenAccent),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('> $l', style: const TextStyle(color: Colors.green, fontFamily: 'monospace', fontSize: 13)),
          )),
        ],
      ),
    );
  }
}
