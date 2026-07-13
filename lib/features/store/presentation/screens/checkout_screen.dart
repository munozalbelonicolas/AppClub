import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String productId;
  final String productName;
  final String productImageUrl;
  final String selectedSize;
  final int quantity;
  final double unitPrice;

  const CheckoutScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.selectedSize,
    required this.quantity,
    required this.unitPrice,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isLoading = true;
  bool _isConfirming = false;
  Map<String, dynamic>? _bankConfig;

  @override
  void initState() {
    super.initState();
    _loadBankConfig();
  }

  Future<void> _loadBankConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('settings/store_config').get();
      if (doc.exists) {
        setState(() => _bankConfig = doc.data());
      }
    } catch (e) {
      AppLogger.error('Error loading bank config', error: e, tag: 'App');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmOrder() async {
    setState(() => _isConfirming = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final totalPrice = widget.unitPrice * widget.quantity;
      final db = FirebaseFirestore.instance;

      // Create the order
      final orderRef = await db.collection('store_orders').add({
        'buyerId': user.id,
        'buyerName': '${user.name} ${user.lastName}',
        'buyerEmail': user.email,
        'productId': widget.productId,
        'productName': widget.productName,
        'productImageUrl': widget.productImageUrl,
        'selectedSize': widget.selectedSize,
        'quantity': widget.quantity,
        'totalPrice': totalPrice,
        'status': 'pending_payment',
        'receiptUrl': null,
        'receiptUploadedAt': null,
        'adminNotes': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reduce stock
      await db.collection('store_products').doc(widget.productId).update({
        'stock': FieldValue.increment(-widget.quantity),
      });

      // Notify admins
      await db.collection('notifications').add({
        'type': 'store_purchase',
        'orderId': orderRef.id,
        'buyerName': '${user.name} ${user.lastName}',
        'productName': widget.productName,
        'selectedSize': widget.selectedSize,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Pedido confirmado! Ahora subí tu comprobante.'),
            backgroundColor: context.colors.success,
          ),
        );
        // Navigate to order detail to upload receipt
        Navigator.pushReplacement(
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
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 1),
        backgroundColor: context.colors.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.unitPrice * widget.quantity;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Checkout', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Order Summary
                  Text('Resumen del Pedido', style: context.typography.titleMedium.copyWith(color: context.colors.primary)),
                  const SizedBox(height: 12),
                  JNCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Product image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildProductImage(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.productName, style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                widget.selectedSize.isNotEmpty
                                    ? 'Talle: ${widget.selectedSize} • Cantidad: ${widget.quantity}'
                                    : 'Cantidad: ${widget.quantity}',
                                style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${totalPrice.toStringAsFixed(0)}',
                          style: context.typography.titleMedium.copyWith(color: context.colors.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price breakdown
                  if (widget.quantity > 1)
                    JNCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Precio unitario', style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary)),
                              Text('\$${widget.unitPrice.toStringAsFixed(0)}', style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cantidad', style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary)),
                              Text('x${widget.quantity}', style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                              Text('\$${totalPrice.toStringAsFixed(0)}', style: context.typography.titleMedium.copyWith(color: context.colors.accent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Bank Details
                  Text('Datos para Transferencia', style: context.typography.titleMedium.copyWith(color: context.colors.primary)),
                  const SizedBox(height: 4),
                  Text(
                    'Realizá la transferencia al siguiente CBU y luego subí el comprobante.',
                    style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                  ),
                  const SizedBox(height: 12),

                  if (_bankConfig != null) ...[
                    _buildBankRow('CBU', _bankConfig!['cbu'] ?? 'No configurado', true),
                    _buildBankRow('Alias', _bankConfig!['alias'] ?? 'No configurado', true),
                    _buildBankRow('Banco', _bankConfig!['bankName'] ?? 'No configurado', false),
                    _buildBankRow('Titular', _bankConfig!['accountHolder'] ?? 'No configurado', false),
                  ] else
                    JNCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Los datos bancarios aún no fueron configurados. Contactá al club.',
                        style: context.typography.bodyMedium.copyWith(color: context.colors.warning),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Instructions
                  JNCard(
                    color: context.colors.info.withValues(alpha: 0.08),
                    border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: context.colors.info, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Una vez realizada la transferencia, volvé a la app y subí el comprobante desde "Mis Compras" para que el club pueda verificar tu pago.',
                            style: context.typography.bodySmall.copyWith(color: context.colors.info),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  JNButton(
                    label: 'Confirmar Pedido',
                    onPressed: _isConfirming ? null : _confirmOrder,
                    isLoading: _isConfirming,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBankRow(String label, String value, bool copyable) {
    return JNCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () => _copyToClipboard(value, label),
              child: Icon(Icons.copy, size: 18, color: context.colors.accent),
            ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    const size = 60.0;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.shopping_bag, color: context.colors.accent),
    );

    final url = widget.productImageUrl;
    if (url.isEmpty) return placeholder;

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.file(
      File(url),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}