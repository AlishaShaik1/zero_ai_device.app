import 'package:flutter/material.dart';

class AppColors {
  // ── Core Palette ──────────────────────────────────────────────────────────
  static const Color background      = Color(0xFFF0F2F5);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color surfaceLight    = Color(0xFFF7F8FA);
  static const Color surfaceDark     = Color(0xFFE8EBF0);

  // ── Skeuomorphic Depth ────────────────────────────────────────────────────
  static const Color shadowLight     = Color(0xFFFFFFFF);
  static const Color shadowDark      = Color(0xFFCDD0D8);
  static const Color innerShadow     = Color(0xFFDDE0E8);

  // ── Accent / Cyan (from ring's OLED display) ──────────────────────────────
  static const Color primary         = Color(0xFF00C9C8);   // cyan teal
  static const Color primaryGlow     = Color(0x3300C9C8);
  static const Color primaryDim      = Color(0xFF7FE4E4);
  static const Color accent          = Color(0xFF00E5FF);
  static const Color accentSoft      = Color(0xFF80F0FF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFF1A1E2E);
  static const Color textSecondary   = Color(0xFF6B7280);
  static const Color textTertiary    = Color(0xFFAAB0BC);
  static const Color textOnDark      = Color(0xFFFFFFFF);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success         = Color(0xFF34D399);
  static const Color warning         = Color(0xFFFBBF24);
  static const Color danger          = Color(0xFFF87171);
  static const Color error           = Color(0xFFF87171);
  static const Color info            = Color(0xFF60A5FA);

  // ── Ring Hardware Colors ──────────────────────────────────────────────────
  static const Color ringBody        = Color(0xFFF5F6F8);
  static const Color ringChip        = Color(0xFF2A2D3A);
  static const Color ringDisplay     = Color(0xFF0D0F14);
  static const Color ringConnector   = Color(0xFFD4A843);
  static const Color ringLens        = Color(0xFF1A1A2E);

  // ── Legacy aliases (for backward compat with download_screen etc.) ────────
  static const Color backgroundGradientEnd = Color(0xFF1A1E2E);
  static const Color zeroPetBody     = Color(0xFF1A1A24);
  static const Color zeroPetEye      = Color(0xFF00C9C8);
  static const Color zeroPetBorder   = Color(0xFF333344);
  static const Color primaryLight    = Color(0xFF7FE4E4);
  static const Color accentLight     = Color(0xFF80F0FF);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C9C8), Color(0xFF0099A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFEEF0F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1E2130), Color(0xFF2A2D3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Neumorphic Helpers ────────────────────────────────────────────────────
  static List<BoxShadow> outerShadow({double blur = 20, double spread = 0}) => [
    BoxShadow(
      color: shadowLight,
      offset: Offset(-blur * 0.3, -blur * 0.3),
      blurRadius: blur,
      spreadRadius: spread,
    ),
    BoxShadow(
      color: shadowDark.withValues(alpha: 0.6),
      offset: Offset(blur * 0.3, blur * 0.3),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  static List<BoxShadow> pressedShadow({double blur = 10}) => [
    BoxShadow(
      color: shadowDark.withValues(alpha: 0.4),
      offset: const Offset(-2, -2),
      blurRadius: blur * 0.5,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: shadowLight,
      offset: const Offset(2, 2),
      blurRadius: blur * 0.5,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> glowShadow({Color? color, double intensity = 0.4}) => [
    BoxShadow(
      color: (color ?? primary).withValues(alpha: intensity),
      blurRadius: 30,
      spreadRadius: 5,
    ),
    BoxShadow(
      color: (color ?? primary).withValues(alpha: intensity * 0.4),
      blurRadius: 60,
      spreadRadius: 15,
    ),
  ];
}
