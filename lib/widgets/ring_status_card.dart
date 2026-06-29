import 'package:flutter/material.dart';
import '../models/ring_state.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

class RingStatusCard extends StatelessWidget {
  final RingState ringState;
  final String lastResponse;
  final bool isTyping;

  const RingStatusCard({
    Key? key,
    required this.ringState,
    required this.lastResponse,
    required this.isTyping,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ringState.connectionState == RingConnectionState.connected) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.radio_button_checked, color: AppColors.accent, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v${ringState.firmwareVersion}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                      const Text(
                        'Zero Ring',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (isTyping)
                    const _TypingDots()
                  else
                    Expanded(
                      child: Text(
                        lastResponse,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ringState.activeModel == ActiveModel.prime ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ringState.activeModel == ActiveModel.prime ? AppConstants.MODEL_PRIME_NAME : AppConstants.MODEL_NANO_NAME,
                      style: const TextStyle(fontSize: 10),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.5), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth_searching, color: AppColors.textSecondary, size: 32),
              SizedBox(height: 8),
              Text('Looking for your ring...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({Key? key}) : super(key: key);

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        int dots = (_controller.value * 4).floor();
        return Text('.' * dots, style: const TextStyle(color: AppColors.accent, fontSize: 16));
      },
    );
  }
}
