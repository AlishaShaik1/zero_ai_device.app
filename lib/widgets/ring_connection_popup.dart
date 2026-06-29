import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/ring_state.dart';
import 'ring_painter.dart';

class RingConnectionPopup extends StatefulWidget {
  final RingState state;
  final VoidCallback onDismiss;

  const RingConnectionPopup({Key? key, required this.state, required this.onDismiss}) : super(key: key);

  static void show(BuildContext context, RingState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RingConnectionPopup(
        state: state,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<RingConnectionPopup> createState() => _RingConnectionPopupState();
}

class _RingConnectionPopupState extends State<RingConnectionPopup> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.state.connectionState == RingConnectionState.connected;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.95), // iOS dark mode popup color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 30),
          
          // 3D Skeuomorphic Ring Model
          Expanded(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_animController.value * 0.05),
                  child: Transform.rotate(
                    angle: _animController.value * 0.05,
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: CustomPaint(
                        painter: RingPainter(
                          connected: isConnected,
                          glowIntensity: isConnected ? _animController.value : 0.0,
                          emotion: widget.state.currentEmotion,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          
          const SizedBox(height: 20),
          
          // Device Name
          Text(
            'Zero Ring',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
          
          const SizedBox(height: 10),
          
          // Battery stats (like AirPods)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.battery_charging_full, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                '100%', // Ideally fetch from state
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
          
          const SizedBox(height: 30),
          
          // Done/Connect button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: widget.onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isConnected ? 'Done' : 'Connecting...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
