import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'jn_card.dart';

/// Animated stat card for player/team statistics
class JNStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;

  const JNStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? context.colors.accent;

    return JNCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: context.typography.statValue.copyWith(color: accentColor),
          ),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: context.typography.statLabel),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: context.typography.bodySmall.copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
