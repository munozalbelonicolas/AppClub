import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../widgets/order_status_badge.dart';

class AdminOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends ConsumerState<AdminOrderDetailScreen> {
  late final Stream<DocumentSnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).snapshots();
  }

  Future<void> _updateStatus(String newStatus, {String? notes}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (notes != null) updateData['adminNotes'] = notes;

      await FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).update(updateData);

      // Notify the buyer
      final orderDoc = await FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).get();
      final orderData = orderDoc.data()!;

      String notifType;
      String notifMessage;
      switch (newStatus) {
        case 'confirmed':
          final isQuota = orderData['isQuotaPayment'] == true;
          if (isQuota && orderData['playerId'] != null) {
            await FirebaseFirestore.instance.collection('users').doc(orderData['playerId']).update({
              'quotaStatus': 'al_dia',
              'lastQuotaPaymentDate': FieldValue.serverTimestamp(),
            });
            notifType = 'quota_payment_confirmed';
            notifMessage = '✅ Tu pago de cuota para ${orderData['productName'].split(' - ').last} fue confirmado.';
          } else {
            notifType = 'store_order_confirmed';
            notifMessage = '✅ Tu pago por ${orderData['productName']} fue confirmado. Ya podés pasar a retirarlo por el club.';
          }
          break;
        case 'delivered':
          notifType = 'store_order_delivered';
          notifMessage = '📦 Tu pedido de ${orderData['productName']} fue entregado.';
          break;
        case 'rejected':
          notifType = 'store_order_rejected';
          notifMessage = '❌ Tu pedido de ${orderData['productName']} fue rechazado: ${notes ?? ''}';
          // Restore stock
          await FirebaseFirestore.instance.collection('store_products').doc(orderData['productId']).update({
            'stock': FieldValue.increment(orderData['quantity'] ?? 1),
          });
          break;
        default:
          return;
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': notifType,
        'orderId': widget.orderId,
        'userId': orderData['buyerId'],
        'body': notifMessage,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a: $newStatus'), backgroundColor: context.colors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
        );
      }
    }
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Rechazar Pedido'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Motivo del rechazo...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('rejected', notes: controller.text.trim());
            },
            child: Text('Rechazar', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Gestionar Pedido', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Pedido no encontrado'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending_payment';
          final receiptUrl = data['receiptUrl'] as String?;
          final createdAt = data['createdAt'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status
                Center(child: OrderStatusBadge(status: status)),
                const SizedBox(height: 20),

                // Buyer info
                JNCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comprador', style: context.typography.labelMedium.copyWith(color: context.colors.textTertiary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, color: context.colors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(data['buyerName'] ?? '', style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, color: context.colors.textTertiary, size: 16),
                          const SizedBox(width: 8),
                          Text(data['buyerEmail'] ?? '', style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Product info
                JNCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Producto', style: context.typography.labelMedium.copyWith(color: context.colors.textTertiary)),
                      const SizedBox(height: 8),
                      Text(data['productName'] ?? '', style: context.typography.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (data['selectedSize'] != null && data['selectedSize'].toString().isNotEmpty) ...[
                            _chip('Talle: ${data['selectedSize']}'),
                            const SizedBox(width: 8),
                          ],
                          _chip('Cant: ${data['quantity']}'),
                          const SizedBox(width: 8),
                          _chip('Total: \$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}'),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Pedido el ${_formatDate(createdAt.toDate())}',
                          style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Receipt
                if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                  Text('Comprobante', style: context.typography.titleMedium.copyWith(color: context.colors.primary)),
                  const SizedBox(height: 12),
                  JNCard(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: _buildReceiptImage(receiptUrl),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action buttons
                if (status == 'pending_payment' || status == 'payment_uploaded') ...[
                  JNButton(
                    label: data['isQuotaPayment'] == true ? '✅ Confirmar Cuota' : '✅ Confirmar y Listo para Retirar',
                    onPressed: () => _updateStatus('confirmed'),
                    variant: JNButtonVariant.success,
                  ),
                  const SizedBox(height: 10),
                  JNButton(
                    label: '❌ Rechazar',
                    onPressed: _showRejectDialog,
                    variant: JNButtonVariant.danger,
                  ),
                ],

                if (status == 'confirmed' && data['isQuotaPayment'] != true) ...[
                  JNButton(
                    label: '📦 Marcar como Entregado',
                    onPressed: () => _updateStatus('delivered'),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceiptImage(String url) {
    final errorWidget = Container(
      height: 200,
      color: context.colors.surfaceLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 48, color: context.colors.textTertiary),
            const SizedBox(height: 8),
            const Text('Comprobante enviado'),
          ],
        ),
      ),
    );

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: double.infinity,
        height: 300,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }
    return Image.file(
      File(url),
      width: double.infinity,
      height: 300,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => errorWidget,
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: context.typography.badge.copyWith(fontSize: 11)),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}