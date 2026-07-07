import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_empty_state.dart';
import '../../../../core/widgets/jn_skeleton_card.dart';
import '../widgets/order_status_badge.dart';
import 'order_detail_screen.dart';

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  late final Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _ordersStream = FirebaseFirestore.instance
        .collection('store_orders')
        .where('buyerId', isEqualTo: user?.id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Mis Compras', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 4,
              itemBuilder: (context, index) => const JNSkeletonCard(height: 140),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const JNEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No tienes compras',
              message: 'Aún no has realizado ninguna compra en la tienda del club.',
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar pedidos: ${snapshot.error}'));
          }

          final docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

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
                        color: context.colors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildProductThumbnail(context, data['imageUrl']),
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
                            style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Talle: ${data['selectedSize']} • \$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}',
                            style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                          ),
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt.toDate()),
                              style: context.typography.badge.copyWith(color: context.colors.textTertiary, fontSize: 10),
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

  Widget _buildProductThumbnail(BuildContext context, String? imageUrl) {
    final placeholder = Icon(Icons.shopping_bag, color: context.colors.accent, size: 24);

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