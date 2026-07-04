import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
  }

  int getConfirmed(List<Map<String, dynamic>> conv) =>
      conv.where((c) => c['status'] == 'confirmed').length;
  int getPending(List<Map<String, dynamic>> conv) =>
      conv.where((c) => c['status'] == 'pending').length;
  int getAbsent(List<Map<String, dynamic>> conv) => 
      conv.where((c) => c['status'] == 'absent').length;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final nextMatch = matchesAsync.valueOrNull?.firstOrNull;
    
    final convocatoriaAsync = nextMatch != null 
        ? ref.watch(convocatoriaStreamProvider(nextMatch['id'])) 
        : const AsyncValue.data(<Map<String, dynamic>>[]);
    
    final convocatoriaList = convocatoriaAsync.valueOrNull ?? [];
    
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Convocatoria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Match Info ───────────────────────────
          if (nextMatch != null) ...[
            JNCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.surfaceLight,
                  context.colors.primary.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PRÓXIMO PARTIDO',
                          style: context.typography.badge.copyWith(
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text('Fecha 6', style: context.typography.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${nextMatch['awayTeam']} vs ${nextMatch['homeTeam']}',
                    style: context.typography.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${nextMatch['date']} · ${nextMatch['time']}',
                        style: context.typography.bodySmall,
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        nextMatch['venue'] as String,
                        style: context.typography.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 16),
          ],

          // ─── Status Summary ───────────────────────
          Row(
            children: [
              _StatusChip(
                count: getConfirmed(convocatoriaList),
                label: 'Confirmados',
                color: context.colors.success,
              ),
              const SizedBox(width: 8),
              _StatusChip(
                count: getPending(convocatoriaList),
                label: 'Pendientes',
                color: context.colors.warning,
              ),
              const SizedBox(width: 8),
              _StatusChip(
                count: getAbsent(convocatoriaList),
                label: 'Ausentes',
                color: context.colors.error,
              ),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── My Attendance Action ─────────────────
          JNCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.accent.withValues(alpha: 0.08),
                context.colors.surfaceLight,
              ],
            ),
            border: Border.all(color: context.colors.accent.withValues(alpha: 0.3)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_pin, size: 20, color: context.colors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Tu confirmación',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.accent,
                      ),
                    ),
                    const Spacer(),
                    JNBadge.confirmed(),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: JNButton(
                        label: 'Confirmar',
                        onPressed: () {},
                        size: JNButtonSize.small,
                        icon: Icons.check,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: JNButton(
                        label: 'Ausente',
                        onPressed: () {},
                        variant: JNButtonVariant.outline,
                        size: JNButtonSize.small,
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: JNButton(
                        label: 'Demora',
                        onPressed: () {},
                        variant: JNButtonVariant.ghost,
                        size: JNButtonSize.small,
                        icon: Icons.schedule,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── Squad List ───────────────────────────
          Text('Convocados', style: context.typography.headlineSmall),
          const SizedBox(height: 12),

          if (convocatoriaList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.how_to_reg,
                      size: 48,
                      color: context.colors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay convocados',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ...convocatoriaList.asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  JNCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            JNAvatar(
                              name: player['name'] as String,
                              size: 38,
                              borderColor: _statusColor(
                                player['status'] as String,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player['name'] as String,
                                    style: context.typography.titleSmall,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '#${player['number']}',
                                        style: context.typography.bodySmall,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('·', style: context.typography.bodySmall),
                                      const SizedBox(width: 6),
                                      Text(
                                        player['position'] as String,
                                        style: context.typography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(player['status'] as String),
                          ],
                        ),
                      )
                      .animate(delay: (300 + index * 50).ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.03),
            );
          }),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return context.colors.success;
      case 'pending':
        return context.colors.warning;
      case 'absent':
        return context.colors.error;
      case 'delayed':
        return context.colors.warning;
      default:
        return context.colors.textTertiary;
    }
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'confirmed':
        return JNBadge.confirmed();
      case 'pending':
        return JNBadge.pending();
      case 'absent':
        return JNBadge.absent();
      case 'delayed':
        return JNBadge.delayed();
      default:
        return const SizedBox();
    }
  }
}

class _StatusChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatusChip({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: JNCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text(
              '$count',
              style: context.typography.headlineMedium.copyWith(color: color),
            ),
            Text(label, style: context.typography.labelSmall),
          ],
        ),
      ),
    );
  }
}
