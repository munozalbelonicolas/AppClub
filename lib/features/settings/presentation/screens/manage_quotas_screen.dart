import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../store/presentation/screens/admin_order_detail_screen.dart';

class ManageQuotasScreen extends ConsumerStatefulWidget {
  const ManageQuotasScreen({super.key});

  @override
  ConsumerState<ManageQuotasScreen> createState() => _ManageQuotasScreenState();
}

class _ManageQuotasScreenState extends ConsumerState<ManageQuotasScreen> {
  String _selectedCategory = 'Todas';
  String _selectedStatus = 'Todos';

  String _getPlayerFullName(Map<String, dynamic> player) {
    final name = player['name']?.toString().trim() ?? '';
    final lastName = player['lastName']?.toString().trim() ?? '';
    final displayName = player['displayName']?.toString().trim() ?? '';
    final fullName = player['fullName']?.toString().trim() ?? '';

    if (name.isNotEmpty && lastName.isNotEmpty) {
      if (name.toLowerCase().contains(lastName.toLowerCase())) {
        return name;
      }
      return '$name $lastName';
    }
    if (name.isNotEmpty) return name;
    if (displayName.isNotEmpty) return displayName;
    if (fullName.isNotEmpty) return fullName;
    return 'Jugador';
  }

  List<String> _calculateMissingMonths(List<String> paidQuotas) {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    final missingMonths = <String>[];
    final monthNames = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];

