import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  // User input controllers
  final TextEditingController _voiceNameController = TextEditingController(text: 'Anna');
  final TextEditingController _callPhraseController = TextEditingController(text: 'Hello Zero');

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Voice Setup',
      'desc': 'Choose how you want to interact with your wearable agent companion.',
      'icon': Icons.record_voice_over_rounded,
      'isForm': true,
    },
    {
      'title': 'System Permissions',
      'desc': 'Zero needs hardware permissions to hear wake words, capture snaps, and link with the ring.',
      'icon': Icons.admin_panel_settings_rounded,
      'isPermission': true,
    },
  ];

  @override
  void dispose() {
    _voiceNameController.dispose();
    _callPhraseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.03),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Icon(
                              slide['icon'],
                              size: 72,
                              color: const Color(0xFF00C9C8),
                            ),
                          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 32),
                          Text(
                            slide['title'],
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ).animate().fade(delay: 150.ms).slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 12),
                          Text(
                            slide['desc'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                              height: 1.4,
                            ),
                          ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 32),
                          if (slide['isForm'] == true) _buildVoiceProfileForm(),
                          if (slide['isPermission'] == true) _buildPermissionsStatusList(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          width: _currentPage == index ? 24 : 8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF00C9C8)
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C9C8),
                          foregroundColor: const Color(0xFF0A0A0F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1 ? 'Finish Profile' : 'Continue',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceProfileForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _voiceNameController,
          label: 'Voice Agent Name',
          hint: 'e.g. Anna, Siri, Jarvis',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _callPhraseController,
          label: 'Call Wake Word Phrase',
          hint: 'e.g. Hello Zero, Hey Zero',
          icon: Icons.chat_bubble_outline,
        ),
      ],
    ).animate().fade(delay: 450.ms);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF00C9C8), fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF00C9C8), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00C9C8)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildPermissionsStatusList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        children: [
          _PermissionRow(icon: Icons.mic, name: 'Microphone access (required for voice commands)'),
          Divider(color: Colors.white10),
          _PermissionRow(icon: Icons.camera_alt, name: 'Camera access (required for ring snap captures)'),
          Divider(color: Colors.white10),
          _PermissionRow(icon: Icons.bluetooth, name: 'Bluetooth link permissions (ring discovery)'),
        ],
      ),
    ).animate().fade(delay: 450.ms);
  }

  Future<void> _handleNext() async {
    if (_currentPage == 0) {
      if (!_formKey.currentState!.validate()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _requestPermissions();
      await _finishOnboarding();
    }
  }

  Future<void> _requestPermissions() async {
    List<Permission> permissions = [
      Permission.microphone,
      Permission.camera,
      Permission.notification,
    ];
    await permissions.request();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.PREF_ONBOARDING_DONE, true);
    
    // Save configuration settings
    await prefs.setString(AppConstants.PREF_USER_NAME, _voiceNameController.text.trim());
    await prefs.setString('call_phrase', _callPhraseController.text.trim());

    if (mounted) {
      final ds = Provider.of<DownloadService>(context, listen: false);
      final allDownloaded = await ds.checkAllDownloaded();
      if (allDownloaded) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/download');
      }
    }
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String name;

  const _PermissionRow({Key? key, required this.icon, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00C9C8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
