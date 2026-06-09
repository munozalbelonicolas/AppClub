import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../data/mock/mock_data.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final nextMatch = MockData.nextMatch;
  late List<Map<String, dynamic>> _convocatoria;

  @override
  void initState() {
    super.initState();
    _convocatoria = List.from(MockData.convocatoria);
  }

  int get _confirmed => _convocatoria.where((c) => c['status'] == 'confirmed').length;
  int get _pending => _convocatoria.where((c) => c['status'] == 'pending').length;
  int get _absent => _convocatoria.where((c) => c['status'] == 'absent').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Convocatoria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Match Info ───────────────────────────
          JNCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceLight, AppColors.primary.withValues(alpha: 0.06)],
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PRÓXIMO PARTIDO',
                        style: AppTypography.badge.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const Spacer(),
                    Text('Fecha 6', style: AppTypography.labelSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${nextMatch['awayTeam']} vs ${nextMatch['homeTeam']}',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text('${nextMatch['date']} · ${nextMatch['time']}', style: AppTypography.bodySmall),
                    const SizedBox(width: 14),
                    Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(nextMatch['venue'] as String, style: AppTypography.bodySmall),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ─── Status Summary ───────────────────────
          Row(
            children: [
              _StatusChip(count: _confirmed, label: 'Confirmados', color: AppColors.success),
              const SizedBox(width: 8),
              _StatusChip(count: _pending, label: 'Pendientes', color: AppColors.warning),
              const SizedBox(width: 8),
              _StatusChip(count: _absent, label: 'Ausentes', color: AppColors.error),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── My Attendance Action ─────────────────
          JNCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent.withValues(alpha: 0.08), AppColors.surfaceLight],
            ),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_pin, size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Tu confirmación', style: AppTypography.titleMedium.copyWith(color: AppColors.accent)),
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
          Text('Convocados', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),

          ..._convocatoria.asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: JNCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    JNAvatar(
                      name: player['name'] as String,
                      size: 38,
                      borderColor: _statusColor(player['status'] as String),
                      borderWidth: 2,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player['name'] as String, style: AppTypography.titleSmall),
                          Row(
                            children: [
                              Text('#${player['number']}', style: AppTypography.bodySmall),
                              const SizedBox(width: 6),
                              Text('·', style: AppTypography.bodySmall),
                              const SizedBox(width: 6),
                              Text(player['position'] as String, style: AppTypography.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(player['status'] as String),
                  ],
                ),
              ).animate(delay: (300 + index * 50).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03),
            );
          }),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'absent':
        return AppColors.error;
      case 'delayed':
        return AppColors.warning;
      default:
        return AppColors.textTertiary;
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
  const _StatusChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: JNCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text('$count', style: AppTypography.headlineMedium.copyWith(color: color)),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}
