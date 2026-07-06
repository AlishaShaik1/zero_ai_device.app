import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ring_state.dart';

class ZeroOrb extends StatefulWidget {
  final ZeroEmotion emotion;
  final bool isRecording;
  final bool isProcessing;
  final bool isDownloading;
  final double size;

  const ZeroOrb({
    Key? key,
    required this.emotion,
    required this.isRecording,
    required this.isProcessing,
    this.isDownloading = false,
    this.size = 200.0,
  }) : super(key: key);

  @override
  State<ZeroOrb> createState() => _ZeroOrbState();
}

class _ZeroOrbState extends State<ZeroOrb> with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _waveController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _waveController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Color _emotionColor(ZeroEmotion emotion) {
    if (widget.isDownloading) return const Color(0xFF3B82F6);
    switch (emotion) {
      case ZeroEmotion.happy: return const Color(0xFF00E5FF);
      case ZeroEmotion.thinking: return const Color(0xFFA855F7);
      case ZeroEmotion.excited: return const Color(0xFFF59E0B);
      case ZeroEmotion.sleeping: return const Color(0xFF64748B);
      case ZeroEmotion.surprised: return const Color(0xFFF43F5E);
      case ZeroEmotion.listening: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _emotionColor(widget.emotion);
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breatheController, _rotateController]),
        builder: (context, child) {
          final breathe = _breatheController.value;
          final rotate = _rotateController.value;
          
          final currentSize = widget.size + (widget.isRecording ? breathe * 25 : breathe * 8);
          final glowOpacity = widget.isRecording
              ? 0.45 + breathe * 0.3
              : widget.isProcessing
                  ? 0.35 + breathe * 0.2
                  : 0.15 + breathe * 0.1;

          return SizedBox(
            width: widget.size + 80,
            height: widget.size + 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: currentSize + 40,
                  height: currentSize + 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withValues(alpha: glowOpacity),
                        blurRadius: 80,
                        spreadRadius: widget.isRecording ? 20 : 5,
                      ),
                    ],
                  ),
                ),
                
                // Rotation gradient
                if (widget.isProcessing || widget.isDownloading)
                  Transform.rotate(
                    angle: rotate * 2 * pi,
                    child: Container(
                      width: currentSize + 10,
                      height: currentSize + 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            baseColor.withValues(alpha: 0.0),
                            baseColor.withValues(alpha: 0.5),
                            baseColor.withValues(alpha: 0.0),
                            baseColor.withValues(alpha: 0.5),
                            baseColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Core orb
                Container(
                  width: currentSize,
                  height: currentSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        baseColor.withValues(alpha: 0.2),
                        const Color(0xFF0A0A0F),
                      ],
                    ),
                    border: Border.all(
                      color: baseColor.withValues(alpha: 0.5 + breathe * 0.3),
                      width: 2.0,
                    ),
                  ),
                ),

                // Waves if recording
                if (widget.isRecording)
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(widget.size + 80, widget.size + 80),
                        painter: _OrbWavePainter(
                          progress: _waveController.value,
                          color: baseColor,
                          baseRadius: widget.size / 2,
                        ),
                      );
                    },
                  ),
                  
                // Center icon / status
                Icon(
                  widget.isDownloading
                      ? Icons.cloud_download_rounded
                      : widget.isRecording
                          ? Icons.mic_rounded
                          : widget.isProcessing
                              ? Icons.memory_rounded
                              : Icons.lens_blur_rounded,
                  color: baseColor.withValues(alpha: 0.8),
                  size: widget.size * 0.3,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrbWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double baseRadius;

  _OrbWavePainter({required this.progress, required this.color, required this.baseRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = baseRadius + phase * 60;
      final opacity = (1.0 - phase) * 0.5;
      
      final path = Path();
      for (double angle = 0; angle <= 2 * pi; angle += pi / 16) {
        final distortion = sin(angle * 6 + progress * 2 * pi) * (8 * phase);
        final r = radius + distortion;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        
        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      paint.color = color.withValues(alpha: opacity);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbWavePainter old) => old.progress != progress;
}
