import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/download_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/skills_screen.dart';
import 'screens/classifier_test_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/connectors_screen.dart';
import 'theme/app_theme.dart';

class ZeroRingApp extends StatelessWidget {
  const ZeroRingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero Ring',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/download': (_) => const DownloadScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/skills': (_) => const SkillsScreen(),
        '/classifier_test': (_) => const ClassifierTestScreen(),
        '/debug': (_) => const DebugScreen(),
        '/connectors': (_) => const ConnectorsScreen(),
      },
    );
  }
}
