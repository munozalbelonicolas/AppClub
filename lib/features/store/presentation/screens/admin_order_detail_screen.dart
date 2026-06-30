import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../widgets/order_status_badge.dart';

class AdminOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends ConsumerState<AdminOrderDetailScreen> {
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
          notifType = 'store_order_confirmed';
          notifMessage = '✅ Tu pago por ${orderData['productName']} fue confirmado.';
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
          SnackBar(content: Text('Estado actualizado a: $newStatus'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
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
            child: const Text('Rechazar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Gestionar Pedido', style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).snapshots(),
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
                      Text('Comprador', style: AppTypography.labelMedium.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(data['buyerName'] ?? '', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, color: AppColors.textTertiary, size: 16),
                          const SizedBox(width: 8),
                          Text(data['buyerEmail'] ?? '', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
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
                      Text('Producto', style: AppTypography.labelMedium.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: 8),
                      Text(data['productName'] ?? '', style: AppTypography.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _chip('Talle: ${data['selectedSize']}'),
                          const SizedBox(width: 8),
                          _chip('Cant: ${data['quantity']}'),
                          const SizedBox(width: 8),
                          _chip('Total: \$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}'),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Pedido el ${_formatDate(createdAt.toDate())}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Receipt
                if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                  Text('Comprobante', style: AppTypography.titleMedium.copyWith(color: AppColors.primary)),
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
                if (status == 'payment_uploaded') ...[
                  JNButton(
                    label: '✅ Confirmar Pago',
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

                if (status == 'confirmed') ...[
                  JNButton(
                    label: '📦 Marcar como Entregado',
                    onPressed: () => _updateStatus('delivered'),
                    variant: JNButtonVariant.primary,
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
      color: AppColors.surfaceLight,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 8),
            Text('Comprobante enviado'),
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
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: AppTypography.badge.copyWith(fontSize: 11)),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
