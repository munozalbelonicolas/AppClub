import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Skeleton loading placeholder with shimmer effect
class JNShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const JNShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  /// Shimmer version of a full card
  factory JNShimmer.card({double height = 120}) {
    return JNShimmer(height: height, borderRadius: AppSpacing.radiusLg);
  }

  /// Shimmer for a text line
  factory JNShimmer.text({double width = 120, double height = 14}) {
    return JNShimmer(width: width, height: height, borderRadius: 4);
  }

  /// Shimmer for a circle (avatar)
  factory JNShimmer.circle({double size = 44}) {
    return JNShimmer(width: size, height: size, borderRadius: size / 2);
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.surfaceVariant,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Full shimmer loading list for screens
class JNShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const JNShimmerList({super.key, this.itemCount = 5, this.itemHeight = 80});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.listItemGap),
      itemBuilder: (_, _) => JNShimmer.card(height: itemHeight),
    );
  }
}
