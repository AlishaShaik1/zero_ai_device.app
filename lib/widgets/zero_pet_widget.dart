import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ring_state.dart';
import '../theme/app_colors.dart';

class ZeroPetWidget extends StatefulWidget {
  final ZeroEmotion emotion;
  final double audioLevel;
  final bool isConnected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ZeroPetWidget({
    Key? key,
    required this.emotion,
    required this.audioLevel,
    required this.isConnected,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<ZeroPetWidget> createState() => _ZeroPetWidgetState();
}

class _ZeroPetWidgetState extends State<ZeroPetWidget> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _idleController;
  late AnimationController _emotionController;
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  Timer? _blinkTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _idleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat();
    _emotionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

    _scheduleRandomBlink();
  }

  void _scheduleRandomBlink() {
    final delay = 3000 + _random.nextInt(4000); // 3000-7000ms
    _blinkTimer = Timer(Duration(milliseconds: delay), () async {
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
        _scheduleRandomBlink();
      }
    });
  }

  @override
  void didUpdateWidget(ZeroPetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion) {
      _emotionController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    _idleController.dispose();
    _emotionController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _bounceController.forward(from: 0.0).then((_) {
      _bounceController.reverse();
    });
    if (widget.onTap != null) widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _blinkController,
          _idleController,
          _emotionController,
          _bounceController,
          _pulseController,
        ]),
        builder: (context, child) {
          return CustomPaint(
            size: const Size(200, 200),
            painter: ZeroPetPainter(
              emotion: widget.emotion,
              audioLevel: widget.audioLevel,
              blinkProgress: _blinkController.value,
              idleOffset: sin(_idleController.value * 2 * pi) * 3,
              bounceScale: 1.0 + (_bounceController.value * 0.2),
              pulseAlpha: _pulseController.value,
              isConnected: widget.isConnected,
            ),
          );
        },
      ),
    );
  }
}

class ZeroPetPainter extends CustomPainter {
  final ZeroEmotion emotion;
  final double audioLevel;
  final double blinkProgress;
  final double idleOffset;
  final double bounceScale;
  final double pulseAlpha;
  final bool isConnected;

