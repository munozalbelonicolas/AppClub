import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_match_card.dart';

// TODO: Connect to Firestore
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resultados'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Fixture'),
            Tab(text: 'Posiciones'),
            Tab(text: 'Goleadores'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFixtureTab(),
          _buildStandingsTab(),
          _buildScorersTab(),
        ],
      ),
    );
  }

  // ─── Fixture Tab ──────────────────────────────────
  Widget _buildFixtureTab() {
    final List<Map<String, dynamic>> matches = [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Category selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Sub-12',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16, color: AppColors.primary),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        if (matches.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay partidos programados',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ...matches.asMap().entries.map((entry) {
          final index = entry.key;
          final match = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index == 0 ||
                  match['matchday'] != matches[index - 1]['matchday'])
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: index > 0 ? 8 : 0),
                  child: Text(
                    'Fecha ${match['matchday']}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    JNMatchCard(
                          homeTeam: match['homeTeam'] as String,
                          awayTeam: match['awayTeam'] as String,
                          homeScore: match['homeScore'] as int?,
                          awayScore: match['awayScore'] as int?,
                          date: _formatDate(match['date'] as String),
                          time: match['time'] as String,
                          status: match['status'] as String,
                        )
                        .animate(delay: (index * 60).ms)
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: 0.03),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─── Standings Tab ────────────────────────────────
  Widget _buildStandingsTab() {
    final List<Map<String, dynamic>> standings = [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Table Header
        JNCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('EQUIPO', style: AppTypography.labelSmall)),
              SizedBox(
                width: 28,
                child: Text(
                  'PJ',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'G',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'E',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'P',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'DG',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'PTS',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 4),

        if (standings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.format_list_numbered,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay posiciones',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ...standings.asMap().entries.map((entry) {
          final index = entry.key;
          final team = entry.value;
          final isClub = team['isClub'] as bool;

          return JNCard(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            color: isClub ? AppColors.primary.withValues(alpha: 0.08) : null,
            border: isClub
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : Border.all(color: Colors.transparent),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: index < 2
                          ? AppColors.success.withValues(alpha: 0.15)
                          : index > 5
                          ? AppColors.error.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${team['pos']}',
                        style: AppTypography.labelMedium.copyWith(
                          color: index < 2
                              ? AppColors.success
                              : index > 5
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    team['team'] as String,
                    style: AppTypography.titleSmall.copyWith(
                      color: isClub
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: isClub ? FontWeight.w700 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['played']}',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['won']}',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['drawn']}',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['lost']}',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${(team['gd'] as int) > 0 ? '+' : ''}${team['gd']}',
                    style: AppTypography.bodySmall.copyWith(
                      color: (team['gd'] as int) > 0
                          ? AppColors.success
                          : (team['gd'] as int) < 0
                          ? AppColors.error
                          : AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${team['points']}',
                    style: AppTypography.titleMedium.copyWith(
                      color: isClub ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ).animate(delay: (100 + index * 50).ms).fadeIn(duration: 400.ms);
        }),
      ],
    );
  }

  // ─── Scorers Tab ──────────────────────────────────
  Widget _buildScorersTab() {
    final List<Map<String, dynamic>> scorers = [];

    if (scorers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no hay goleadores',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: scorers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final scorer = scorers[index];
        final isClub = scorer['isClub'] as bool;
        final isTop3 = index < 3;

        return JNCard(
              padding: const EdgeInsets.all(14),
              color: isClub ? AppColors.primary.withValues(alpha: 0.06) : null,
              border: isClub
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : null,
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isTop3
                          ? (index == 0
                                    ? AppColors.accent
                                    : index == 1
                                    ? AppColors.textSecondary
                                    : const Color(0xFFCD7F32))
                                .withValues(alpha: 0.15)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: AppTypography.titleMedium.copyWith(
                          color: isTop3
                              ? (index == 0
                                    ? AppColors.accent
                                    : index == 1
                                    ? AppColors.textSecondary
                                    : const Color(0xFFCD7F32))
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scorer['name'] as String,
                          style: AppTypography.titleMedium.copyWith(
                            color: isClub
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: isClub
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        Text(
                          scorer['team'] as String,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Goals
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isClub
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 14,
                          color: isClub
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${scorer['goals']}',
                          style: AppTypography.titleLarge.copyWith(
                            color: isClub
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .animate(delay: (index * 80).ms)
            .fadeIn(duration: 400.ms)
            .slideX(begin: 0.03);
      },
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
}
