import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../widgets/order_status_badge.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = [
    {'key': 'all', 'label': 'Todos'},
    {'key': 'pending_payment', 'label': 'Pendientes'},
    {'key': 'payment_uploaded', 'label': 'Por Verificar'},
    {'key': 'confirmed', 'label': 'Confirmados'},
    {'key': 'delivered', 'label': 'Entregados'},
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pedidos de la Tienda', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
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
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('No hay pedidos', style: AppTypography.bodyLarge.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['productName']} — Talle: ${data['selectedSize']}',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}',
                        style: AppTypography.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OrderStatusBadge(status: data['status'] ?? 'pending_payment'),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt.toDate()),
                          style: AppTypography.badge.copyWith(color: AppColors.textTertiary, fontSize: 10),
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
    return base.where('status', isEqualTo: filter).orderBy('createdAt', descending: true).snapshots();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
