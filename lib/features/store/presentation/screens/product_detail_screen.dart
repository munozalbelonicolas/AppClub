import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/providers/session_provider.dart';
import 'create_product_screen.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _selectedSize;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user != null && (user.role == 'directivo' || user.role == 'secretario');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('store_products').doc(widget.productId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Producto no encontrado'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? '';
          final description = data['description'] ?? '';
          final price = (data['price'] ?? 0).toDouble();
          final stock = data['stock'] ?? 0;
          final imageUrl = data['imageUrl'] as String?;
          final sizes = List<String>.from(data['sizes'] ?? []);
          final isOutOfStock = stock <= 0;

          return CustomScrollView(
            slivers: [
              // Hero image
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppColors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeroImage(imageUrl),
                ),
                actions: [
                  if (isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateProductScreen(productId: widget.productId),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _confirmDelete(context, name),
                    ),
                  ],
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(name, style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),

                      // Price
                      Text(
                        '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                        style: AppTypography.headlineLarge.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Stock info
                      Text(
                        isOutOfStock ? 'Sin stock disponible' : '$stock unidades disponibles',
                        style: AppTypography.bodySmall.copyWith(
                          color: isOutOfStock ? AppColors.error : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      Text('Descripción', style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Text(description, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),

                      const SizedBox(height: 24),

                      // Size selector
                      if (sizes.isNotEmpty) ...[
                        Text('Seleccioná tu talle', style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: sizes.map((size) {
                            final isSelected = _selectedSize == size;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedSize = size),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  size,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Quantity selector
                      if (!isOutOfStock) ...[
                        Text('Cantidad', style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
                        const SizedBox(height: 10),
                        JNCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.textSecondary,
                                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$_quantity',
                                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.primary,
                                onPressed: _quantity < stock ? () => setState(() => _quantity++) : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: \$${(price * _quantity).toStringAsFixed(0)}',
                          style: AppTypography.titleMedium.copyWith(color: AppColors.accent),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Buy button
                      if (!isOutOfStock)
                        JNButton(
                          label: 'Comprar',
                          onPressed: _selectedSize == null
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CheckoutScreen(
                                        productId: widget.productId,
                                        productName: name,
                                        productImageUrl: imageUrl ?? '',
                                        selectedSize: _selectedSize!,
                                        quantity: _quantity,
                                        unitPrice: price,
                                      ),
                                    ),
                                  );
                                },
                        )
                      else
                        JNButton(
                          label: 'Agotado',
                          onPressed: null,
                        ),

                      if (_selectedSize == null && !isOutOfStock)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Seleccioná un talle para continuar',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: AppColors.surfaceLight,
        child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.textTertiary)),
      );
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.surfaceLight,
        child: const Center(child: Icon(Icons.broken_image, size: 80, color: AppColors.textTertiary)),
      ));
    }
    return Image.file(File(imageUrl), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(
      color: AppColors.surfaceLight,
      child: const Center(child: Icon(Icons.broken_image, size: 80, color: AppColors.textTertiary)),
    ));
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de que querés eliminar "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('store_products').doc(widget.productId).update({'isActive': false});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
