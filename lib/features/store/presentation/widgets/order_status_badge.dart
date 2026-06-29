import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(config.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: AppTypography.badge.copyWith(color: config.color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(String s) {
    switch (s) {
      case 'pending_payment':
        return _StatusConfig('🟡', 'Pendiente de Pago', AppColors.warning);
      case 'payment_uploaded':
        return _StatusConfig('🔵', 'Comprobante Enviado', AppColors.info);
      case 'confirmed':
        return _StatusConfig('🟢', 'Pago Confirmado', AppColors.success);
      case 'delivered':
        return _StatusConfig('✅', 'Entregado', AppColors.success);
      case 'rejected':
        return _StatusConfig('🔴', 'Rechazado', AppColors.error);
      default:
        return _StatusConfig('⚪', s, AppColors.textTertiary);
    }
  }
}

class _StatusConfig {
  final String emoji;
  final String label;
  final Color color;
  _StatusConfig(this.emoji, this.label, this.color);
}
