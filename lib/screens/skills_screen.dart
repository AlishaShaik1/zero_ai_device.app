import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';
import '../theme/app_colors.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> skills = const [
    {'name': 'Smart Home', 'icon': Icons.home},
    {'name': 'Music', 'icon': Icons.music_note},
    {'name': 'Timer', 'icon': Icons.timer},
    {'name': 'Weather', 'icon': Icons.cloud},
    {'name': 'News', 'icon': Icons.article},
    {'name': 'Air Mouse', 'icon': Icons.mouse},
    {'name': 'Lights', 'icon': Icons.lightbulb},
    {'name': 'Lock', 'icon': Icons.lock},
    {'name': 'Send Text', 'icon': Icons.message},
    {'name': 'Maps', 'icon': Icons.map},
    {'name': 'Translate', 'icon': Icons.translate},
    {'name': 'Calculate', 'icon': Icons.calculate},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Skills', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
        ),
        itemCount: skills.length,
        itemBuilder: (context, index) {
          final skill = skills[index];
          return InkWell(
            onTap: () {
              if (skill['name'] == 'Air Mouse') {
                context.read<ZeroController>().toggleMouseMode();
              } else {
                context.read<ZeroController>().handleTextCommand('trigger ${skill['name']}');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Triggered ${skill['name']}'),
                  backgroundColor: const Color(0xFF00C9C8),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(skill['icon'], color: const Color(0xFF00C9C8), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    skill['name'],
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
