import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Player/user avatar with border, fallback initials, and optional badge
class JNAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final int? number;

  const JNAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = AppSpacing.avatarMd,
    this.borderColor,
    this.borderWidth = 2,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? context.colors.accent,
              width: borderWidth,
            ),
            color: context.colors.surfaceVariant,
          ),
          child: ClipOval(
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => _buildInitials(context),
                  )
                : _buildInitials(context),
          ),
        ),
        if (number != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
                border: Border.all(color: context.colors.background, width: 1.5),
              ),
              child: Text(
                '#$number',
                style: context.typography.badge.copyWith(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : parts[0].substring(0, parts[0].length >= 2 ? 2 : 1);

    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}