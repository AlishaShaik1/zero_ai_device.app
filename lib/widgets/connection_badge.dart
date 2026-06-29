import 'package:flutter/material.dart';
import '../models/ring_state.dart';
import '../theme/app_colors.dart';

class ConnectionBadge extends StatelessWidget {
  final RingConnectionState state;
  final int batteryLevel;

  const ConnectionBadge({
    Key? key,
    required this.state,
    required this.batteryLevel,
  }) : super(key: key);

  Color _getStateColor() {
    switch (state) {
      case RingConnectionState.scanning:
        return AppColors.warning;
      case RingConnectionState.connecting:
        return AppColors.warning; // yellow/orange
      case RingConnectionState.connected:
        return AppColors.success;
      case RingConnectionState.disconnected:
        return AppColors.error;
    }
  }

  String _getStateText() {
    switch (state) {
      case RingConnectionState.scanning:
        return 'Scanning...';
      case RingConnectionState.connecting:
        return 'Connecting...';
      case RingConnectionState.connected:
        return 'Zero Connected';
      case RingConnectionState.disconnected:
        return 'No Ring';
    }
  }

  IconData _getBatteryIcon() {
    if (batteryLevel >= 90) return Icons.battery_full;
    if (batteryLevel >= 60) return Icons.battery_6_bar;
    if (batteryLevel >= 30) return Icons.battery_3_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStateColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getStateText(),
            style: TextStyle(color: color, fontSize: 12),
          ),
          if (state == RingConnectionState.connected) ...[
            const SizedBox(width: 8),
            Icon(_getBatteryIcon(), size: 14, color: AppColors.success),
            const SizedBox(width: 2),
            Text(
              '$batteryLevel%',
              style: const TextStyle(fontSize: 10, color: AppColors.success),
            ),
          ]
        ],
      ),
    );
  }
}
