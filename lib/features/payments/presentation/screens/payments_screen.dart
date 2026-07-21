import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../store/presentation/screens/order_detail_screen.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _isCreatingOrder = false;

  Future<void> _payQuota(Map<String, dynamic> player, String quotaMonth) async {
    setState(() => _isCreatingOrder = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final db = FirebaseFirestore.instance;

      // Verificar si ya existe una solicitud de pago de cuota pendiente o con comprobante subido
      final existingOrders = await db.collection('store_orders')
          .where('buyerId', isEqualTo: user.id)
          .where('playerId', isEqualTo: player['id'])
          .where('isQuotaPayment', isEqualTo: true)
          .where('quotaMonth', isEqualTo: quotaMonth)
          .where('status', whereIn: ['pending_payment', 'payment_uploaded'])
          .get();

      if (existingOrders.docs.isNotEmpty) {
        // Si existe, simplemente navegamos a esa orden
        final existingOrderId = existingOrders.docs.first.id;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: existingOrderId),
            ),
          );
        }
        return;
      }
      
      final orderRef = await db.collection('store_orders').add({
        'buyerId': user.id,
        'buyerName': '${user.name} ${user.lastName}',
        'buyerEmail': user.email,
        'productId': 'cuota_cooperadora',
        'productName': 'Cuota $quotaMonth - ${player['name']} ${player['lastName']}',
        'productImageUrl': null,
        'selectedSize': 'N/A',
        'quantity': 1,
        'totalPrice': 0, // El administrador validará el monto según el comprobante
        'status': 'pending_payment',
        'isQuotaPayment': true,
        'quotaMonth': quotaMonth,
        'playerId': player['id'],
        'receiptUrl': null,
        'receiptUploadedAt': null,
        'adminNotes': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      

      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Solicitud creada. Sube tu comprobante de pago.'),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderRef.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  void _showPlayerSelectionDialog(List<Map<String, dynamic>> players) {
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No tienes jugadores vinculados para pagar cuota.'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Pagar Cuota Cooperadora', style: context.typography.titleLarge),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: players.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = players[index];
                return ListTile(
                  tileColor: context.colors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text('${p['name']} ${p['lastName']}', style: context.typography.titleMedium),
                  subtitle: Text('Categoría: ${p['category'] ?? "Sin categoría"}', style: context.typography.bodySmall),
                  trailing: const Icon(Icons.payment),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMonthSelectionDialog(p);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: context.colors.primary)),
            ),
          ],
        );
      },
    );
  }

  void _showMonthSelectionDialog(Map<String, dynamic> player) {
    final currentYear = DateTime.now().year;
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Seleccionar Mes', style: context.typography.titleLarge),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: 12,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final monthStr = '${index + 1}'.padLeft(2, '0');
                final quotaMonth = '$monthStr/$currentYear';
                final monthName = months[index];
                
                final paidQuotas = List<String>.from(player['paidQuotas'] ?? []);
                final isPaid = paidQuotas.contains(quotaMonth);

                return ListTile(
                  tileColor: context.colors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text('$monthName $currentYear', style: context.typography.titleMedium),
                  trailing: isPaid 
                    ? const Icon(Icons.check_circle, color: Colors.green) 
                    : const Icon(Icons.chevron_right, color: Colors.grey),
                  enabled: !isPaid,
                  onTap: () {
                    Navigator.pop(ctx);
                    _payQuota(player, quotaMonth);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: context.colors.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider)!;
    final playersAsync = ref.watch(tutorPlayersStreamProvider(sessionUser.id));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Cuotas y Pagos')),
      body: _isCreatingOrder
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                // ─── Header Card ─────────────────────────
                JNCard(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.surfaceLight,
                      context.colors.primary,
                    ],
                  ),
                  border: Border.all(
                    color: context.colors.primary.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              size: 24,
                              color: context.colors.accent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Administración de Cuotas',
                                  style: context.typography.labelMedium,
                                ),
                                Text(
                                  '${sessionUser.name} ${sessionUser.lastName}',
                                  style: context.typography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Paga las cuotas cooperadoras de tus jugadores vinculados desde aquí.',
                        style: context.typography.bodyMedium.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),

                const SizedBox(height: 24),

                // ─── Players List ──────────────────────────
                Text('Mis Jugadores', style: context.typography.headlineSmall),
                const SizedBox(height: 12),
                playersAsync.when(
                  data: (players) {
                    if (players.isEmpty) {
                      return JNCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No tienes jugadores vinculados.',
                          style: context.typography.bodyMedium,
                        ),
                      );
                    }
                    return Column(
                      children: players.map((p) {
                        final currentYear = DateTime.now().year;
                        final currentMonth = DateTime.now().month;
                        final paidQuotas = List<String>.from(p['paidQuotas'] ?? []);
                        
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

                        final isAlDia = missingMonths.isEmpty;
                        final badgeText = isAlDia ? 'AL DÍA' : 'DEUDOR';
                        final debtText = isAlDia ? '' : 'Debe: ${missingMonths.join(", ")}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: JNCard(
                            padding: const EdgeInsets.all(16),
                            border: Border.all(
                              color: isAlDia ? context.colors.success.withValues(alpha: 0.3) : context.colors.error.withValues(alpha: 0.3),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: context.colors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${p['name']} ${p['lastName']}', style: context.typography.titleMedium),
                                      Text('Categoría: ${p['category'] ?? "Sin categoría"}', style: context.typography.bodySmall),
                                      if (!isAlDia)
                                        Text(
                                          debtText, 
                                          style: context.typography.bodySmall.copyWith(color: context.colors.error, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isAlDia ? context.colors.success.withValues(alpha: 0.1) : context.colors.error.withValues(alpha: 0.1),
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
                                    if (!isAlDia) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 30,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: context.colors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                          ),
                                          onPressed: () => _showMonthSelectionDialog(p),
                                          child: const Text('Pagar', style: TextStyle(fontSize: 12, color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                ),
                const SizedBox(height: 24),
                JNButton(
                  label: 'Pagar a otro jugador',
                  icon: Icons.search,
                  variant: JNButtonVariant.outline,
                  onPressed: () {
                    final players = playersAsync.valueOrNull ?? [];
                    _showPlayerSelectionDialog(players);
                  },
                ),
              ],
            ),
    );
  }
}