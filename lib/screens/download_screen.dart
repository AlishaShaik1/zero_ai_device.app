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
  bool _isNavigating = false;

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

          if (service.allDownloaded && !_isNavigating) {
            _isNavigating = true;
            Future.microtask(() {
              if (mounted) Navigator.pushReplacementNamed(context, '/home');
            });
          }

          return Stack(
            children: [
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 32),
                              const Text(
                                'ZERO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 5,
                                  color: Color(0xFF00C9C8),
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              Expanded(
                                child: Center(
                                  child: _buildProductHero(progress, service.isDownloading),
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
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
                              
                              const SizedBox(height: 32),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: _buildProgressTrack(progress, pct, hasFailed, service),
                              ),
                              
                              const SizedBox(height: 18),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: service.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, index) {
                                    final item = service.items[index];
                                    return _buildModelCard(item);
                                  },
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                      onPressed: service.allDownloaded
                                          ? () => Navigator.pushReplacementNamed(context, '/home')
                                          : service.isDownloading
                                              ? () => service.cancelAll()
                                              : () => service.downloadAll(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: service.allDownloaded
                                          ? Colors.white
                                          : service.isDownloading
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : const Color(0xFF00C9C8),
                                      foregroundColor: service.isDownloading
                                          ? Colors.white
                                          : const Color(0xFF070710),
                                      disabledBackgroundColor: Colors.white10,
                                      disabledForegroundColor: Colors.white30,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      elevation: 0,
                                    ),
                                      child: Text(
                                        service.allDownloaded
                                            ? 'Get Started'
                                            : service.isDownloading
                                                ? 'Pause Download ($pct%)'
                                                : 'Start Download',
                                        style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                          color: service.allDownloaded
                                              ? const Color(0xFF070710)
                                              : service.isDownloading
                                                  ? Colors.white
                                                  : const Color(0xFF070710),
                                        ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: service.allDownloaded ? 40 : 12),
                              
                              if (!service.allDownloaded)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 32),
                                  child: Column(
                                    children: [
                                      Text(
                                        service.statusMessage.isNotEmpty
                                            ? service.statusMessage
                                            : 'Waiting to start...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.5),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Please keep the app open while downloading.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.25),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductHero(double progress, bool isActive) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, __) {
        final glow = _glowController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
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

            Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF12121E),
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

  Widget _buildProgressTrack(
      double progress, int pct, bool hasFailed, DownloadService service) {
    return Column(
      children: [
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

  Widget _buildModelCard(ModelDownloadItem item) {
    final isActive = item.status == DownloadStatus.downloading;
    final isVerifying = item.status == DownloadStatus.verifying;
    final isDone = item.status == DownloadStatus.completed;
    final isFailed = item.status == DownloadStatus.failed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive || isVerifying ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00C9C8).withValues(alpha: 0.35)
              : isVerifying
                  ? const Color(0xFFA855F7).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF34D399)
                      : isFailed
                          ? const Color(0xFFFF6B6B)
                          : isVerifying
                              ? const Color(0xFFA855F7)
                              : isActive
                                  ? const Color(0xFF00C9C8)
                                  : Colors.white.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  boxShadow: isActive || isVerifying
                      ? [
                          BoxShadow(
                            color: (isVerifying ? const Color(0xFFA855F7) : const Color(0xFF00C9C8)).withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                isDone
                    ? 'Ready'
                    : isFailed
                        ? 'Retrying'
                        : isVerifying
                            ? 'Verifying...'
                            : '${(item.progress * 100).toInt()}%',
                style: TextStyle(
                  color: isDone
                      ? const Color(0xFF34D399)
                      : isFailed
                          ? const Color(0xFFFF6B6B)
                          : isVerifying
                              ? const Color(0xFFA855F7)
                              : const Color(0xFF00C9C8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: item.progress.clamp(0.0, 1.0)),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: isVerifying ? null : value,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDone
                        ? const Color(0xFF34D399)
                        : isFailed
                            ? const Color(0xFFFF6B6B)
                            : isVerifying
                                ? const Color(0xFFA855F7)
                                : const Color(0xFF00C9C8),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          isActive || isVerifying
              ? Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isVerifying ? const Color(0xFFA855F7) : const Color(0xFF00C9C8)
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVerifying 
                          ? 'Checking SHA-256 integrity...'
                          : '${(item.fileSizeMB * item.progress).toStringAsFixed(1)} MB / ${item.fileSizeMB.toStringAsFixed(0)} MB  •  ${item.downloadSpeedMBps > 0 ? "${item.downloadSpeedMBps.toStringAsFixed(1)} MB/s" : "Calculating..."}',
                      style: TextStyle(
                        color: (isVerifying ? const Color(0xFFA855F7) : const Color(0xFF00C9C8)).withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Text(
                  isDone
                      ? 'Downloaded and ready'
                      : isFailed
                          ? (item.errorMessage ?? 'Retrying shortly')
                          : 'Waiting to start',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                  ),
                ),
        ],
      ),
    );
  }
}

class _ThinProgressRing extends CustomPainter {
  final double progress;
  final double glow;
  _ThinProgressRing({required this.progress, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    if (progress <= 0.005) return;

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
