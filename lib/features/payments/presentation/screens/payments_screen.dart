import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../data/mock/mock_data.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payments = MockData.payments;
    final pending = payments.where((p) => p['status'] == 'pending').toList();
    final paid = payments.where((p) => p['status'] == 'paid').toList();
    final totalPaid = paid.fold<int>(0, (sum, p) => sum + (p['amount'] as int));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cuotas y Pagos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Balance Card ─────────────────────────
          JNCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceLight,
                AppColors.primary.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet, size: 24, color: AppColors.accent),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estado de cuenta', style: AppTypography.labelMedium),
                        Text(
                          '${MockData.currentPlayer['name']} ${MockData.currentPlayer['lastName']}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                    const Spacer(),
                    pending.isNotEmpty ? JNBadge.pending() : JNBadge.paid(),
                  ],
                ),
                const SizedBox(height: 20),
                if (pending.isNotEmpty) ...[
                  Text('Pendiente', style: AppTypography.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_formatNumber(pending.first['amount'] as int)}',
                    style: AppTypography.displayMedium.copyWith(color: AppColors.warning),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vence el ${_formatDate(pending.first['dueDate'] as String)}',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  JNButton(
                    label: 'Pagar cuota',
                    onPressed: () {},
                    fullWidth: true,
                    icon: Icons.payment,
                  ),
                ] else ...[
                  Text(
                    '¡Todo al día!',
                    style: AppTypography.displaySmall.copyWith(color: AppColors.success),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // ─── Summary Row ──────────────────────────
          Row(
            children: [
              Expanded(
                child: JNCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text('Pagadas', style: AppTypography.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${paid.length}', style: AppTypography.headlineLarge.copyWith(color: AppColors.success)),
                      Text('cuotas', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: JNCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text('Total pagado', style: AppTypography.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('\$${_formatNumber(totalPaid)}', style: AppTypography.headlineLarge.copyWith(color: AppColors.accent)),
                      Text('en 2026', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Payment History ──────────────────────
          Text('Historial de pagos', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),

          ...payments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            final isPaid = payment['status'] == 'paid';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JNCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPaid ? Icons.check_circle_outline : Icons.schedule,
                        color: isPaid ? AppColors.success : AppColors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(payment['month'] as String, style: AppTypography.titleMedium),
                          Text(
                            isPaid
                                ? 'Pagado el ${_formatDate(payment['paidDate'] as String)}'
                                : 'Vence el ${_formatDate(payment['dueDate'] as String)}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${_formatNumber(payment['amount'] as int)}',
                          style: AppTypography.titleLarge.copyWith(
                            color: isPaid ? AppColors.textPrimary : AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        isPaid ? JNBadge.paid() : JNBadge.pending(),
                      ],
                    ),
                  ],
                ),
              ).animate(delay: (300 + index * 80).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${int.parse(parts[2])} ${months[int.parse(parts[1])]}';
  }

  String _formatNumber(int n) {
    final str = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }
}
