import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/providers/session_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'create_product_screen.dart';
import 'my_orders_screen.dart';
import 'store_config_screen.dart';
import 'admin_orders_screen.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String _selectedFilter = 'todos';

  final List<Map<String, dynamic>> _filters = [
    {'key': 'todos', 'label': 'Todos', 'icon': Icons.apps},
    {'key': 'indumentaria', 'label': 'Indumentaria', 'icon': Icons.checkroom},
    {'key': 'accesorios', 'label': 'Accesorios', 'icon': Icons.sports_handball},
    {'key': 'calzado', 'label': 'Calzado', 'icon': Icons.ice_skating},
    {'key': 'equipamiento', 'label': 'Equipamiento', 'icon': Icons.sports_soccer},
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user != null && (user.role == 'directivo' || user.role == 'secretario');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.doc('settings/store_config').snapshots(),
      builder: (context, configSnapshot) {
        final configData = configSnapshot.data?.data() as Map<String, dynamic>?;
        final isStoreEnabled = configData?['isStoreEnabled'] ?? true;

        // If store is disabled and user is not admin, show closed message
        if (!isStoreEnabled && !isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text('Tienda', style: AppTypography.titleLarge),
              backgroundColor: AppColors.surface,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 72, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Tienda temporalmente cerrada',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Volvé a intentar más tarde.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Tienda', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // My Orders button (for all users)
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Mis Compras',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
            ),
          ),
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Pedidos',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurar Tienda',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreConfigScreen()),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter['key'];
                return ChoiceChip(
                  avatar: Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  label: Text(filter['label'] as String),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceLight,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = filter['key'] as String),
                );
              },
            ),
          ),

          // Product grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text('No hay productos disponibles', style: AppTypography.bodyLarge.copyWith(color: AppColors.textTertiary)),
                        if (isAdmin) ...[
                          const SizedBox(height: 16),
                          Text('Tocá + para agregar uno', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                        ],
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final productId = docs[index].id;
                    return ProductCard(
                      name: data['name'] ?? '',
                      price: (data['price'] ?? 0).toDouble(),
                      imageUrl: data['imageUrl'],
                      stock: data['stock'] ?? 0,
                      category: data['category'] ?? '',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(productId: productId),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateProductScreen()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
      },
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    var query = FirebaseFirestore.instance
        .collection('store_products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (_selectedFilter != 'todos') {
      query = FirebaseFirestore.instance
          .collection('store_products')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: _selectedFilter)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots();
  }
}
