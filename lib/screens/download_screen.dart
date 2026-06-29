import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../models/download_model.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({Key? key}) : super(key: key);

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070710),
    ));

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Auto-start immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<DownloadService>();
      if (!service.allDownloaded && !service.isDownloading) {
        service.downloadAll();
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF070710),
      body: Consumer<DownloadService>(
        builder: (context, service, _) {
          final progress = service.weightedProgress;
          final pct = (progress * 100).toInt();
          final hasFailed =
              service.items.any((i) => i.status == DownloadStatus.failed);

          if (service.allDownloaded) {
            Future.microtask(() {
              if (mounted) Navigator.pushReplacementNamed(context, '/home');
            });
          }

          return Stack(
            children: [
              // ── Subtle background radial ────────────────────────────────
              Positioned(
                top: -100,
                left: size.width / 2 - 200,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) => Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C9C8).withValues(
                              alpha: 0.04 + _glowController.value * 0.03),
                          blurRadius: 200,
                          spreadRadius: 100,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),

                    // ── Brand mark ────────────────────────────────────────
                    const Text(
                      'ZERO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 5,
                        color: Color(0xFF00C9C8),
                      ),
                    ),

                    const SizedBox(height: 56),

                    // ── Product image — the hero ──────────────────────────
                    Expanded(
                      child: Center(
                        child: _buildProductHero(progress, service.isDownloading),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── Copy block ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Text(
                            service.allDownloaded
                                ? 'Zero is ready.'
                                : 'Setting up Zero',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            service.allDownloaded
                                ? 'Intelligence online.'
                                : hasFailed
                                    ? 'Connection issue — tap to resume.'
                                    : 'This may take a few minutes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.35),
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Progress track ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _buildProgressTrack(progress, pct, hasFailed, service),
                    ),

                    const SizedBox(height: 40),

                    // ── Enter button (visible only when done) ─────────────
                    AnimatedOpacity(
                      opacity: service.allDownloaded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: service.allDownloaded
                                ? () => Navigator.pushReplacementNamed(
                                    context, '/home')
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF070710),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: service.allDownloaded ? 40 : 12),

                    // ── Background download notice ─────────────────────────
                    if (!service.allDownloaded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Text(
                          'Download continues if you leave this screen',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.2),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Product hero: real ring photo inside a clean frosted disc ──────────────
  Widget _buildProductHero(double progress, bool isActive) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, __) {
        final glow = _glowController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Soft ambient glow behind product
            if (isActive || progress > 0)
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C9C8)
                          .withValues(alpha: 0.06 + glow * 0.06),
                      blurRadius: 80,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),

            // Progress ring — razor thin
            SizedBox(
              width: 230,
              height: 230,
              child: CustomPaint(
                painter: _ThinProgressRing(
                  progress: progress,
                  glow: glow,
                ),
              ),
            ),

            // Product image
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF12121E),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/zero_ring.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 64,
                    color: Color(0xFF00C9C8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Progress track — minimal, like Apple setup ─────────────────────────────
  Widget _buildProgressTrack(
      double progress, int pct, bool hasFailed, DownloadService service) {
    return Column(
      children: [
        // Thin track
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 2,
            color: Colors.white.withValues(alpha: 0.08),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF006E70), Color(0xFF00E5FF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasFailed ? 'Connection lost' : '$pct% complete',
              style: TextStyle(
                fontSize: 12,
                color: hasFailed
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.3),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasFailed && !service.isDownloading)
              GestureDetector(
                onTap: service.retryFailed,
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00C9C8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Razor-thin progress ring ──────────────────────────────────────────────────
class _ThinProgressRing extends CustomPainter {
  final double progress;
  final double glow;
  _ThinProgressRing({required this.progress, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    // Track
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    if (progress <= 0.005) return;

    // Arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF00C9C8).withValues(alpha: 0.7 + glow * 0.3),
    );

    // Tip dot
    if (progress > 0.01) {
      final tipAngle = -pi / 2 + 2 * pi * progress.clamp(0.0, 1.0);
      final tx = c.dx + r * cos(tipAngle);
      final ty = c.dy + r * sin(tipAngle);
      canvas.drawCircle(
        Offset(tx, ty),
        3,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(Offset(tx, ty), 2,
          Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ThinProgressRing old) =>
      old.progress != progress || old.glow != glow;
}
