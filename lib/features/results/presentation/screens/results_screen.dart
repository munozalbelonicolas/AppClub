import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_match_card.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'Primera';

  String? _lastChildId;

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
    final categories = ref.watch(appCategoriesProvider);
    final sessionUser = ref.watch(currentUserProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    
    // Set initial category from selected child if parent
    if (sessionUser?.role == 'tutor' && selectedChild != null && selectedChild['category'] != null) {
      if (_lastChildId != selectedChild['id']) {
        _selectedCategory = selectedChild['category'] as String;
        _lastChildId = selectedChild['id'] as String?;
      }
    }

    if (!categories.contains(_selectedCategory) && categories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedCategory = categories.first;
        });
      });
    }

    return Scaffold(
      backgroundColor: context.colors.background,
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
      body: Column(
        children: [
          _buildCategorySelector(categories),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFixtureTab(),
                _buildStandingsTab(),
                _buildScorersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(List<String> categories) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.category, color: context.colors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: context.colors.primary),
                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: context.typography.titleMedium))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fixture Tab ──────────────────────────────────
  Widget _buildFixtureTab() {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final List<Map<String, dynamic>> matches = matchesAsync.valueOrNull ?? [];
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [

        if (matches.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: context.colors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay partidos programados',
                    style: context.typography.titleMedium.copyWith(
                      color: context.colors.textSecondary,
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
                    style: context.typography.labelMedium.copyWith(
                      color: context.colors.textTertiary,
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
          color: context.colors.surfaceVariant,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#',
                  style: context.typography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('EQUIPO', style: context.typography.labelSmall)),
              SizedBox(
                width: 28,
                child: Text(
                  'PJ',
                  style: context.typography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'G',
                  style: context.typography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'E',
                  style: context.typography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'P',
                  style: context.typography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'DG',
                  style: context.typography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'PTS',
                  style: context.typography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.accent,
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
                    color: context.colors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay posiciones',
                    style: context.typography.titleMedium.copyWith(
                      color: context.colors.textSecondary,
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
            color: isClub ? context.colors.primary.withValues(alpha: 0.08) : null,
            border: isClub
                ? Border.all(
                    color: context.colors.primary.withValues(alpha: 0.3),
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
                          ? context.colors.success.withValues(alpha: 0.15)
                          : index > 5
                          ? context.colors.error.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${team['pos']}',
                        style: context.typography.labelMedium.copyWith(
                          color: index < 2
                              ? context.colors.success
                              : index > 5
                              ? context.colors.error
                              : context.colors.textSecondary,
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
                    style: context.typography.titleSmall.copyWith(
                      color: isClub
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
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
                    style: context.typography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['won']}',
                    style: context.typography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['drawn']}',
                    style: context.typography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${team['lost']}',
                    style: context.typography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${(team['gd'] as int) > 0 ? '+' : ''}${team['gd']}',
                    style: context.typography.bodySmall.copyWith(
                      color: (team['gd'] as int) > 0
                          ? context.colors.success
                          : (team['gd'] as int) < 0
                          ? context.colors.error
                          : context.colors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${team['points']}',
                    style: context.typography.titleMedium.copyWith(
                      color: isClub ? context.colors.accent : context.colors.textPrimary,
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
    final scorersAsync = ref.watch(scorersStreamProvider(_selectedCategory));

    return scorersAsync.when(
      data: (scorers) {
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
                color: context.colors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no hay goleadores',
                style: context.typography.titleMedium.copyWith(
                  color: context.colors.textSecondary,
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
              color: isClub ? context.colors.primary.withValues(alpha: 0.06) : null,
              border: isClub
                  ? Border.all(
                      color: context.colors.primary.withValues(alpha: 0.2),
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
                                    ? context.colors.accent
                                    : index == 1
                                    ? context.colors.textSecondary
                                    : const Color(0xFFCD7F32))
                                .withValues(alpha: 0.15)
                          : context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: context.typography.titleMedium.copyWith(
                          color: isTop3
                              ? (index == 0
                                    ? context.colors.accent
                                    : index == 1
                                    ? context.colors.textSecondary
                                    : const Color(0xFFCD7F32))
                              : context.colors.textTertiary,
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
                          style: context.typography.titleMedium.copyWith(
                            color: isClub
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            fontWeight: isClub
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        Text(
                          scorer['team'] as String,
                          style: context.typography.bodySmall,
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
                          ? context.colors.primary.withValues(alpha: 0.12)
                          : context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 14,
                          color: isClub
                              ? context.colors.primary
                              : context.colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${scorer['goals']}',
                          style: context.typography.titleLarge.copyWith(
                            color: isClub
                                ? context.colors.primary
                                : context.colors.textPrimary,
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: context.colors.error))),
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