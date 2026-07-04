import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

import '../../data/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.isOutOfStock;

    return JNCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _buildImage(context),
                ),
              ),
              // Category badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _categoryLabel(product.category),
                    style: context.typography.badge.copyWith(color: context.colors.accent, fontSize: 10),
                  ),
                ),
              ),
              // Out of stock overlay
              if (isOutOfStock)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AGOTADO',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
                  style: context.typography.bodyLarge.copyWith(
                    color: context.colors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (product.imageUrl == null || product.imageUrl!.isEmpty) {
      return Container(
        color: context.colors.surfaceLight,
        child: Center(
          child: Icon(Icons.shopping_bag_outlined, size: 48, color: context.colors.textTertiary),
        ),
      );
    }
    
    // Check if it's a local file path or a network URL
    if (product.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: product.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Container(
          color: context.colors.surfaceLight,
          child: Center(
            child: Icon(Icons.broken_image, size: 48, color: context.colors.textTertiary),
          ),
        ),
      );
    } else {
      return Image.file(
        File(product.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: context.colors.surfaceLight,
          child: Center(
            child: Icon(Icons.broken_image, size: 48, color: context.colors.textTertiary),
          ),
        ),
      );
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'indumentaria':
        return '👕 Indumentaria';
      case 'accesorios':
        return '🧤 Accesorios';
      case 'calzado':
        return '👟 Calzado';
      case 'equipamiento':
        return '⚽ Equipamiento';
      default:
        return cat;
    }
  }
}