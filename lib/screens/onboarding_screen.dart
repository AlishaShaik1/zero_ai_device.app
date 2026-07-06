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

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Meet Zero',
      'desc': 'A revolutionary wearable AI that sees, hears, and acts on your behalf.',
      'icon': Icons.fingerprint,
    },
    {
      'title': 'Permissions',
      'desc': 'Zero needs access to your microphone, camera, bluetooth, and notifications to function fully.',
      'icon': Icons.admin_panel_settings,
      'isPermission': true,
    },
    {
      'title': 'Always Connected',
      'desc': 'Seamless integration with a wide range of ESP chips and BLE devices in the background.',
      'icon': Icons.bluetooth_connected,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Prevent manual swiping past permissions
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Icon(
                          _slides[index]['icon'],
                          size: 80,
                          color: const Color(0xFF00C9C8),
                        ),
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 48),
                      Text(
                        _slides[index]['title'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          _slides[index]['desc'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                        ),
                      ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
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
                      onPressed: () => _handleNext(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C9C8),
                        foregroundColor: const Color(0xFF0A0A0F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1 ? 'Start Setup' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
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
    );
  }

  Future<void> _handleNext() async {
    final currentSlide = _slides[_currentPage];
    
    if (currentSlide['isPermission'] == true) {
      await _requestPermissions();
    }

    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    } else {
      _finishOnboarding(context);
    }
  }

  Future<void> _requestPermissions() async {
    List<Permission> permissions = [
      Permission.microphone,
      Permission.camera,
      Permission.notification, // For background services
    ];
    
    await permissions.request();
  }

  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.PREF_ONBOARDING_DONE, true);
    
    if (context.mounted) {
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
