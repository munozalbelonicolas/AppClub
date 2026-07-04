import 'package:flutter/material.dart';


class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color onPrimary;

  final Color accent;
  final Color accentLight;
  final Color accentDark;

  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color surfaceVariant;
  final Color surfaceElevated;
  final Color card;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  final Color border;
  final Color borderLight;
  final Color divider;

  final Color success;
  final Color successDark;
  final Color warning;
  final Color warningDark;
  final Color error;
  final Color errorDark;
  final Color info;

  final Color win;
  final Color draw;
  final Color loss;

  const AppThemeColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.onPrimary,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.border,
    required this.borderLight,
    required this.divider,
    required this.success,
    required this.successDark,
    required this.warning,
    required this.warningDark,
    required this.error,
    required this.errorDark,
    required this.info,
    required this.win,
    required this.draw,
    required this.loss,
  });

  @override
  ThemeExtension<AppThemeColors> copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? onPrimary,
    Color? accent,
    Color? accentLight,
    Color? accentDark,
    Color? background,
    Color? surface,
    Color? surfaceLight,
    Color? surfaceVariant,
    Color? surfaceElevated,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? border,
    Color? borderLight,
    Color? divider,
    Color? success,
    Color? successDark,
    Color? warning,
    Color? warningDark,
    Color? error,
    Color? errorDark,
    Color? info,
    Color? win,
    Color? draw,
    Color? loss,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentDark: accentDark ?? this.accentDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      successDark: successDark ?? this.successDark,
      warning: warning ?? this.warning,
      warningDark: warningDark ?? this.warningDark,
      error: error ?? this.error,
      errorDark: errorDark ?? this.errorDark,
      info: info ?? this.info,
      win: win ?? this.win,
      draw: draw ?? this.draw,
      loss: loss ?? this.loss,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
      covariant ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      successDark: Color.lerp(successDark, other.successDark, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningDark: Color.lerp(warningDark, other.warningDark, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorDark: Color.lerp(errorDark, other.errorDark, t)!,
      info: Color.lerp(info, other.info, t)!,
      win: Color.lerp(win, other.win, t)!,
      draw: Color.lerp(draw, other.draw, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
    );
  }

  // Helper getters
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryDark],
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentDark],
      );

  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [surfaceLight, surface],
      );

  // Dark Theme Colors (Legacy values)
  static const dark = AppThemeColors(
    primary: Color(0xFFC1121F),
    primaryLight: Color(0xFFE63946),
    primaryDark: Color(0xFF8B0D15),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFD4AF37),
    accentLight: Color(0xFFE6C85B),
    accentDark: Color(0xFFB8952E),
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF161616),
    surfaceLight: Color(0xFF1E1E1E),
    surfaceVariant: Color(0xFF262626),
    surfaceElevated: Color(0xFF2A2A2A),
    card: Color(0xFF1A1A1A),
    textPrimary: Color(0xFFF8F9FA),
    textSecondary: Color(0xFFADB5BD),
    textTertiary: Color(0xFF6C757D),
    textDisabled: Color(0xFF495057),
    border: Color(0xFF2D2D2D),
    borderLight: Color(0xFF3A3A3A),
    divider: Color(0xFF222222),
    success: Color(0xFF2ECC71),
    successDark: Color(0xFF1A7A42),
    warning: Color(0xFFE67E22),
    warningDark: Color(0xFF8B4C15),
    error: Color(0xFFE74C3C),
    errorDark: Color(0xFF8B2E25),
    info: Color(0xFF3498DB),
    win: Color(0xFF2ECC71),
    draw: Color(0xFFE67E22),
    loss: Color(0xFFE74C3C),
  );

  // Light Theme Colors
  static const light = AppThemeColors(
    primary: Color(0xFFC1121F), // Keep same primary
    primaryLight: Color(0xFFE63946),
    primaryDark: Color(0xFF8B0D15),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFD4AF37), // Keep same gold accent
    accentLight: Color(0xFFE6C85B),
    accentDark: Color(0xFFB8952E),
    background: Color(0xFFF4F6F8), // Light grey background
    surface: Color(0xFFFFFFFF), // White surface
    surfaceLight: Color(0xFFF8F9FA), // Slightly off-white
    surfaceVariant: Color(0xFFE9ECEF),
    surfaceElevated: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF212529), // Dark text
    textSecondary: Color(0xFF495057),
    textTertiary: Color(0xFF868E96),
    textDisabled: Color(0xFFCED4DA),
    border: Color(0xFFDEE2E6), // Light borders
    borderLight: Color(0xFFE9ECEF),
    divider: Color(0xFFE9ECEF),
    success: Color(0xFF27AE60),
    successDark: Color(0xFF1E8449),
    warning: Color(0xFFE67E22),
    warningDark: Color(0xFFD35400),
    error: Color(0xFFE74C3C),
    errorDark: Color(0xFFC0392B),
    info: Color(0xFF2980B9),
    win: Color(0xFF27AE60),
    draw: Color(0xFFE67E22),
    loss: Color(0xFFE74C3C),
  );
}

// Extension to make it easy to access colors: context.colors.primary
extension AppThemeColorsExtension on BuildContext {
  AppThemeColors get colors => Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;
}
