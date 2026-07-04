import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Premium card component with subtle border and modern styling
class JNCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final LinearGradient? gradient;
  final List<BoxShadow>? shadow;
  final double? borderRadius;
  final Border? border;

  const JNCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.gradient,
    this.shadow,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? AppSpacing.radiusLg);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? context.colors.card) : null,
        gradient: gradient,
        borderRadius: radius,
        border: border ?? Border.all(color: context.colors.border, width: 0.5),
        boxShadow: shadow ?? AppShadows.none,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: context.colors.primary.withValues(alpha: 0.08),
          highlightColor: context.colors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
