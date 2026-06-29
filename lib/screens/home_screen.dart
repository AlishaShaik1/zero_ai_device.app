import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';
import '../models/ring_state.dart';
import '../widgets/zero_pet_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _waveController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

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

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
    ));
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _waveController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ZeroController>();
    final state = controller.ringState;
    final isConnected = state.connectionState == RingConnectionState.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, controller, state, isConnected),
            const Spacer(flex: 1),
            _buildCentralOrb(controller, state, isConnected),
            const SizedBox(height: 24),
            _buildResponseArea(controller, state),
            const Spacer(flex: 1),
            _buildCommandInput(controller),
            const SizedBox(height: 8),
            _buildQuickActions(controller, state),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ZeroController controller,
      RingState state, bool isConnected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Connection indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isConnected ? const Color(0xFF00C9C8) : Colors.white)
                    .withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? const Color(0xFF00C9C8)
                        : const Color(0xFF444444),
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00C9C8)
                                  .withValues(alpha: 0.6),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Zero Ring' : 'Searching…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Mouse mode badge
          if (state.isMouseModeActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C9C8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '🖱️ Air Mouse',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00C9C8)),
              ),
            ),
          const SizedBox(width: 8),
          _glassIcon(Icons.tune_rounded, () => Navigator.pushNamed(context, '/settings')),
          const SizedBox(width: 8),
          _glassIcon(Icons.bug_report_rounded, () => Navigator.pushNamed(context, '/debug')),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildCentralOrb(
      ZeroController controller, RingState state, bool isConnected) {
    final isRecording = state.isRecording;
    final isProcessing = controller.isProcessing;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isRecording) {
          controller.stopRecording();
        } else {
          controller.startRecording();
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        controller.onPetTapped();
      },
      child: AnimatedBuilder(
        animation: _breatheController,
        builder: (context, child) {
          final breathe = _breatheController.value;
          final orbSize = 200.0 + (isRecording ? breathe * 20 : breathe * 6);
          final glowOpacity = isRecording
              ? 0.4 + breathe * 0.3
              : isProcessing
                  ? 0.3 + breathe * 0.2
                  : 0.08 + breathe * 0.06;

          return SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: orbSize + 60,
                  height: orbSize + 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _emotionColor(state.currentEmotion)
                            .withValues(alpha: glowOpacity),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),

                // Glass ring border
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.03),
                        Colors.white.withValues(alpha: 0.01),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: _emotionColor(state.currentEmotion)
                          .withValues(alpha: 0.3 + breathe * 0.2),
                      width: 1.5,
                    ),
                  ),
                ),

                // Ring pet widget!
                ClipOval(
                  child: Container(
                    width: orbSize - 40,
                    height: orbSize - 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF12121A),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: (orbSize - 40) / 200.0,
                        child: ZeroPetWidget(
                          emotion: state.currentEmotion,
                          audioLevel: state.audioLevel,
                          isConnected: isConnected,
                        ),
                      ),
                    ),
                  ),
                ),

                // Emotion overlay text
                Positioned(
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _emotionColor(state.currentEmotion)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isRecording
                          ? '🎤 Listening…'
                          : isProcessing
                              ? '🧠 Thinking…'
                              : _emotionLabel(state.currentEmotion),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _emotionColor(state.currentEmotion),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Recording waves
                if (isRecording) _buildRecordingWaves(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingWaves() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(260, 260),
          painter: _WaveRingPainter(
            progress: _waveController.value,
            color: const Color(0xFF00C9C8),
          ),
        );
      },
    );
  }

  Widget _buildResponseArea(ZeroController controller, RingState state) {
    final response = controller.lastResponse;
    if (response.isEmpty) return const SizedBox(height: 60);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          response,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildCommandInput(ZeroController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask Zero anything…',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    controller.handleTextCommand(text.trim());
                    _textController.clear();
                    _focusNode.unfocus();
                  }
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  controller.handleTextCommand(text);
                  _textController.clear();
                  _focusNode.unfocus();
                } else {
                  if (controller.ringState.isRecording) {
                    controller.stopRecording();
                  } else {
                    controller.startRecording();
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C9C8), Color(0xFF00B0B0)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C9C8).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  _textController.text.trim().isNotEmpty
                      ? Icons.arrow_upward_rounded
                      : Icons.mic_rounded,
                  color: const Color(0xFF0A0A0F),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ZeroController controller, RingState state) {
    final actions = [
      _QuickAction(Icons.mouse_rounded, 'Mouse',
          state.isMouseModeActive, () => controller.toggleMouseMode()),
      _QuickAction(Icons.camera_alt_rounded, 'Camera',
          false, () => controller.captureAndAnalyze()),
      _QuickAction(Icons.search_rounded, 'Search',
          false, () => controller.handleTextCommand('search the web')),
      _QuickAction(Icons.grid_view_rounded, 'Skills',
          false, () => Navigator.pushNamed(context, '/skills')),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((a) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              a.onTap();
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: a.active
                    ? const Color(0xFF00C9C8).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: a.active
                      ? const Color(0xFF00C9C8).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.icon,
                      size: 22,
                      color: a.active
                          ? const Color(0xFF00C9C8)
                          : Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(height: 4),
                  Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: a.active
                          ? const Color(0xFF00C9C8)
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _emotionColor(ZeroEmotion emotion) {
    switch (emotion) {
      case ZeroEmotion.happy:
        return const Color(0xFF00C9C8);
      case ZeroEmotion.thinking:
        return const Color(0xFF8B5CF6);
      case ZeroEmotion.excited:
        return const Color(0xFFF59E0B);
      case ZeroEmotion.sleeping:
        return const Color(0xFF475569);
      case ZeroEmotion.surprised:
        return const Color(0xFFEF4444);
      case ZeroEmotion.listening:
        return const Color(0xFF3B82F6);
    }
  }

  String _emotionLabel(ZeroEmotion emotion) {
    switch (emotion) {
      case ZeroEmotion.happy:
        return '✨ Tap to talk';
      case ZeroEmotion.thinking:
        return '🧠 Processing';
      case ZeroEmotion.excited:
        return '⚡ Excited';
      case ZeroEmotion.sleeping:
        return '💤 Sleeping';
      case ZeroEmotion.surprised:
        return '😲 Surprised';
      case ZeroEmotion.listening:
        return '🎤 Listening';
    }
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  _QuickAction(this.icon, this.label, this.active, this.onTap);
}

class _WaveRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = 100.0 + phase * 30;
      final opacity = (1.0 - phase) * 0.3;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveRingPainter old) =>
      old.progress != progress;
}
