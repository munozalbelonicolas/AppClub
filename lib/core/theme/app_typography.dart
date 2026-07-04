import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme_colors.dart';

/// Typography system using Inter font family
/// Clean, professional hierarchy for a sports app
class AppTypography {
  final BuildContext context;
  AppTypography(this.context);

  // ─── Display ────────────────────────────────────────────────
  TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: context.colors.textPrimary,
    letterSpacing: -1.5,
    height: 1.1,
  );

  TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: context.colors.textPrimary,
    letterSpacing: -1.0,
    height: 1.15,
  );

  TextStyle get displaySmall => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: context.colors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // ─── Headlines ─────────────────────────────────────────────
  TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: context.colors.textPrimary,
    letterSpacing: -0.5,
    height: 1.25,
  );

  TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: context.colors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: context.colors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // ─── Titles ────────────────────────────────────────────────
  TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: context.colors.textPrimary,
    letterSpacing: 0,
    height: 1.35,
  );

  TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: context.colors.textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: context.colors.textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ─── Body ─────────────────────────────────────────────────
  TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: context.colors.textPrimary,
    letterSpacing: 0.15,
    height: 1.5,
  );

  TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: context.colors.textSecondary,
    letterSpacing: 0.15,
    height: 1.45,
  );

  TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: context.colors.textTertiary,
    letterSpacing: 0.2,
    height: 1.4,
  );

  // ─── Labels ───────────────────────────────────────────────
  TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: context.colors.textPrimary,
    letterSpacing: 0.5,
    height: 1.4,
  );

  TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: context.colors.textSecondary,
    letterSpacing: 0.5,
    height: 1.35,
  );

  TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: context.colors.textTertiary,
    letterSpacing: 0.5,
    height: 1.3,
  );

  // ─── Special Sport Styles ─────────────────────────────────
  TextStyle get scoreLarge => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: context.colors.textPrimary,
    letterSpacing: -2,
    height: 1.0,
  );

  TextStyle get scoreMedium => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: context.colors.textPrimary,
    letterSpacing: -1,
    height: 1.0,
  );

  TextStyle get statValue => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: context.colors.accent,
    letterSpacing: -0.5,
    height: 1.1,
  );

  TextStyle get statLabel => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: context.colors.textTertiary,
    letterSpacing: 1.0,
    height: 1.3,
  );

  TextStyle get badge => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
  );

  TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );
}

extension AppTypographyExtension on BuildContext {
  AppTypography get typography => AppTypography(this);
}