  ZeroPetPainter({
    required this.emotion,
    required this.audioLevel,
    required this.blinkProgress,
    required this.idleOffset,
    required this.bounceScale,
    required this.pulseAlpha,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + idleOffset);

    if (isConnected) {
      final glowPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.2 * pulseAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 95, glowPaint);

      final outerPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.1 * pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, 90, outerPaint);
    }

    final bodyPaint = Paint()
      ..color = AppColors.zeroPetBody
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 75, bodyPaint);

    final borderPaint = Paint()
      ..color = AppColors.zeroPetBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 75, borderPaint);

    canvas.save();
    
    // Convert center for scaling so scaling pivots correctly.
    canvas.translate(center.dx, center.dy);
    canvas.scale(bounceScale, bounceScale);
    canvas.translate(-center.dx, -center.dy);

    switch (emotion) {
      case ZeroEmotion.happy:
        _drawSquareEyes(canvas, center, blinkProgress);
        _drawSmile(canvas, center, false);
        break;
      case ZeroEmotion.thinking:
        _drawSquintEyes(canvas, center);
        _drawThinkingDots(canvas, center);
        break;
      case ZeroEmotion.excited:
        _drawStarEyes(canvas, center);
        _drawSmile(canvas, center, true);
        break;
      case ZeroEmotion.sleeping:
        _drawClosedEyeLines(canvas, center);
        _drawZFloat(canvas, center);
        break;
      case ZeroEmotion.surprised:
        _drawCircleEyes(canvas, center, true);
        _drawOmouth(canvas, center);
        break;
      case ZeroEmotion.listening:
        _drawSquareEyes(canvas, center, blinkProgress, wide: true);
        break;
    }

    canvas.restore();

    if (audioLevel > 0.05 && emotion == ZeroEmotion.listening) {
      _drawWaveformArc(canvas, center, audioLevel);
    }
  }

  void _drawSquareEyes(Canvas canvas, Offset center, double blink, {bool wide = false}) {
    final paint = Paint()..color = AppColors.accent..style = PaintingStyle.fill;
    final width = wide ? 24.0 : 18.0;
    final height = 14 * (1 - blink) + 1;
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + const Offset(-22, -10), width: width, height: height),
      const Radius.circular(4),
    );
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + const Offset(22, -10), width: width, height: height),
      const Radius.circular(4),
    );
    canvas.drawRRect(leftRect, paint);
    canvas.drawRRect(rightRect, paint);
  }

  void _drawStarEyes(Canvas canvas, Offset center) {
    final paint = Paint()..color = AppColors.accent..style = PaintingStyle.fill;
    _drawStar(canvas, paint, center + const Offset(-22, -10));
    _drawStar(canvas, paint, center + const Offset(22, -10));
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center) {
    final path = Path();
    int points = 5;
    double outerRadius = 12;
    double innerRadius = 5;
    for (int i = 0; i < points * 2; i++) {
      double r = i % 2 == 0 ? outerRadius : innerRadius;
      double a = (i * pi / points) - pi / 2;
      double x = center.dx + r * cos(a);
      double y = center.dy + r * sin(a);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCircleEyes(Canvas canvas, Offset center, bool large) {
    final paint = Paint()..color = AppColors.accent..style = PaintingStyle.fill;
    final radius = large ? 12.0 : 8.0;
    canvas.drawCircle(center + const Offset(-22, -10), radius, paint);
    canvas.drawCircle(center + const Offset(22, -10), radius, paint);
  }

  void _drawSquintEyes(Canvas canvas, Offset center) {
    final paint = Paint()..color = AppColors.accent..style = PaintingStyle.fill;
    final leftRect = Rect.fromCenter(center: center + const Offset(-22, -10), width: 18, height: 3);
    final rightRect = Rect.fromCenter(center: center + const Offset(22, -10), width: 18, height: 3);
    canvas.drawRect(leftRect, paint);
    canvas.drawRect(rightRect, paint);
  }

  void _drawClosedEyeLines(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final leftPath = Path()..addArc(Rect.fromCenter(center: center + const Offset(-22, -8), width: 18, height: 10), pi, pi);
    final rightPath = Path()..addArc(Rect.fromCenter(center: center + const Offset(22, -8), width: 18, height: 10), pi, pi);
    canvas.drawPath(leftPath, paint);
    canvas.drawPath(rightPath, paint);
  }

  void _drawSmile(Canvas canvas, Offset center, bool wide) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final width = wide ? 40.0 : 20.0;
    final height = wide ? 20.0 : 10.0;
    final path = Path()..addArc(Rect.fromCenter(center: center + const Offset(0, 15), width: width, height: height), 0, pi);
    canvas.drawPath(path, paint);
  }

  void _drawOmouth(Canvas canvas, Offset center) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(center + const Offset(0, 15), 6, paint);
  }

  void _drawThinkingDots(Canvas canvas, Offset center) {
    final paint = Paint()..color = AppColors.accent..style = PaintingStyle.fill;
    // Simplified static dots for thinking
    canvas.drawCircle(center + const Offset(-15, -40), 4, paint);
    canvas.drawCircle(center + const Offset(0, -45), 5, paint);
    canvas.drawCircle(center + const Offset(15, -40), 4, paint);
  }

  void _drawZFloat(Canvas canvas, Offset center) {
    final textPainter = TextPainter(
      text: const TextSpan(text: 'Z', style: TextStyle(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    // Simplified static Z
    textPainter.paint(canvas, center + const Offset(20, -50));
  }

  void _drawWaveformArc(Canvas canvas, Offset center, double level) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromCenter(center: center + const Offset(0, 5), width: 60 + level * 40, height: 40 + level * 40);
    canvas.drawArc(rect, 0, pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
