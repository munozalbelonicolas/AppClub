import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_section_header.dart';
import '../../../../core/widgets/jn_stat_card.dart';
import '../../../player/presentation/screens/consolidated_roster_screen.dart';
import '../../../results/presentation/screens/manage_scorers_screen.dart';
import 'create_coach_report_screen.dart';
import 'formation_screen.dart';

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionUser = ref.watch(currentUserProvider)!;

    final playersAsync = ref.watch(playersStreamProvider);
    final List<Map<String, dynamic>> allPlayers = playersAsync.valueOrNull ?? [];
    
    // Filter players by assignedCategories or category
    final List<Map<String, dynamic>> players = allPlayers.where((p) {
      if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
        return sessionUser.assignedCategories!.contains(p['category']);
      }
      return p['category'] == sessionUser.category;
    }).toList();
    
    final matchesAsync = ref.watch(matchesStreamProvider);
    final List<Map<String, dynamic>> allMatches = matchesAsync.valueOrNull ?? [];
    final Map<String, dynamic>? nextMatch = allMatches.where((m) {
      final matchCat = m['category'];
      if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
        return sessionUser.assignedCategories!.contains(matchCat);
      }
      return matchCat == sessionUser.category;
    }).firstOrNull;

    return Scaffold(
      backgroundColor: context.colors.background,
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
                  name: '${sessionUser.name} ${sessionUser.lastName}',
                  size: 50,
                  borderColor: context.colors.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DT ${sessionUser.name} ${sessionUser.lastName}',
                        style: context.typography.titleLarge,
                      ),
                      Text(
                        '${sessionUser.assignedCategories?.join(', ') ?? sessionUser.category ?? 'Sin categoría'} • Temporada ${DateTime.now().year}',
                        style: context.typography.bodySmall,
                      ),
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
              JNStatCard(
                value: '${players.length}',
                label: 'Jugadores',
                icon: Icons.groups,
                color: context.colors.info,
              ),
              JNStatCard(
                value: '13',
                label: 'Puntos',
                icon: Icons.emoji_events,
                color: context.colors.accent,
              ),
              JNStatCard(
                value: '1°',
                label: 'Posición',
                icon: Icons.leaderboard,
                color: context.colors.success,
              ),
              JNStatCard(
                value: '5',
                label: 'Partidos',
                icon: Icons.sports_soccer,
                color: context.colors.primary,
              ),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),
          JNCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConsolidatedRosterScreen()),
              );
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: context.colors.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consolidado de Jugadores', style: context.typography.titleMedium),
                      Text('Listado completo y exportación a Excel', style: context.typography.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Next Match Actions ───────────────────
          if (nextMatch != null) ...[
            const JNSectionHeader(title: 'Próximo partido', padding: EdgeInsets.zero),
            const SizedBox(height: 12),
            JNCard(
              padding: const EdgeInsets.all(16),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        size: 18,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${nextMatch['homeTeam']} vs ${nextMatch['awayTeam']}',
                        style: context.typography.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${nextMatch['date']} · ${nextMatch['time']} · ${nextMatch['venue']}',
                    style: context.typography.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.list_alt,
                          label: 'Convocatoria',
                          color: context.colors.primary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.format_list_numbered,
                          label: 'Formación',
                          color: context.colors.accent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FormationScreen(matchId: nextMatch['id']),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.note_add,
                          label: 'Notas',
                          color: context.colors.info,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

            const SizedBox(height: 24),
          ],

          // ─── Squad ────────────────────────────────
          JNSectionHeader(
            title: 'Plantel ${sessionUser.assignedCategories?.join(', ') ?? sessionUser.category ?? 'Sin categoría'}',
            actionLabel: '${players.length} jugadores',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          if (players.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.groups, size: 48, color: context.colors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      'No hay jugadores registrados en esta(s) categoría(s)',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          ...players.asMap().entries.map((entry) {
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
                              name: '${player['name']} ${player['lastName']}',
                              size: 40,
                              number: player['number'] != null ? int.tryParse(player['number'].toString()) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${player['name']} ${player['lastName']}',
                                    style: context.typography.titleSmall,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        player['position']?.toString() ?? 'Sin Posición',
                                        style: context.typography.bodySmall,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('·', style: context.typography.bodySmall),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${player['age'] ?? '-'} años',
                                        style: context.typography.bodySmall,
                                      ),
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
                                    Icon(
                                      Icons.sports_soccer,
                                      size: 12,
                                      color: context.colors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${player['goals'] ?? 0}',
                                      style: context.typography.labelMedium.copyWith(
                                        color: context.colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${player['attendance'] ?? 0}%',
                                  style: context.typography.bodySmall.copyWith(
                                    color: (int.tryParse(player['attendance']?.toString() ?? '0') ?? 0) >= 90
                                        ? context.colors.success
                                        : context.colors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate(delay: (300 + index * 60).ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.03),
            );
          }),

          const SizedBox(height: 24),

          // ─── Comunicación Institucional ─────────────
          const JNSectionHeader(
            title: 'Comunicación Institucional',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          JNCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envía informes o novedades importantes directamente a la directiva del club.',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateCoachReportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar Informe a Directiva'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Gestión de Goleadores ─────────────
          const JNSectionHeader(
            title: 'Gestión Deportiva',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          JNCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageScorersScreen(),
                ),
              );
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sports_soccer, color: context.colors.accent, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Goleadores por Categoría', style: context.typography.titleMedium),
                      Text('Gestionar la tabla de goleadores de la liga.', style: context.typography.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.textTertiary),
              ],
            ),
          ).animate(delay: 550.ms).fadeIn(duration: 400.ms),
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
            Text(label, style: context.typography.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}