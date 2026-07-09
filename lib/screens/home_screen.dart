import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';
import '../models/ring_state.dart';
import '../widgets/zero_orb.dart';
import '../widgets/chat_area.dart';
import '../widgets/floating_control_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ));

    // Safely trigger deferred hardware, bluetooth and wake-word init
    // once permissions are ready and HomeScreen is entered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ZeroController>().initializeHardwareAndModels();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleKeyboard() {
    setState(() {
      _isKeyboardVisible = !_isKeyboardVisible;
      if (_isKeyboardVisible) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ZeroController>();
    final state = controller.ringState;
    final isConnected = state.connectionState == RingConnectionState.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBody: true,
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.0,
                  colors: [
                    const Color(0xFF1E1E28).withValues(alpha: 0.5),
                    const Color(0xFF0A0A0F),
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(isConnected, controller),
                
                // Orb Area (Top 40%)
                Expanded(
                  flex: 4,
                  child: Center(
                    child: ZeroOrb(
                      emotion: state.currentEmotion,
                      isRecording: state.isRecording,
                      isProcessing: controller.isProcessing,
                    ).animate(key: const ValueKey('orb_anim')).scale(duration: 800.ms, curve: Curves.easeOutBack),
                  ),
                ),
                
                // Live Transcription (Middle)
                AnimatedBuilder(
                  animation: controller.voicePipelineService,
                  builder: (context, _) {
                    final transcript = controller.voicePipelineService.recognizedWords;
                    if (!controller.voicePipelineService.isListening || transcript.isEmpty) {
                      return const SizedBox(height: 20);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '"$transcript"',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ).animate(key: const ValueKey('transcription_anim')).fade().slideY(begin: 0.2, end: 0),
                    );
                  },
                ),

                // Chat Area (Bottom 60%)
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      ChatArea(conversationManager: controller.conversationManager),
                      
                      // Keyboard Input Overlay
                      if (_isKeyboardVisible)
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: _buildKeyboardInput(controller),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Floating Control Bar
          if (!_isKeyboardVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: FloatingControlBar(
                  controller: controller,
                  state: state,
                  onKeyboardTap: _toggleKeyboard,
                  onSettingsTap: () => Navigator.pushNamed(context, '/settings'),
                ).animate(key: const ValueKey('control_bar_anim')).fade().slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isConnected, ZeroController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? const Color(0xFF00C9C8) : const Color(0xFF444444),
                  boxShadow: isConnected ? [BoxShadow(color: const Color(0xFF00C9C8).withValues(alpha: 0.5), blurRadius: 8)] : [],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'Zero Connected' : 'Searching for Ring...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => controller.togglePreferredModel(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    controller.preferredModel == ActiveModel.nano ? 'Model: Qwen' : 'Model: Gemma',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onDoubleTap: () => Navigator.pushNamed(context, '/debug'),
                child: Icon(Icons.info_outline_rounded, color: Colors.white.withValues(alpha: 0.2), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardInput(ZeroController controller) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E28).withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleKeyboard,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        controller.handleTextCommand(text.trim());
                        _textController.clear();
                        _toggleKeyboard();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty) {
                    controller.handleTextCommand(text);
                    _textController.clear();
                    _toggleKeyboard();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFF00C9C8), Color(0xFF00E5FF)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF00C9C8).withValues(alpha: 0.4), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF0A0A0F), size: 20),
                ),
              ),
            ],
          ),
        ).animate().slideY(begin: 1.0, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
      ),
    );
  }
}
