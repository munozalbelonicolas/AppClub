import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionUser = ref.watch(currentUserProvider)!;

    final paymentsAsync = ref.watch(userPaymentsStreamProvider(sessionUser.id));
    final List<Map<String, dynamic>> payments = paymentsAsync.valueOrNull ?? [];
    final pending = payments.where((p) => p['status'] == 'pending').toList();
    final paid = payments.where((p) => p['status'] == 'paid').toList();
    final totalPaid = paid.fold<int>(0, (sum, p) => sum + (p['amount'] as num).toInt());

    return Scaffold(
      backgroundColor: context.colors.background,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado de cuenta',
                          style: context.typography.labelMedium,
                        ),
                        Text(
                          '${sessionUser.name} ${sessionUser.lastName}',
                          style: context.typography.bodySmall,
                        ),
                      ],
                    ),
                    const Spacer(),
                    pending.isNotEmpty ? JNBadge.pending() : JNBadge.paid(),
                  ],
                ),
                const SizedBox(height: 20),
                if (pending.isNotEmpty) ...[
                  Text('Pendiente', style: context.typography.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_formatNumber(pending.first['amount'] as int)}',
                    style: context.typography.displayMedium.copyWith(
                      color: context.colors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vence el ${_formatDate(pending.first['dueDate'] as String)}',
                    style: context.typography.bodySmall,
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
                    style: context.typography.displaySmall.copyWith(
                      color: context.colors.success,
                    ),
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
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: context.colors.success,
                          ),
                          const SizedBox(width: 6),
                          Text('Pagadas', style: context.typography.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${paid.length}',
                        style: context.typography.headlineLarge.copyWith(
                          color: context.colors.success,
                        ),
                      ),
                      Text('cuotas', style: context.typography.bodySmall),
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
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: context.colors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text('Total pagado', style: context.typography.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${_formatNumber(totalPaid)}',
                        style: context.typography.headlineLarge.copyWith(
                          color: context.colors.accent,
                        ),
                      ),
                      Text(
                        'en ${DateTime.now().year}',
                        style: context.typography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Payment History ──────────────────────
          Text('Historial de pagos', style: context.typography.headlineSmall),
          const SizedBox(height: 12),

          if (payments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: context.colors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay cuotas registradas',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ...payments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            final isPaid = payment['status'] == 'paid';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  JNCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? context.colors.success.withValues(alpha: 0.12)
                                    : context.colors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isPaid
                                    ? Icons.check_circle_outline
                                    : Icons.schedule,
                                color: isPaid
                                    ? context.colors.success
                                    : context.colors.warning,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    payment['month'] as String,
                                    style: context.typography.titleMedium,
                                  ),
                                  Text(
                                    isPaid
                                        ? 'Pagado el ${_formatDate(payment['paidDate'] as String)}'
                                        : 'Vence el ${_formatDate(payment['dueDate'] as String)}',
                                    style: context.typography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${_formatNumber(payment['amount'] as int)}',
                                  style: context.typography.titleLarge.copyWith(
                                    color: isPaid
                                        ? context.colors.textPrimary
                                        : context.colors.warning,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                isPaid ? JNBadge.paid() : JNBadge.pending(),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate(delay: (300 + index * 80).ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.03),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
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