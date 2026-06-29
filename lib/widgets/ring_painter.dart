import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/ring_state.dart';
class RingPainter extends CustomPainter {
  final bool connected;
  final double glowIntensity;
  final ZeroEmotion emotion;

  RingPainter({
    required this.connected,
    required this.glowIntensity,
    required this.emotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;
    final strokeWidth = size.width / 4;

    // 1. Shadow for 3D depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, radius * 0.5), width: radius * 2.2, height: radius * 1.5),
      shadowPaint,
    );

    // 2. Outer Transparent/Glass Band (Base)
    final glassPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.3),
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi * 2,
      false,
      glassPaint,
    );

    // 3. Internal Chips and Circuitry (Skeuomorphic depth)
    final pcbPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [
          const Color(0xFF1A1A1A),
          const Color(0xFF2A2A2A),
          const Color(0xFF111111),
        ],
      );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.1,
      pi * 1.8,
      false,
      pcbPaint,
    );

    // Add gold contacts / chips accents
    final goldPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    // Draw small chips
    for (int i = 0; i < 6; i++) {
      double angle = pi * 0.2 + (i * pi / 3);
      double cx = center.dx + radius * cos(angle);
      double cy = center.dy + radius * sin(angle);
      
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle + pi/2);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: strokeWidth * 0.5, height: strokeWidth * 0.3), Paint()..color = const Color(0xFF222222));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: strokeWidth * 0.4, height: strokeWidth * 0.2), Paint()..color = const Color(0xFF111111));
      // Gold pins
      for(int j=-1; j<=1; j++) {
        canvas.drawCircle(Offset(j * 4.0, -strokeWidth*0.15), 1.5, goldPaint);
        canvas.drawCircle(Offset(j * 4.0, strokeWidth*0.15), 1.5, goldPaint);
      }
      canvas.restore();
    }

    // 4. Inner Hollow Edge (Reflections)
    final innerHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawCircle(center, radius - strokeWidth/2, innerHighlight);

    // 5. Top Island with OLED Display
    final islandRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - radius),
      width: size.width * 0.45,
      height: size.height * 0.25,
    );

    final islandPaint = Paint()
      ..color = const Color(0xFF151515)
      ..style = PaintingStyle.fill;
    
    final islandRRect = RRect.fromRectAndRadius(islandRect, const Radius.circular(16));
    canvas.drawRRect(islandRRect, islandPaint);
    
    // Island Border reflection
    final islandBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawRRect(islandRRect, islandBorder);

    // OLED Screen area
    final screenRect = Rect.fromCenter(
      center: Offset(center.dx - 8, center.dy - radius),
      width: size.width * 0.25,
      height: size.height * 0.15,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(screenRect, const Radius.circular(8)), Paint()..color = Colors.black);

    // Cyan Eyes (Zero Emotion)
    final cyanPaint = Paint()
      ..color = const Color(0xFF00FFFF).withValues(alpha: connected ? 0.9 : 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, glowIntensity * 5 + 1);

    // Draw square eyes based on emotion
    if (emotion == ZeroEmotion.happy || emotion == ZeroEmotion.listening || emotion == ZeroEmotion.thinking) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(screenRect.center.dx - 12, screenRect.center.dy), width: 12, height: 12), const Radius.circular(2)),
        cyanPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(screenRect.center.dx + 12, screenRect.center.dy), width: 12, height: 12), const Radius.circular(2)),
        cyanPaint,
      );
    } else {
      // Default / sleeping
      canvas.drawLine(
        Offset(screenRect.center.dx - 16, screenRect.center.dy),
        Offset(screenRect.center.dx - 8, screenRect.center.dy),
        cyanPaint..strokeWidth = 3,
      );
      canvas.drawLine(
        Offset(screenRect.center.dx + 8, screenRect.center.dy),
        Offset(screenRect.center.dx + 16, screenRect.center.dy),
        cyanPaint..strokeWidth = 3,
      );
    }

    // 6. Camera Lens
    final camCenter = Offset(islandRect.right - 14, islandRect.center.dy);
    canvas.drawCircle(camCenter, 10, Paint()..color = const Color(0xFF222222));
    canvas.drawCircle(camCenter, 6, Paint()..color = const Color(0xFF0a0a0a));
    // Lens reflection
    canvas.drawCircle(camCenter.translate(-2, -2), 2, Paint()..color = Colors.white.withValues(alpha: 0.6));

    // 7. Cyan LED indicator
    final ledCenter = Offset(islandRect.right - 14, islandRect.top + 8);
    canvas.drawCircle(
      ledCenter, 
      3, 
      Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: connected ? 1.0 : 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, connected ? glowIntensity * 4 + 2 : 0)
    );
    canvas.drawCircle(ledCenter, 1.5, Paint()..color = Colors.white);

    // 8. Outer Glass Highlights
    final outerHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + strokeWidth/2),
      pi * 1.2,
      pi * 0.4,
      false,
      outerHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) {
    return oldDelegate.connected != connected || 
           oldDelegate.glowIntensity != glowIntensity ||
           oldDelegate.emotion != emotion;
  }
}
