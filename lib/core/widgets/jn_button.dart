import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';
import '../theme/app_spacing.dart';

enum JNButtonVariant { primary, outline, ghost, accent, danger, success }

enum JNButtonSize { small, medium, large }

/// Premium button with multiple variants
class JNButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final JNButtonVariant variant;
  final JNButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const JNButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = JNButtonVariant.primary,
    this.size = JNButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
      child: _buildButton(context),
    );
  }

  double get _height {
    switch (size) {
      case JNButtonSize.small:
        return 36;
      case JNButtonSize.medium:
        return 48;
      case JNButtonSize.large:
        return 56;
    }
  }

  double get _fontSize {
    switch (size) {
      case JNButtonSize.small:
        return 12;
      case JNButtonSize.medium:
        return 14;
      case JNButtonSize.large:
        return 16;
    }
  }

  Widget _buildButton(BuildContext context) {
    switch (variant) {
      case JNButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            disabledBackgroundColor: context.colors.primaryDark.withValues(
              alpha: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          child: _buildChild(context, context.colors.onPrimary),
        );
      case JNButtonVariant.accent:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          child: _buildChild(context, Colors.black),
        );
      case JNButtonVariant.outline:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
            side: BorderSide(color: context.colors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          child: _buildChild(context, context.colors.textPrimary),
        );
      case JNButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: _buildChild(context, context.colors.textSecondary),
        );
      case JNButtonVariant.danger:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          child: _buildChild(context, Colors.white),
        );
      case JNButtonVariant.success:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          child: _buildChild(context, Colors.white),
        );
    }
  }

  Widget _buildChild(BuildContext context, Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _fontSize + 4),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}