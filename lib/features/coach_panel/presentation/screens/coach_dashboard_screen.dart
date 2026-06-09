import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_stat_card.dart';
import '../../../../core/widgets/jn_section_header.dart';
import '../../../../data/mock/mock_data.dart';

class CoachDashboardScreen extends StatelessWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final players = MockData.players.where((p) => p['category'] == 'Sub-12').toList();
    final nextMatch = MockData.nextMatch;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Panel DT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Coach Header ─────────────────────────
          JNCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                JNAvatar(
                  name: 'Pablo Ramírez',
                  size: 50,
                  borderColor: AppColors.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DT Pablo Ramírez', style: AppTypography.titleLarge),
                      Text('Sub-12 · Temporada 2026', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const JNBadge(label: 'DT', type: JNBadgeType.accent),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── Team Stats Overview ──────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              JNStatCard(value: '${players.length}', label: 'Jugadores', icon: Icons.groups, color: AppColors.info),
              JNStatCard(value: '13', label: 'Puntos', icon: Icons.emoji_events, color: AppColors.accent),
              JNStatCard(value: '1°', label: 'Posición', icon: Icons.leaderboard, color: AppColors.success),
              JNStatCard(value: '5', label: 'Partidos', icon: Icons.sports_soccer, color: AppColors.primary),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Next Match Actions ───────────────────
          JNSectionHeader(
            title: 'Próximo partido',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          JNCard(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_soccer, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${nextMatch['homeTeam']} vs ${nextMatch['awayTeam']}',
                      style: AppTypography.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${nextMatch['date']} · ${nextMatch['time']} · ${nextMatch['venue']}',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.list_alt,
                        label: 'Convocatoria',
                        color: AppColors.primary,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.format_list_numbered,
                        label: 'Formación',
                        color: AppColors.accent,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.note_add,
                        label: 'Notas',
                        color: AppColors.info,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Squad ────────────────────────────────
          JNSectionHeader(
            title: 'Plantel Sub-12',
            actionLabel: '${players.length} jugadores',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          ...players.asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: JNCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    JNAvatar(
                      name: '${player['name']} ${player['lastName']}',
                      size: 40,
                      number: player['number'] as int,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${player['name']} ${player['lastName']}',
                            style: AppTypography.titleSmall,
                          ),
                          Row(
                            children: [
                              Text(player['position'] as String, style: AppTypography.bodySmall),
                              const SizedBox(width: 8),
                              Text('·', style: AppTypography.bodySmall),
                              const SizedBox(width: 8),
                              Text('${player['age']} años', style: AppTypography.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_soccer, size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text('${player['goals']}', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('${player['attendance']}%', style: AppTypography.bodySmall.copyWith(
                          color: (player['attendance'] as int) >= 90 ? AppColors.success : AppColors.warning,
                        )),
                      ],
                    ),
                  ],
                ),
              ).animate(delay: (300 + index * 60).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
