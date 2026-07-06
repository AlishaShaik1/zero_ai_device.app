import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/zero_controller.dart';
import '../models/ring_state.dart';

class FloatingControlBar extends StatelessWidget {
  final ZeroController controller;
  final RingState state;
  final VoidCallback onSettingsTap;
  final VoidCallback onKeyboardTap;

  const FloatingControlBar({
    Key? key,
    required this.controller,
    required this.state,
    required this.onSettingsTap,
    required this.onKeyboardTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIconButton(Icons.keyboard_rounded, onKeyboardTap),
                _buildMainActionButton(),
                _buildIconButton(Icons.settings_rounded, onSettingsTap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
      ),
    );
  }

  Widget _buildMainActionButton() {
    final isRecording = state.isRecording;
    final isProcessing = controller.isProcessing;

    return GestureDetector(
      onTap: () {
        if (isRecording) {
          controller.stopRecording();
        } else if (isProcessing) {
          // If we had a cancel generation method, we'd call it here
        } else {
          controller.startRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isRecording 
                ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)] // Red for Stop
                : [const Color(0xFF00C9C8), const Color(0xFF00E5FF)], // Cyan for Mic
          ),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? const Color(0xFFF43F5E) : const Color(0xFF00C9C8)).withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              isProcessing 
                  ? Icons.stop_rounded // Stop generating
                  : isRecording
                      ? Icons.stop_rounded // Stop recording
                      : Icons.mic_rounded, // Start recording
              key: ValueKey<bool>(isRecording || isProcessing),
              color: const Color(0xFF0A0A0F),
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
