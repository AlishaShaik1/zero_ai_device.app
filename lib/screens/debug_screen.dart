import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ZeroController>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Developer Tools', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Simulate Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 10),
          _buildButton('Simulate Mic Listen', () => controller.startRecording()),
          const SizedBox(height: 10),
          _buildButton('Simulate Processing', () => controller.handleTextCommand("dummy complex task")),
          const SizedBox(height: 10),
          _buildButton('Simulate Stop Mic', () => controller.stopRecording()),
          const Divider(height: 40, color: Colors.white24),
          Text('Logs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              controller.lastResponse.isEmpty ? 'No recent logs' : controller.lastResponse,
              style: const TextStyle(color: Color(0xFF34D399), fontFamily: 'monospace'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00C9C8).withValues(alpha: 0.15),
        foregroundColor: const Color(0xFF00C9C8),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
