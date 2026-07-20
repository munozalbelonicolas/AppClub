import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_empty_state.dart';
import '../../../../core/widgets/jn_skeleton_card.dart';
import '../widgets/order_status_badge.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, String>> _tabs = [
    {'label': 'Todos', 'key': 'all'},
    {'label': 'Pendientes', 'key': 'pending_payment'},
    {'label': 'A Revisar', 'key': 'payment_uploaded'},
    {'label': 'Confirmados', 'key': 'confirmed'},
    {'label': 'Completados', 'key': 'delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Gestión de Pedidos', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: context.colors.primary,
          labelColor: context.colors.primary,
          unselectedLabelColor: context.colors.textTertiary,
          tabs: _tabs.map((t) => Tab(text: t['label'] as String)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildOrderList(tab['key'] as String)).toList(),
      ),
    );
  }

  Widget _buildOrderList(String filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: 4,
            itemBuilder: (context, index) => const JNSkeletonCard(height: 100),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar pedidos: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const JNEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No hay pedidos',
            message: 'No se encontraron pedidos en esta categoría.',
          );
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
                MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(orderId: orderId)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['buyerName'] ?? '',
                              style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (data['selectedSize'] != null && data['selectedSize'].toString().isNotEmpty)
                                  ? '${data['productName']} — Talle: ${data['selectedSize']}'
                                  : '${data['productName']}',
                              style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}',
                        style: context.typography.titleSmall.copyWith(color: context.colors.accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OrderStatusBadge(
                        status: data['status'] ?? 'pending_payment',
                        isQuota: data['isQuotaPayment'] == true,
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt.toDate()),
                          style: context.typography.badge.copyWith(color: context.colors.textTertiary, fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildQuery(String filter) {
    final base = FirebaseFirestore.instance.collection('store_orders');
    if (filter == 'all') {
      return base.orderBy('createdAt', descending: true).snapshots();
    }
    return base.where('status', isEqualTo: filter).snapshots();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
