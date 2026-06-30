import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/providers/session_provider.dart';
import '../widgets/order_status_badge.dart';
import 'order_detail_screen.dart';

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mis Compras', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('store_orders')
            .where('buyerId', isEqualTo: user.id)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('No tenés compras aún', style: AppTypography.bodyLarge.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final orderId = docs[index].id;
              final createdAt = data['createdAt'] as Timestamp?;

              return JNCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildProductThumbnail(data['productImageUrl'] as String?),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['productName'] ?? '',
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Talle: ${data['selectedSize']} • \$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt.toDate()),
                              style: AppTypography.badge.copyWith(color: AppColors.textTertiary, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    OrderStatusBadge(status: data['status'] ?? 'pending_payment'),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildProductThumbnail(String? imageUrl) {
    const placeholder = Icon(Icons.shopping_bag, color: AppColors.accent, size: 24);

    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.file(
      File(imageUrl),
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
