import 'package:flutter/material.dart';

/// Club Jorge Newbery — Official Color Palette
/// Inspired by the club's shield: black, red, white, gold accents
class AppColors {
  AppColors._();

  // ─── Primary Brand Colors ───────────────────────────────────
  static const Color primary = Color(0xFFC1121F);
  static const Color primaryLight = Color(0xFFE63946);
  static const Color primaryDark = Color(0xFF8B0D15);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ─── Accent / Gold ──────────────────────────────────────────
  static const Color accent = Color(0xFFD4AF37);
  static const Color accentLight = Color(0xFFE6C85B);
  static const Color accentDark = Color(0xFFB8952E);

  // ─── Background & Surface ──────────────────────────────────
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF161616);
  static const Color surfaceLight = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF262626);
  static const Color surfaceElevated = Color(0xFF2A2A2A);
  static const Color card = Color(0xFF1A1A1A);

  // ─── Text ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8F9FA);
  static const Color textSecondary = Color(0xFFADB5BD);
  static const Color textTertiary = Color(0xFF6C757D);
  static const Color textDisabled = Color(0xFF495057);

  // ─── Borders & Dividers ────────────────────────────────────
  static const Color border = Color(0xFF2D2D2D);
  static const Color borderLight = Color(0xFF3A3A3A);
  static const Color divider = Color(0xFF222222);

  // ─── Status Colors ────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color successDark = Color(0xFF1A7A42);
  static const Color warning = Color(0xFFE67E22);
  static const Color warningDark = Color(0xFF8B4C15);
  static const Color error = Color(0xFFE74C3C);
  static const Color errorDark = Color(0xFF8B2E25);
  static const Color info = Color(0xFF3498DB);

  // ─── Match / Sport specific ───────────────────────────────
  static const Color win = Color(0xFF2ECC71);
  static const Color draw = Color(0xFFE67E22);
  static const Color loss = Color(0xFFE74C3C);

  // ─── Opacity variants ────────────────────────────────────
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);
  static Color accentWithOpacity(double opacity) =>
      accent.withValues(alpha: opacity);
  static Color surfaceWithOpacity(double opacity) =>
      surface.withValues(alpha: opacity);

  // ─── Gradients ────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceLight, surface],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x80000000), Color(0xDD000000)],
  );
}
