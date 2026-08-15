import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import 'manage_scorers_screen.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'all';
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
    final rawCategories = ref.watch(appCategoriesProvider);
    final sessionUser = ref.watch(currentUserProvider);
    final selectedChild = ref.watch(selectedChildProvider);

    List<String> categories = ['all', ...rawCategories];

    if (sessionUser?.role == 'tutor') {
      final players = ref.watch(tutorPlayersStreamProvider(sessionUser!.id)).valueOrNull ?? [];
      final tutorCategories = players
          .map((p) => p['category'] as String?)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      if (tutorCategories.isNotEmpty) {
        categories = ['all', ...tutorCategories];
      }
    }

    if (sessionUser?.role == 'tutor' && selectedChild != null && selectedChild['category'] != null) {
      if (_lastChildId != selectedChild['id']) {
        _selectedCategory = selectedChild['category'] as String;
        _lastChildId = selectedChild['id'] as String?;
      }
    }

    if (!categories.contains(_selectedCategory) && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    final bool canManage = sessionUser?.isAdmin == true || sessionUser?.role == 'dt' || sessionUser?.isCoach == true;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Resultados y Torneo'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Gestionar Goleadores',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageScorersScreen()),
                );
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.colors.accent,
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
                _buildFixtureTab(canManage),
                _buildStandingsTab(),
                _buildScorersTab(canManage),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: context.colors.primary, size: 22),
          const SizedBox(width: 10),
          Text('Categoría:', style: context.typography.labelMedium.copyWith(color: context.colors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: context.colors.surface,
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: context.colors.primary),
                  style: context.typography.titleMedium,
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat == 'all' ? 'Todas las Categorías (Jornada General)' : 'Categoría $cat'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Fixture & Resultados Tab (Jornadas y 10 Categorías) ──────────────────────────────────
  Widget _buildFixtureTab(bool canManage) {
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);
    final clubs = clubsAsync.valueOrNull ?? [];

    return fixturesAsync.when(
      data: (allFixtures) {
        if (allFixtures.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer, size: 48, color: context.colors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No hay fechas programadas en el fixture',
                    style: context.typography.titleMedium.copyWith(color: context.colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: allFixtures.length,
          itemBuilder: (context, fIndex) {
            final fixture = allFixtures[fIndex];
            final allMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
            final fixtureName = fixture['name'] ?? 'Fecha ${fIndex + 1}';
            final fixtureDate = fixture['date']?.toString() ?? '';

            // Filtrar partidos de la fecha según la categoría seleccionada
            final displayedMatches = allMatches.where((m) {
              if (_selectedCategory == 'all') return true;
              final cat = m['category']?.toString();
              return cat == null || cat == 'all' || cat == _selectedCategory;
            }).toList();

            if (_selectedCategory != 'all' && displayedMatches.isEmpty) {
              return const SizedBox.shrink();
            }

            // Calcular Puntos Globales de la Jornada (2 pts ganar, 1 pt empatar, 0 perder)
            int homeTotalPts = 0;
            int awayTotalPts = 0;
            int playedCount = 0;

            String? homeClubId;
            String? awayClubId;

            for (final m in allMatches) {
              homeClubId ??= m['homeClubId']?.toString();
              awayClubId ??= m['awayClubId']?.toString();

              final hScore = m['homeScore'] != null ? int.tryParse(m['homeScore'].toString()) : null;
              final aScore = m['awayScore'] != null ? int.tryParse(m['awayScore'].toString()) : null;
              final status = m['status']?.toString() ?? '';

              if (hScore != null && aScore != null && status != 'scheduled') {
                playedCount++;
                if (hScore > aScore) {
                  homeTotalPts += 2;
                } else if (hScore < aScore) {
                  awayTotalPts += 2;
                } else {
                  homeTotalPts += 1;
                  awayTotalPts += 1;
                }
              }
            }

            final homeClub = clubs.where((c) => c['id'] == homeClubId).firstOrNull;
            final awayClub = clubs.where((c) => c['id'] == awayClubId).firstOrNull;
            final homeName = homeClub?['name'] ?? 'Local';
            final awayName = awayClub?['name'] ?? 'Visitante';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: JNCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header de la Fecha & Marcador General ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fixtureName,
                              style: context.typography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (fixtureDate.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                fixtureDate,
                                style: context.typography.labelSmall.copyWith(color: context.colors.textSecondary),
                              ),
                            ],
                          ],
                        ),

                        // Botón de Cargar Jornada Completa (Admin / DT)
                        if (canManage && allMatches.isNotEmpty)
                          InkWell(
                            onTap: () => _showFullMatchdayResultsModal(
                              context,
                              fixture: fixture,
                              clubs: clubs,
                              homeClub: homeClub,
                              awayClub: awayClub,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.colors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.colors.accent.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note, size: 16, color: context.colors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cargar Jornada (10 Cat.)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─── Banner de Puntos Totales de la Jornada ───
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _buildClubSmallAvatar(homeClub),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    homeName,
                                    style: context.typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$homeTotalPts pts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 11)),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  '$awayTotalPts pts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.accent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    awayName,
                                    style: context.typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildClubSmallAvatar(awayClub),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Puntos de Jornada: $playedCount/${allMatches.length} partidos jugados (2 pts Victoria · 1 pt Empate)',
                          style: TextStyle(fontSize: 10, color: context.colors.textTertiary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ─── Lista de Partidos de las Categorías ───
                    ...displayedMatches.asMap().entries.map((entry) {
                      final matchIndexInAll = allMatches.indexOf(entry.value);
                      final match = entry.value;
                      final mHomeClub = clubs.where((c) => c['id'] == match['homeClubId']).firstOrNull ?? homeClub;
                      final mAwayClub = clubs.where((c) => c['id'] == match['awayClubId']).firstOrNull ?? awayClub;

                      final catLabel = match['category']?.toString() ?? 'Cat. General';
                      final status = match['status']?.toString() ?? 'scheduled';
                      final bool isFinished = status == 'finished' || status == 'finalizado';
                      final bool isLive = status == 'live' || status == 'en vivo';
                      final int? homeScore = match['homeScore'] != null ? int.tryParse(match['homeScore'].toString()) : null;
                      final int? awayScore = match['awayScore'] != null ? int.tryParse(match['awayScore'].toString()) : null;
                      final bool hasScores = homeScore != null && awayScore != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLive
                                ? context.colors.error.withValues(alpha: 0.5)
                                : context.colors.border.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Categoría y Horario
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    catLabel.startsWith('20') ? 'Categoría $catLabel' : catLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ),
                                if (match['time'] != null && match['time'].toString().isNotEmpty)
                                  Text(
                                    match['time'].toString(),
                                    style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Fila de Equipos y Marcador
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Local
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          mHomeClub?['name'] ?? 'Local',
                                          style: context.typography.titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildClubSmallAvatar(mHomeClub),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Marcador
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: hasScores || isFinished || isLive
                                      ? Text(
                                          '${homeScore ?? 0} - ${awayScore ?? 0}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isLive ? context.colors.error : context.colors.textPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'VS',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE5B842)),
                                        ),
                                ),
                                const SizedBox(width: 8),

                                // Visitante
                                Expanded(
                                  child: Row(
                                    children: [
                                      _buildClubSmallAvatar(mAwayClub),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          mAwayClub?['name'] ?? 'Visitante',
                                          style: context.typography.titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Goleadores del partido
                            if (match['scorers'] != null && (match['scorers'] as List).isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: (match['scorers'] as List).map((sc) {
                                  final scMap = sc as Map<String, dynamic>;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: context.colors.border.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sports_soccer, size: 10, color: Color(0xFFE5B842)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${scMap['name']} (${scMap['goals']})',
                                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 6),

                            // Fila de Estado y Botones de Acción
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (isLive)
                                  const JNBadge(label: '● EN VIVO', type: JNBadgeType.error, small: true)
                                else if (isFinished)
                                  const JNBadge(label: 'FINALIZADO', type: JNBadgeType.success, small: true)
                                else
                                  const JNBadge(label: 'PROGRAMADO', small: true),

                                if (canManage)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Botón Goleadores
                                      InkWell(
                                        onTap: () => _showMatchScorersModal(
                                          context,
                                          fixture: fixture,
                                          matchIndex: matchIndexInAll,
                                          homeClub: mHomeClub,
                                          awayClub: mAwayClub,
                                          category: catLabel,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: context.colors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: context.colors.primary.withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.emoji_events_outlined, size: 13, color: context.colors.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Goleadores',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: context.colors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // Botón Resultado
                                      InkWell(
                                        onTap: () => _showSingleMatchResultModal(
                                          context,
                                          fixture: fixture,
                                          matchIndex: matchIndexInAll,
                                          homeClub: mHomeClub,
                                          awayClub: mAwayClub,
                                          category: catLabel,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: context.colors.accent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: context.colors.accent.withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.sports_soccer, size: 13, color: context.colors.accent),
                                              const SizedBox(width: 4),
                                              Text(
                                                hasScores ? 'Editar Goles' : '⚽ Resultado',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: context.colors.accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: context.colors.error))),
    );
  }

  Widget _buildClubSmallAvatar(Map<String, dynamic>? club) {
    final logoUrl = club?['logoUrl']?.toString();
    return CircleAvatar(
      radius: 12,
      backgroundColor: context.colors.surfaceLight,
      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
      child: logoUrl == null || logoUrl.isEmpty ? const Icon(Icons.shield, size: 12) : null,
    );
  }

  // ─── Modal: Cargar Jornada Completa (Las 10 Categorías) ──────────────────────────────────
  void _showFullMatchdayResultsModal(
    BuildContext context, {
    required Map<String, dynamic> fixture,
    required List<Map<String, dynamic>> clubs,
    required Map<String, dynamic>? homeClub,
    required Map<String, dynamic>? awayClub,
  }) {
    final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    final homeName = homeClub?['name'] ?? 'Local';
    final awayName = awayClub?['name'] ?? 'Visitante';

    final List<TextEditingController> homeControllers = [];
    final List<TextEditingController> awayControllers = [];
    final List<String> statuses = [];

    for (final m in matches) {
      homeControllers.add(TextEditingController(text: m['homeScore']?.toString() ?? '0'));
      awayControllers.add(TextEditingController(text: m['awayScore']?.toString() ?? '0'));
      final st = m['status']?.toString() ?? 'finished';
      statuses.add((st == 'finished' || st == 'live' || st == 'scheduled') ? st : 'finished');
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calcular en vivo los puntos de la jornada
            int liveHomePts = 0;
            int liveAwayPts = 0;
            for (int i = 0; i < matches.length; i++) {
              final hG = int.tryParse(homeControllers[i].text.trim()) ?? 0;
              final aG = int.tryParse(awayControllers[i].text.trim()) ?? 0;
              final st = statuses[i];
              if (st != 'scheduled') {
                if (hG > aG) {
                  liveHomePts += 2;
                } else if (hG < aG) {
                  liveAwayPts += 2;
                } else {
                  liveHomePts += 1;
                  liveAwayPts += 1;
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF18181A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Planilla de Jornada',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    '${fixture['name'] ?? 'Fecha'}: $homeName vs $awayName',
                    style: const TextStyle(color: Color(0xFFE5B842), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242427),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Puntos de Jornada: $homeName $liveHomePts - $liveAwayPts $awayName',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Text('(2 pts Victoria)', style: TextStyle(color: Color(0xFFE5B842), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    children: matches.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      final cat = m['category']?.toString() ?? 'Cat. ${i + 1}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222226),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF333338)),
                        ),
                        child: Row(
                          children: [
                            // Categoría
                            SizedBox(
                              width: 75,
                              child: Text(
                                cat.startsWith('20') ? 'Cat. $cat' : cat,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),

                            // Goles Local
                            SizedBox(
                              width: 45,
                              child: TextField(
                                controller: homeControllers[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF2A2A30),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text('-', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                            ),

                            // Goles Visitante
                            SizedBox(
                              width: 45,
                              child: TextField(
                                controller: awayControllers[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF2A2A30),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Selector de Estado
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: statuses[i],
                                    dropdownColor: const Color(0xFF2A2A30),
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                    items: const [
                                      DropdownMenuItem(value: 'finished', child: Text('Finalizado')),
                                      DropdownMenuItem(value: 'live', child: Text('En Vivo')),
                                      DropdownMenuItem(value: 'scheduled', child: Text('Programado')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => statuses[i] = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5B842),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final updatedMatches = List<Map<String, dynamic>>.from(matches);
                    for (int i = 0; i < matches.length; i++) {
                      final hScore = int.tryParse(homeControllers[i].text.trim()) ?? 0;
                      final aScore = int.tryParse(awayControllers[i].text.trim()) ?? 0;
                      updatedMatches[i] = {
                        ...updatedMatches[i],
                        'homeScore': hScore,
                        'awayScore': aScore,
                        'status': statuses[i],
                      };
                    }

                    await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                      'matches': updatedMatches,
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resultados de la jornada guardados exitosamente!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar Todos los Resultados', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Modal: Cargar Resultado Individual de Partido / Categoría ──────────────────────────────────
  void _showSingleMatchResultModal(
    BuildContext context, {
    required Map<String, dynamic> fixture,
    required int matchIndex,
    required Map<String, dynamic>? homeClub,
    required Map<String, dynamic>? awayClub,
    required String category,
  }) {
    final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    final match = matches[matchIndex];

    final homeController = TextEditingController(text: match['homeScore']?.toString() ?? '0');
    final awayController = TextEditingController(text: match['awayScore']?.toString() ?? '0');
    String status = match['status']?.toString() ?? 'finished';
    if (status != 'finished' && status != 'live' && status != 'scheduled') {
      status = 'finished';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF18181A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resultado del Partido', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(category.startsWith('20') ? 'Categoría $category' : category, style: const TextStyle(color: Color(0xFFE5B842), fontSize: 12)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Local
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: context.colors.surfaceLight,
                                backgroundImage: homeClub?['logoUrl'] != null && homeClub!['logoUrl'].isNotEmpty
                                    ? NetworkImage(homeClub['logoUrl'])
                                    : null,
                                child: homeClub?['logoUrl'] == null ? const Icon(Icons.shield) : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                homeClub?['name'] ?? 'Local',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 65,
                                child: TextField(
                                  controller: homeController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF242427),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text('VS', style: TextStyle(color: Color(0xFFE5B842), fontWeight: FontWeight.w900, fontSize: 15)),
                        ),

                        // Visitante
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: context.colors.surfaceLight,
                                backgroundImage: awayClub?['logoUrl'] != null && awayClub!['logoUrl'].isNotEmpty
                                    ? NetworkImage(awayClub['logoUrl'])
                                    : null,
                                child: awayClub?['logoUrl'] == null ? const Icon(Icons.shield) : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                awayClub?['name'] ?? 'Visitante',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 65,
                                child: TextField(
                                  controller: awayController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF242427),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Selector de Estado
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado del Partido', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF242427),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: status,
                              dropdownColor: const Color(0xFF242427),
                              isExpanded: true,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'finished', child: Text('Finalizado')),
                                DropdownMenuItem(value: 'live', child: Text('En Vivo')),
                                DropdownMenuItem(value: 'scheduled', child: Text('Programado')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => status = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5B842),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final hScore = int.tryParse(homeController.text.trim()) ?? 0;
                    final aScore = int.tryParse(awayController.text.trim()) ?? 0;

                    matches[matchIndex] = {
                      ...match,
                      'homeScore': hScore,
                      'awayScore': aScore,
                      'status': status,
                    };

                    await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                      'matches': matches,
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resultado actualizado con éxito!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar Resultado', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Modal: Carga de Goleadores del Partido ──────────────────────────────────
  void _showMatchScorersModal(
    BuildContext context, {
    required Map<String, dynamic> fixture,
    required int matchIndex,
    required Map<String, dynamic>? homeClub,
    required Map<String, dynamic>? awayClub,
    required String category,
  }) {
    final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    final match = Map<String, dynamic>.from(matches[matchIndex]);
    final List<Map<String, dynamic>> matchScorers = List<Map<String, dynamic>>.from(match['scorers'] ?? []);

    final homeName = homeClub?['name'] ?? 'Local';
    final awayName = awayClub?['name'] ?? 'Visitante';

    final allPlayers = ref.watch(playersStreamProvider).valueOrNull ?? [];
    final categoryClean = category.replaceAll('Categoría', '').replaceAll('Cat.', '').trim();
    final categoryPlayers = allPlayers.where((p) {
      final cat = p['category']?.toString().trim();
      return cat == categoryClean || cat == category;
    }).toList();
    categoryPlayers.sort((a, b) => _getPlayerName(a).toLowerCase().compareTo(_getPlayerName(b).toLowerCase()));

    String selectedTeam = homeName;
    final nameController = TextEditingController();
    final goalsController = TextEditingController(text: '1');
    String? selectedPlayerId;
    bool manualNameInput = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isLocalSelected = selectedTeam == homeName || selectedTeam.toLowerCase().contains('newbery');

            return AlertDialog(
              backgroundColor: const Color(0xFF18181A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.emoji_events_outlined, color: Color(0xFFE5B842), size: 22),
                      SizedBox(width: 8),
                      Text('Goleadores', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$homeName vs $awayName (${category.startsWith('20') ? 'Cat. $category' : category})',
                      style: const TextStyle(color: Color(0xFFE5B842), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    if (matchScorers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242427),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No se han registrado goleadores en este partido.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Column(
                        children: matchScorers.asMap().entries.map((entry) {
                          final scIdx = entry.key;
                          final sc = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242427),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sports_soccer, size: 14, color: Color(0xFFE5B842)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sc['name']?.toString() ?? '',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        '${sc['team']} · ${sc['goals']} ${sc['goals'] == 1 ? 'gol' : 'goles'}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () {
                                    setModalState(() {
                                      matchScorers.removeAt(scIdx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF333338)),
                    const SizedBox(height: 10),

                    const Text(
                      'Agregar Goleador al Partido',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Selector de Equipo
                    const Text('Equipo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242427),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTeam,
                          dropdownColor: const Color(0xFF242427),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: [
                            DropdownMenuItem(value: homeName, child: Text(homeName)),
                            DropdownMenuItem(value: awayName, child: Text(awayName)),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedTeam = val;
                                selectedPlayerId = null;
                                nameController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Selector de Jugadores de la Categoría (para Club Local) o TextField
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isLocalSelected ? 'Jugador (Cat. $categoryClean)' : 'Nombre del Jugador',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  if (isLocalSelected && manualNameInput)
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          manualNameInput = false;
                                          nameController.clear();
                                        });
                                      },
                                      child: const Text('📋 Usar lista', style: TextStyle(color: Color(0xFFE5B842), fontSize: 11)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              if (isLocalSelected && !manualNameInput && categoryPlayers.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF242427),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF333338)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: categoryPlayers.any((p) => p['id'] == selectedPlayerId) ? selectedPlayerId : null,
                                      hint: const Text('Seleccionar Jugador...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      dropdownColor: const Color(0xFF242427),
                                      isExpanded: true,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: [
                                        ...categoryPlayers.map((p) {
                                          final pName = _getPlayerName(p);
                                          return DropdownMenuItem<String>(
                                            value: p['id'] as String,
                                            child: Text(pName, overflow: TextOverflow.ellipsis),
                                          );
                                        }),
                                        const DropdownMenuItem<String>(
                                          value: 'MANUAL',
                                          child: Text('✍️ Escribir otro nombre...', style: TextStyle(color: Color(0xFFE5B842))),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val == 'MANUAL') {
                                          setModalState(() {
                                            selectedPlayerId = null;
                                            manualNameInput = true;
                                            nameController.clear();
                                          });
                                        } else if (val != null) {
                                          final sel = categoryPlayers.firstWhere((p) => p['id'] == val);
                                          setModalState(() {
                                            selectedPlayerId = val;
                                            nameController.text = _getPlayerName(sel);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                )
                              else
                                TextField(
                                  controller: nameController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: isLocalSelected ? 'Ej: Nombre del jugador' : 'Ej: Jugador Rival',
                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                    filled: true,
                                    fillColor: const Color(0xFF242427),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Goles', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: goalsController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF242427),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE5B842),
                        side: const BorderSide(color: Color(0xFFE5B842)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Añadir a la lista'),
                      onPressed: () {
                        final pName = nameController.text.trim();
                        final gCount = int.tryParse(goalsController.text.trim()) ?? 1;
                        if (pName.isNotEmpty && gCount > 0) {
                          setModalState(() {
                            matchScorers.add({
                              'name': pName,
                              'team': selectedTeam,
                              'goals': gCount,
                              'isClub': selectedTeam.toLowerCase().contains('newbery'),
                            });
                            nameController.clear();
                            goalsController.text = '1';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5B842),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    matches[matchIndex] = {
                      ...match,
                      'scorers': matchScorers,
                    };

                    await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                      'matches': matches,
                    });

                    for (final sc in matchScorers) {
                      final effectiveCategory = (category == 'all' || category.isEmpty) ? 'Primera' : category;
                      await ref.read(firestoreServiceProvider).addScorer({
                        'name': sc['name'],
                        'team': sc['team'],
                        'category': effectiveCategory,
                        'goals': sc['goals'] ?? 1,
                        'isClub': sc['isClub'] ?? false,
                      });
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Goleadores del partido guardados correctamente!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar Goleadores', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── 2. Posiciones Tab (Calculada en Vivo con 2 pts victoria / 1 pt empate) ──────────────────────────────────
  Widget _buildStandingsTab() {
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);

    final fixtures = fixturesAsync.valueOrNull ?? [];
    final clubs = clubsAsync.valueOrNull ?? [];

    final Map<String, Map<String, dynamic>> standingsMap = {};

    for (final c in clubs) {
      final name = c['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      standingsMap[name] = {
        'team': name,
        'logoUrl': c['logoUrl'],
        'isClub': name.toLowerCase().contains('newbery'),
        'played': 0,
        'won': 0,
        'drawn': 0,
        'lost': 0,
        'gf': 0,
        'gc': 0,
        'gd': 0,
        'points': 0,
      };
    }

    for (final f in fixtures) {
      final matches = List<Map<String, dynamic>>.from(f['matches'] ?? []);
      for (final m in matches) {
        // Filtrar por categoría si no está seleccionada 'all'
        if (_selectedCategory != 'all') {
          final cat = m['category']?.toString();
          if (cat != null && cat != _selectedCategory) {
            continue;
          }
        }

        final homeClub = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
        final awayClub = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;

        final homeName = homeClub?['name']?.toString() ?? 'Local';
        final awayName = awayClub?['name']?.toString() ?? 'Visitante';

        final status = m['status']?.toString() ?? '';
        final hScore = m['homeScore'] != null ? int.tryParse(m['homeScore'].toString()) : null;
        final aScore = m['awayScore'] != null ? int.tryParse(m['awayScore'].toString()) : null;

        if (hScore != null && aScore != null && status != 'scheduled') {
          if (!standingsMap.containsKey(homeName)) {
            standingsMap[homeName] = {
              'team': homeName,
              'logoUrl': homeClub?['logoUrl'],
              'isClub': homeName.toLowerCase().contains('newbery'),
              'played': 0,
              'won': 0,
              'drawn': 0,
              'lost': 0,
              'gf': 0,
              'gc': 0,
              'gd': 0,
              'points': 0,
            };
          }
          if (!standingsMap.containsKey(awayName)) {
            standingsMap[awayName] = {
              'team': awayName,
              'logoUrl': awayClub?['logoUrl'],
              'isClub': awayName.toLowerCase().contains('newbery'),
              'played': 0,
              'won': 0,
              'drawn': 0,
              'lost': 0,
              'gf': 0,
              'gc': 0,
              'gd': 0,
              'points': 0,
            };
          }

          final homeStat = standingsMap[homeName]!;
          final awayStat = standingsMap[awayName]!;

          homeStat['played'] = (homeStat['played'] as int) + 1;
          awayStat['played'] = (awayStat['played'] as int) + 1;

          homeStat['gf'] = (homeStat['gf'] as int) + hScore;
          homeStat['gc'] = (homeStat['gc'] as int) + aScore;
          homeStat['gd'] = (homeStat['gf'] as int) - (homeStat['gc'] as int);

          awayStat['gf'] = (awayStat['gf'] as int) + aScore;
          awayStat['gc'] = (awayStat['gc'] as int) + hScore;
          awayStat['gd'] = (awayStat['gf'] as int) - (awayStat['gc'] as int);

          // REGLA DE TORNEO: 2 puntos por victoria, 1 por empate, 0 por derrota
          if (hScore > aScore) {
            homeStat['won'] = (homeStat['won'] as int) + 1;
            homeStat['points'] = (homeStat['points'] as int) + 2;
            awayStat['lost'] = (awayStat['lost'] as int) + 1;
          } else if (hScore < aScore) {
            awayStat['won'] = (awayStat['won'] as int) + 1;
            awayStat['points'] = (awayStat['points'] as int) + 2;
            homeStat['lost'] = (homeStat['lost'] as int) + 1;
          } else {
            homeStat['drawn'] = (homeStat['drawn'] as int) + 1;
            homeStat['points'] = (homeStat['points'] as int) + 1;
            awayStat['drawn'] = (awayStat['drawn'] as int) + 1;
            awayStat['points'] = (awayStat['points'] as int) + 1;
          }
        }
      }
    }

    final standings = standingsMap.values.toList();
    standings.sort((a, b) {
      final pA = a['points'] as int;
      final pB = b['points'] as int;
      if (pA != pB) return pB.compareTo(pA);

      final gdA = a['gd'] as int;
      final gdB = b['gd'] as int;
      if (gdA != gdB) return gdB.compareTo(gdA);

      final gfA = a['gf'] as int;
      final gfB = b['gf'] as int;
      if (gfA != gfB) return gfB.compareTo(gfA);

      final wA = a['won'] as int;
      final wB = b['won'] as int;
      return wB.compareTo(wA);
    });

    for (int i = 0; i < standings.length; i++) {
      standings[i]['pos'] = i + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Info Banner Puntos
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategory == 'all'
                    ? 'Tabla General de Clubes (Suma de Jornadas)'
                    : 'Tabla de Posiciones · Categoría $_selectedCategory',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const Text('PG = 2 pts · PE = 1 pt', style: TextStyle(fontSize: 10, color: Color(0xFFE5B842), fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // Table Header
        JNCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          color: context.colors.surfaceVariant,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('#', style: context.typography.labelSmall, textAlign: TextAlign.center),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text('EQUIPO', style: context.typography.labelSmall)),
              SizedBox(
                width: 24,
                child: Text('PJ', style: context.typography.labelSmall, textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 24,
                child: Text('G', style: context.typography.labelSmall, textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 24,
                child: Text('E', style: context.typography.labelSmall, textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 24,
                child: Text('P', style: context.typography.labelSmall, textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 28,
                child: Text('DG', style: context.typography.labelSmall, textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  'PTS',
                  style: context.typography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: context.colors.accent),
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
                  Icon(Icons.format_list_numbered, size: 48, color: context.colors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay posiciones registradas',
                    style: context.typography.titleMedium.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

        ...standings.asMap().entries.map((entry) {
          final index = entry.key;
          final team = entry.value;
          final isClub = team['isClub'] as bool;
          final logoUrl = team['logoUrl']?.toString();

          return JNCard(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: isClub ? context.colors.primary.withValues(alpha: 0.1) : null,
            border: isClub
                ? Border.all(color: context.colors.primary.withValues(alpha: 0.35))
                : Border.all(color: Colors.transparent),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: index < 2
                          ? context.colors.success.withValues(alpha: 0.2)
                          : (index >= standings.length - 2 && standings.length > 4
                              ? context.colors.error.withValues(alpha: 0.2)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${team['pos']}',
                        style: context.typography.labelMedium.copyWith(
                          color: index < 2
                              ? context.colors.success
                              : (index >= standings.length - 2 && standings.length > 4
                                  ? context.colors.error
                                  : context.colors.textSecondary),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                Expanded(
                  child: Row(
                    children: [
                      if (logoUrl != null && logoUrl.isNotEmpty) ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.transparent,
                          backgroundImage: NetworkImage(logoUrl),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          team['team'] as String,
                          style: context.typography.titleSmall.copyWith(
                            color: isClub ? context.colors.textPrimary : context.colors.textSecondary,
                            fontWeight: isClub ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  width: 24,
                  child: Text('${team['played']}', style: context.typography.bodySmall, textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 24,
                  child: Text('${team['won']}', style: context.typography.bodySmall, textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 24,
                  child: Text('${team['drawn']}', style: context.typography.bodySmall, textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 24,
                  child: Text('${team['lost']}', style: context.typography.bodySmall, textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${(team['gd'] as int) > 0 ? '+' : ''}${team['gd']}',
                    style: context.typography.bodySmall.copyWith(
                      color: (team['gd'] as int) > 0
                          ? context.colors.success
                          : ((team['gd'] as int) < 0 ? context.colors.error : context.colors.textTertiary),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${team['points']}',
                    style: context.typography.titleMedium.copyWith(
                      color: isClub ? context.colors.accent : context.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ).animate(delay: (60 + index * 30).ms).fadeIn(duration: 300.ms);
        }),
      ],
    );
  }

  // ─── 3. Goleadores Tab ──────────────────────────────────
  Widget _buildScorersTab(bool canManage) {
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
                  Icon(Icons.sports_soccer, size: 48, color: context.colors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay goleadores registrados en esta categoría',
                    style: context.typography.titleMedium.copyWith(color: context.colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Goleadores'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManageScorersScreen()),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: scorers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final scorer = scorers[index];
            final isClub = scorer['isClub'] == true;
            final isTop3 = index < 3;

            return JNCard(
              padding: const EdgeInsets.all(14),
              color: isClub ? context.colors.primary.withValues(alpha: 0.08) : null,
              border: isClub ? Border.all(color: context.colors.primary.withValues(alpha: 0.25)) : null,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isTop3
                          ? (index == 0
                              ? const Color(0xFFFFD700)
                              : index == 1
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFCD7F32)).withValues(alpha: 0.2)
                          : context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: context.typography.titleMedium.copyWith(
                          color: isTop3
                              ? (index == 0
                                  ? const Color(0xFFFFD700)
                                  : index == 1
                                      ? const Color(0xFFE0E0E0)
                                      : const Color(0xFFCD7F32))
                              : context.colors.textTertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scorer['name'] as String? ?? '',
                          style: context.typography.titleMedium.copyWith(
                            color: isClub ? context.colors.textPrimary : context.colors.textSecondary,
                            fontWeight: isClub ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        Text(
                          scorer['team'] as String? ?? 'Club',
                          style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isClub ? context.colors.primary.withValues(alpha: 0.15) : context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 16,
                          color: isClub ? context.colors.primary : context.colors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${scorer['goals'] ?? 0}',
                          style: context.typography.titleLarge.copyWith(
                            color: isClub ? context.colors.primary : context.colors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: (index * 40).ms).fadeIn(duration: 300.ms).slideX(begin: 0.02);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: context.colors.error))),
    );
  }

  String _getPlayerName(Map<String, dynamic> p) {
    final name = p['name']?.toString() ?? p['displayName']?.toString() ?? p['fullName']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    final fn = p['firstName']?.toString() ?? '';
    final ln = p['lastName']?.toString() ?? '';
    if (fn.isNotEmpty || ln.isNotEmpty) return '$fn $ln'.trim();
    return 'Jugador sin nombre';
  }
}