    for (int i = 1; i <= currentMonth; i++) {
      final monthStr = '$i'.padLeft(2, '0');
      final quotaStr = '$monthStr/$currentYear';
      if (!paidQuotas.contains(quotaStr)) {
        missingMonths.add(monthNames[i - 1]);
      }
    }
    return missingMonths;
  }

  void _showReceiptPreviewDialog({
    required BuildContext context,
    required String receiptUrl,
    required String monthName,
    required Map<String, dynamic> order,
    required Map<String, dynamic> player,
    required VoidCallback onMarkPaid,
  }) {
    final status = order['status']?.toString() ?? 'pending_payment';
    final buyerName = order['buyerName']?.toString() ?? 'Tutor';
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ??
        (order['receiptUploadedAt'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF1F5F9) : context.colors.surfaceLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: context.colors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comprobante: $monthName',
                              style: context.typography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isLight ? Colors.black87 : Colors.white,
                              ),
                            ),
                            Text(
                              'Subido por: $buyerName${createdAt != null ? ' (${createdAt.day}/${createdAt.month}/${createdAt.year})' : ''}',
                              style: context.typography.bodySmall.copyWith(
                                color: isLight ? Colors.black54 : context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Image Viewer with Zoom & Pan
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.52,
                  ),
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: InteractiveViewer(
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: receiptUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 48, color: Colors.white54),
                              SizedBox(height: 8),
                              Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Info & Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estado del comprobante:',
                            style: TextStyle(
                              fontSize: 13,
                              color: isLight ? Colors.black87 : Colors.white70,
                            ),
                          ),
                          _buildStatusChip(status, isLight),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (order['id'] != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Ver Orden'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isLight ? Colors.black87 : Colors.white,
                                  side: BorderSide(color: context.colors.border),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminOrderDetailScreen(orderId: order['id']),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (order['id'] != null) const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Aprobar Cuota'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.success,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                onMarkPaid();
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status, bool isLight) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'confirmed':
        bg = isLight ? const Color(0xFFDCFCE7) : const Color(0xFF14532D);
        fg = isLight ? const Color(0xFF15803D) : const Color(0xFF86EFAC);
        label = 'Aprobado';
        break;
      case 'payment_uploaded':
        bg = isLight ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);
        fg = isLight ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
        label = 'Comprobante Subido';
        break;
      case 'rejected':
        bg = isLight ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);
        fg = isLight ? const Color(0xFFB91C1C) : const Color(0xFFFCA5A5);
        label = 'Rechazado';
        break;
      default:
        bg = isLight ? const Color(0xFFF1F5F9) : const Color(0xFF27272A);
        fg = isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
        label = 'Pendiente';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showEditQuotasDialog(Map<String, dynamic> player) {
    final currentYear = DateTime.now().year;
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    final currentPaidQuotas = List<String>.from(player['paidQuotas'] ?? []);
    final playerId = player['id']?.toString() ?? '';
    final playerFullName = _getPlayerFullName(player);

    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('store_orders')
              .where('playerId', isEqualTo: playerId)
              .snapshots(),
          builder: (context, snapshot) {
            final orders = (snapshot.data?.docs ?? []).map((d) {
              final m = d.data();
              m['id'] = d.id;
              return m;
            }).toList();

            return StatefulBuilder(
              builder: (context, setState) {
                final isLight = Theme.of(context).brightness == Brightness.light;

                return AlertDialog(
                  backgroundColor: context.colors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.person, color: context.colors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cuotas de $playerFullName',
                                  style: context.typography.titleLarge.copyWith(
                                    color: isLight ? Colors.black87 : Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Cat: ${player['category'] ?? "Sin categoría"} · Año $currentYear',
                                  style: context.typography.bodySmall.copyWith(
                                    color: isLight ? Colors.black54 : context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: 12,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final monthStr = '${index + 1}'.padLeft(2, '0');
                        final quotaMonth = '$monthStr/$currentYear';
                        final isPaid = currentPaidQuotas.contains(quotaMonth);

                        // Find matching order for this month
                        final matchingOrder = orders.where((o) {
                          final qm = o['quotaMonth']?.toString();
                          if (qm == quotaMonth || qm == '$monthStr/$currentYear' || qm == '${index + 1}/$currentYear') {
                            return true;
                          }
                          final pName = o['productName']?.toString().toLowerCase() ?? '';
                          return pName.contains(months[index].toLowerCase()) && pName.contains('$currentYear');
                        }).firstOrNull;

                        final receiptUrl = matchingOrder?['receiptUrl']?.toString();
                        final hasReceipt = receiptUrl != null && receiptUrl.isNotEmpty;
                        final orderStatus = matchingOrder?['status']?.toString() ?? '';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? (isLight ? const Color(0xFFF0FDF4) : const Color(0xFF14532D).withValues(alpha: 0.2))
                                : (isLight ? const Color(0xFFF8FAFC) : context.colors.surfaceLight),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPaid
                                  ? (isLight ? const Color(0xFFBBF7D0) : const Color(0xFF16A34A).withValues(alpha: 0.5))
                                  : (isLight ? const Color(0xFFE2E8F0) : context.colors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: isPaid,
                                activeColor: context.colors.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      if (!currentPaidQuotas.contains(quotaMonth)) {
                                        currentPaidQuotas.add(quotaMonth);
                                      }
                                    } else {
                                      currentPaidQuotas.remove(quotaMonth);
                                    }
                                  });
                                },
                              ),

                              // Month text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${months[index]} $currentYear',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isPaid ? FontWeight.bold : FontWeight.w500,
                                        color: isLight ? Colors.black87 : Colors.white,
                                      ),
                                    ),
                                    if (isPaid)
                                      Text(
                                        'Pagada',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.colors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      Text(
                                        hasReceipt ? 'Comprobante pendiente de revisión' : 'Impaga',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasReceipt ? Colors.amber[800] : context.colors.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Receipt button / thumbnail
                              if (hasReceipt)
                                InkWell(
                                  onTap: () {
                                    _showReceiptPreviewDialog(
                                      context: this.context,
                                      receiptUrl: receiptUrl,
                                      monthName: '${months[index]} $currentYear',
                                      order: matchingOrder!,
                                      player: player,
                                      onMarkPaid: () {
                                        setState(() {
                                          if (!currentPaidQuotas.contains(quotaMonth)) {
                                            currentPaidQuotas.add(quotaMonth);
                                          }
                                        });
                                        if (matchingOrder['id'] != null) {
                                          FirebaseFirestore.instance
                                              .collection('store_orders')
                                              .doc(matchingOrder['id'])
                                              .update({
                                            'status': 'confirmed',
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          });
                                        }
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (orderStatus == 'confirmed')
                                          ? (isLight ? const Color(0xFFDCFCE7) : const Color(0xFF14532D))
                                          : (isLight ? const Color(0xFFFEF3C7) : const Color(0xFF78350F)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (orderStatus == 'confirmed')
                                            ? (isLight ? const Color(0xFF86EFAC) : const Color(0xFF22C55E))
                                            : (isLight ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: CachedNetworkImage(
                                            imageUrl: receiptUrl,
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, _, _) => const Icon(Icons.receipt, size: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          orderStatus == 'confirmed' ? 'Comprobante' : 'Ver Comprobante',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: (orderStatus == 'confirmed')
                                                ? (isLight ? const Color(0xFF15803D) : const Color(0xFF86EFAC))
                                                : (isLight ? const Color(0xFFB45309) : const Color(0xFFFDE68A)),
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.visibility,
                                          size: 13,
                                          color: (orderStatus == 'confirmed')
                                              ? (isLight ? const Color(0xFF15803D) : const Color(0xFF86EFAC))
                                              : (isLight ? const Color(0xFFB45309) : const Color(0xFFFDE68A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (matchingOrder != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF27272A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.hourglass_empty, size: 12, color: context.colors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sin comprobante',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isLight ? Colors.black54 : context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final successColor = context.colors.success;
                        final errorColor = context.colors.error;
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(player['id']).update({
                            'paidQuotas': currentPaidQuotas,
                            'quotaStatus': _calculateMissingMonths(currentPaidQuotas).isEmpty ? 'al_dia' : 'atrasado',
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: const Text('Cuotas actualizadas correctamente'), backgroundColor: successColor),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: errorColor),
                            );
                          }
                        }
                      },
                      child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersStreamProvider);
    final categories = ref.watch(appCategoriesProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Estado de Cuotas'),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: context.colors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Categoría:', style: context.typography.titleSmall),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                          ...categories.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Estado:', style: context.typography.titleSmall),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                          DropdownMenuItem(value: 'Al Día', child: Text('Al Día')),
                          DropdownMenuItem(value: 'Deudor', child: Text('Deudor')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('store_orders')
                  .where('isQuotaPayment', isEqualTo: true)
                  .snapshots(),
              builder: (context, ordersSnap) {
                final quotaOrders = (ordersSnap.data?.docs ?? []).map((d) => d.data()).toList();
                // Build a set of playerIds that have uploaded receipts
                final playersWithReceipts = <String>{};
                for (final o in quotaOrders) {
                  final pId = o['playerId']?.toString();
                  final rUrl = o['receiptUrl']?.toString();
                  if (pId != null && pId.isNotEmpty && rUrl != null && rUrl.isNotEmpty) {
                    playersWithReceipts.add(pId);
                  }
                }

                return playersAsync.when(
                  data: (players) {
                    final filteredPlayers = players.where((p) {
                      final role = p['role'];
                      if (role != null && role != 'jugador') return false;

                      // Category Filter
                      if (_selectedCategory != 'Todas' && p['category'] != _selectedCategory) {
                        return false;
                      }

                      // Status Filter
                      final paidQuotas = List<String>.from(p['paidQuotas'] ?? []);
                      final missing = _calculateMissingMonths(paidQuotas);
                      final isAlDia = missing.isEmpty;

                      if (_selectedStatus == 'Al Día' && !isAlDia) return false;
                      if (_selectedStatus == 'Deudor' && isAlDia) return false;

                      return true;
                    }).toList();

                    if (filteredPlayers.isEmpty) {
                      return const Center(child: Text('No hay jugadores que coincidan con los filtros'));
                    }

                    // Sort by name
                    filteredPlayers.sort((a, b) =>
                      _getPlayerFullName(a).toLowerCase().compareTo(_getPlayerFullName(b).toLowerCase())
                    );

                    return ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filteredPlayers.length,
                      itemBuilder: (context, index) {
                        final p = filteredPlayers[index];
                        final paidQuotas = List<String>.from(p['paidQuotas'] ?? []);
                        final missingMonths = _calculateMissingMonths(paidQuotas);
                        final isAlDia = missingMonths.isEmpty;
                        final pId = p['id']?.toString() ?? '';
                        final hasUploadedReceipt = playersWithReceipts.contains(pId);

                        final badgeText = isAlDia ? 'AL DÍA' : 'DEUDOR';
                        final debtText = isAlDia ? '' : 'Debe: ${missingMonths.join(", ")}';
                        final fullName = _getPlayerFullName(p);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: JNCard(
                            onTap: () => _showEditQuotasDialog(p),
                            padding: const EdgeInsets.all(12),
                            border: Border.all(
                              color: isAlDia
                                ? context.colors.success.withValues(alpha: 0.3)
                                : context.colors.error.withValues(alpha: 0.3),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: context.colors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(fullName, style: context.typography.titleMedium),
                                          ),
                                          if (hasUploadedReceipt)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(left: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.receipt, size: 12, color: Color(0xFFD97706)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Comprobante',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text('Cat: ${p['category'] ?? "Sin categoría"}', style: context.typography.bodySmall),
                                      if (!isAlDia)
                                        Text(
                                          debtText,
                                          style: context.typography.bodySmall.copyWith(
                                            color: context.colors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAlDia
                                      ? context.colors.success.withValues(alpha: 0.1)
                                      : context.colors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: context.typography.labelSmall.copyWith(
                                      color: isAlDia ? context.colors.success : context.colors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

