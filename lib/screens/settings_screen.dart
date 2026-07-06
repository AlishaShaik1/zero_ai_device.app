import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/zero_controller.dart';
import '../services/user_preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedSttLocale;

  @override
  void initState() {
    super.initState();
    final controller = context.read<ZeroController>();
    _selectedSttLocale = controller.preferencesService.sttLocale;
  }

  Future<void> _onLanguageChanged(String newLocale) async {
    final controller = context.read<ZeroController>();
    await controller.preferencesService.setSttLocale(newLocale);

    // Also update TTS immediately to match
    final lang = kSupportedLanguages.firstWhere(
      (l) => l.sttLocale == newLocale,
      orElse: () => kSupportedLanguages.first,
    );
    await controller.preferencesService.setSttLocale(lang.sttLocale);

    setState(() => _selectedSttLocale = newLocale);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language set to ${lang.label}'),
          backgroundColor: const Color(0xFF00C9C8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLang = kSupportedLanguages.firstWhere(
      (l) => l.sttLocale == _selectedSttLocale,
      orElse: () => kSupportedLanguages.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [

          // ─── Voice & Language ─────────────────────────────────────────────
          _buildSection('Voice & Language', [
            _buildLanguagePicker(selectedLang),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.mic_rounded,
              label: 'Speech Recognition',
              value: selectedLang.label,
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.volume_up_rounded,
              label: 'Assistant Voice Language',
              value: selectedLang.label,
            ),
          ]),

          const SizedBox(height: 24),

          // ─── AI Configuration ─────────────────────────────────────────────
          _buildSection('AI Configuration', [
            _buildToggleRow(
              icon: Icons.psychology_rounded,
              title: 'Zero Prime Complex Reasoning',
              subtitle: 'Uses Gemma model for hard questions',
              value: true,
              onChanged: (_) {},
            ),
            _buildDivider(),
            _buildToggleRow(
              icon: Icons.search_rounded,
              title: 'Web Search Access',
              subtitle: 'Allow Zero to search the internet',
              value: true,
              onChanged: (_) {},
            ),
          ]),

          const SizedBox(height: 24),

          // ─── Downloads ────────────────────────────────────────────────────
          _buildSection('Downloads', [
            _buildActionRow(
              icon: Icons.download_rounded,
              title: 'Manage Models',
              value: '3 Installed',
              onTap: () => Navigator.pushNamed(context, '/downloads'),
            ),
            _buildDivider(),
            _buildToggleRow(
              icon: Icons.update_rounded,
              title: 'Auto-update Models',
              subtitle: 'Download updates on Wi-Fi',
              value: false,
              onChanged: (_) {},
            ),
          ]),

          const SizedBox(height: 40),

          Center(
            child: GestureDetector(
              onLongPress: () => Navigator.pushNamed(context, '/debug'),
              child: Text(
                'Zero Ring v1.0.0',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Language Picker Row ─────────────────────────────────────────────────

  Widget _buildLanguagePicker(SupportedLanguage selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C9C8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.language_rounded, color: Color(0xFF00C9C8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Microphone Language',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Language used for voice recognition & speech',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // DropdownButton themed to match the dark UI
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSttLocale,
              dropdownColor: const Color(0xFF1A1A26),
              style: const TextStyle(color: Color(0xFF00C9C8), fontSize: 13, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF00C9C8), size: 18),
              borderRadius: BorderRadius.circular(14),
              items: kSupportedLanguages.map((lang) {
                return DropdownMenuItem<String>(
                  value: lang.sttLocale,
                  child: Text(
                    lang.label,
                    style: TextStyle(
                      color: lang.sttLocale == _selectedSttLocale
                          ? const Color(0xFF00C9C8)
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _onLanguageChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Shell ────────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFF00C9C8).withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Row Widgets ─────────────────────────────────────────────────────────

  Widget _buildDivider() => Divider(
        height: 1,
        indent: 54,
        color: Colors.white.withValues(alpha: 0.06),
      );

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF00C9C8),
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white54, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.25), size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))),
          Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
        ],
      ),
    );
  }
}
