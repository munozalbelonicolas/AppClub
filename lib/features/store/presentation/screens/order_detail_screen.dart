import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../widgets/order_status_badge.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  late final Stream<DocumentSnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).snapshots();
  }

  Future<void> _uploadReceipt() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked == null) return;

      setState(() => _isUploading = true);

      final file = File(picked.path);
      final user = ref.read(currentUserProvider)!;

      // Upload to Firebase Storage and get download URL
      final downloadUrl = await ImageUploadService.uploadReceipt(file, widget.orderId);

      await FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).update({
        'receiptUrl': downloadUrl,
        'receiptUploadedAt': FieldValue.serverTimestamp(),
        'status': 'payment_uploaded',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify admins
      final orderDoc = await FirebaseFirestore.instance.collection('store_orders').doc(widget.orderId).get();
      final orderData = orderDoc.data()!;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'store_receipt_uploaded',
        'orderId': widget.orderId,
        'buyerName': '${user.name} ${user.lastName}',
        'productName': orderData['productName'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comprobante enviado. El club verificará tu pago.'),
            backgroundColor: context.colors.success,
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Detalle del Pedido', style: context.typography.titleLarge),
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
          final adminNotes = data['adminNotes'] as String?;
          final createdAt = data['createdAt'] as Timestamp?;
          final productImageUrl = data['productImageUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status
                Center(child: OrderStatusBadge(status: status)),
                const SizedBox(height: 16),

                // Order Timeline
                _buildOrderTimeline(status),
                const SizedBox(height: 20),

                // Product info with image
                JNCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Producto', style: context.typography.labelMedium.copyWith(color: context.colors.textTertiary)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Product thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildProductThumbnail(productImageUrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['productName'] ?? '', style: context.typography.titleMedium),
                                const SizedBox(height: 4),
                                if (createdAt != null)
                                  Text(
                                    'Pedido el ${_formatDate(createdAt.toDate())}',
                                    style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if ((data['selectedSize'] ?? '').isNotEmpty) ...[
                            _infoChip('Talle', data['selectedSize']),
                            const SizedBox(width: 12),
                          ],
                          _infoChip('Cantidad', '${data['quantity'] ?? 1}'),
                          const SizedBox(width: 12),
                          _infoChip('Total', '\$${(data['totalPrice'] ?? 0).toStringAsFixed(0)}'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Receipt section
                Text('Comprobante de Pago', style: context.typography.titleMedium.copyWith(color: context.colors.primary)),
                const SizedBox(height: 12),

                if (status == 'pending_payment') ...[
                  JNCard(
                    color: context.colors.warning.withValues(alpha: 0.08),
                    border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: context.colors.warning),
                        const SizedBox(height: 12),
                        Text(
                          'Realizá la transferencia y luego subí el comprobante aquí.',
                          style: context.typography.bodyMedium.copyWith(color: context.colors.warning),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        JNButton(
                          label: 'Subir Comprobante',
                          onPressed: _isUploading ? null : _uploadReceipt,
                          isLoading: _isUploading,
                          icon: Icons.upload_file,
                        ),
                      ],
                    ),
                  ),
                ] else if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                  JNCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: _buildReceiptImage(receiptUrl),
                        ),
                        if (status == 'payment_uploaded')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Esperando verificación del club...',
                              style: context.typography.bodySmall.copyWith(color: context.colors.info),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Admin notes (rejection reason)
                if (status == 'rejected' && adminNotes != null && adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  JNCard(
                    color: context.colors.error.withValues(alpha: 0.08),
                    border: Border.all(color: context.colors.error.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Motivo del rechazo', style: context.typography.labelMedium.copyWith(color: context.colors.error)),
                        const SizedBox(height: 8),
                        Text(adminNotes, style: context.typography.bodyMedium),
                      ],
                    ),
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

  /// Build a visual timeline of the order's progress.
  Widget _buildOrderTimeline(String currentStatus) {
    final steps = [
      const _TimelineStep('Pedido Creado', 'pending_payment', Icons.shopping_cart),
      const _TimelineStep('Comprobante Enviado', 'payment_uploaded', Icons.upload_file),
      const _TimelineStep('Pago Confirmado', 'confirmed', Icons.check_circle),
      const _TimelineStep('Entregado', 'delivered', Icons.local_shipping),
    ];

    final statusOrder = ['pending_payment', 'payment_uploaded', 'confirmed', 'delivered'];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final isRejected = currentStatus == 'rejected';

    return JNCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isCompleted = !isRejected && currentIndex >= index;
          final isCurrent = !isRejected && currentIndex == index;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isRejected
                          ? context.colors.error.withValues(alpha: 0.15)
                          : isCompleted
                              ? context.colors.success.withValues(alpha: 0.15)
                              : context.colors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isRejected
                            ? context.colors.error
                            : isCompleted
                                ? context.colors.success
                                : context.colors.border,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      isRejected && isCurrent
                          ? Icons.close
                          : isCompleted
                              ? Icons.check
                              : step.icon,
                      size: 14,
                      color: isRejected
                          ? context.colors.error
                          : isCompleted
                              ? context.colors.success
                              : context.colors.textTertiary,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 24,
                      color: isCompleted && !isRejected
                          ? context.colors.success.withValues(alpha: 0.3)
                          : context.colors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Step label
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    isRejected && index == currentIndex ? 'Rechazado' : step.label,
                    style: context.typography.bodySmall.copyWith(
                      color: isCompleted || isCurrent
                          ? (isRejected ? context.colors.error : context.colors.textPrimary)
                          : context.colors.textTertiary,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Build product thumbnail — supports network URLs and local files.
  Widget _buildProductThumbnail(String? imageUrl) {
    const size = 60.0;
    final placeholder = Container(
      width: size,
      height: size,
      color: context.colors.surfaceLight,
      child: Icon(Icons.shopping_bag, color: context.colors.accent, size: 28),
    );

    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.file(
      File(imageUrl),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  /// Build receipt image — supports network URLs and legacy local paths.
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

  Widget _infoChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: context.typography.badge.copyWith(color: context.colors.textTertiary, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

/// Internal model for timeline steps.
class _TimelineStep {
  final String label;
  final String statusKey;
  final IconData icon;
  const _TimelineStep(this.label, this.statusKey, this.icon);
}