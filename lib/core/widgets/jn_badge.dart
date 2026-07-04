import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum JNBadgeType { success, warning, error, info, accent, neutral }

/// Status badge for payments, attendance, categories, etc.
class JNBadge extends StatelessWidget {
  final String label;
  final JNBadgeType type;
  final IconData? icon;
  final bool small;

  const JNBadge({
    super.key,
    required this.label,
    this.type = JNBadgeType.neutral,
    this.icon,
    this.small = false,
  });

  // Convenience constructors
  factory JNBadge.paid() => const JNBadge(
    label: 'AL DÍA',
    type: JNBadgeType.success,
    icon: Icons.check_circle_outline,
  );
  factory JNBadge.pending() => const JNBadge(
    label: 'PENDIENTE',
    type: JNBadgeType.warning,
    icon: Icons.schedule,
  );
  factory JNBadge.overdue() => const JNBadge(
    label: 'VENCIDO',
    type: JNBadgeType.error,
    icon: Icons.warning_amber_rounded,
  );
  factory JNBadge.confirmed() => const JNBadge(
    label: 'CONFIRMADO',
    type: JNBadgeType.success,
    icon: Icons.check,
  );
  factory JNBadge.absent() => const JNBadge(
    label: 'AUSENTE',
    type: JNBadgeType.error,
    icon: Icons.close,
  );
  factory JNBadge.delayed() => const JNBadge(
    label: 'DEMORA',
    type: JNBadgeType.warning,
    icon: Icons.access_time,
  );

  Color _backgroundColor(BuildContext context) {
    switch (type) {
      case JNBadgeType.success:
        return context.colors.success.withValues(alpha: 0.15);
      case JNBadgeType.warning:
        return context.colors.warning.withValues(alpha: 0.15);
      case JNBadgeType.error:
        return context.colors.error.withValues(alpha: 0.15);
      case JNBadgeType.info:
        return context.colors.info.withValues(alpha: 0.15);
      case JNBadgeType.accent:
        return context.colors.accent.withValues(alpha: 0.15);
      case JNBadgeType.neutral:
        return context.colors.surfaceVariant;
    }
  }

  Color _textColor(BuildContext context) {
    switch (type) {
      case JNBadgeType.success:
        return context.colors.success;
      case JNBadgeType.warning:
        return context.colors.warning;
      case JNBadgeType.error:
        return context.colors.error;
      case JNBadgeType.info:
        return context.colors.info;
      case JNBadgeType.accent:
        return context.colors.accent;
      case JNBadgeType.neutral:
        return context.colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 10 : 12, color: _textColor(context)),
            SizedBox(width: small ? 4 : 6),
          ],
          Text(
            label.toUpperCase(),
            style: context.typography.badge.copyWith(
              color: _textColor(context),
              fontSize: small ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }
}