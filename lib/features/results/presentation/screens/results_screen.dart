import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import '../utils/league_jornada_utils.dart';
import 'manage_scorers_screen.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado de Planilla UCIV
  String _sheetTournamentFilter = 'apertura'; // 'apertura' | 'clausura'
  String? _selectedJornadaId;

  // Estado de Tabla de Posiciones
  String _standingsTournament = 'apertura'; // 'apertura' | 'clausura' (sin anual)
  String _standingsCategory = 'all';

  // Estado de Fixture y Goleadores
  String _selectedCategory = 'all';
  String? _lastChildId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final bool isPlayer = sessionUser?.role == 'jugador';
    final String? playerCategory = sessionUser?.category;

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
    } else if (isPlayer) {
      if (playerCategory != null && playerCategory.isNotEmpty) {
        categories = [playerCategory];
        _selectedCategory = playerCategory;
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

    final bool isAdmin = sessionUser?.isAdmin == true;
    final bool canManage = isAdmin || sessionUser?.role == 'dt' || sessionUser?.isCoach == true;

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
          indicatorColor: const Color(0xFFC1121F),
          labelColor: const Color(0xFFE63946),
          unselectedLabelColor: context.colors.textSecondary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Planilla UCIV'),
            Tab(text: 'Posiciones'),
            Tab(text: 'Nuestras Fechas'),
            Tab(text: 'Goleadores'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeagueJornadaSheetTab(),
          _buildStandingsTab(),
          Column(
            children: [
              _buildCategorySelector(categories, isPlayer: isPlayer, playerCategory: playerCategory),
              Expanded(child: _buildFixtureTab(canManage, isAdmin)),
            ],
          ),
          Column(
            children: [
              _buildCategorySelector(categories, isPlayer: isPlayer, playerCategory: playerCategory),
              Expanded(child: _buildScorersTab(canManage)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(List<String> categories, {bool isPlayer = false, String? playerCategory}) {
    if (isPlayer && playerCategory != null && playerCategory.isNotEmpty) {
      return Container(
        color: context.colors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.sports_soccer, color: context.colors.primary, size: 20),
            const SizedBox(width: 10),
            Text('Mi Categoría:', style: context.typography.labelMedium.copyWith(color: context.colors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Categoría $playerCategory',
                style: context.typography.labelMedium.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
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

  Map<String, dynamic>? _findClub(List<Map<String, dynamic>> clubs, dynamic clubIdOrName) {
    if (clubIdOrName == null) return null;
    final str = clubIdOrName.toString().trim().toLowerCase();
    if (str.isEmpty) return null;
    return clubs.where((c) {
      final cId = c['id']?.toString().trim().toLowerCase();
      final cName = c['name']?.toString().trim().toLowerCase();
      final cShort = c['shortName']?.toString().trim().toLowerCase();
      return cId == str || cName == str || (cShort != null && cShort == str);
    }).firstOrNull;
  }

  // ─── 1. Fixture & Resultados Tab (Jornadas y 10 Categorías) ──────────────────────────────────
  Widget _buildFixtureTab(bool canManage, bool isAdmin) {
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
                    'No hay fechas cargadas en Nuestras Fechas',
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
              homeClubId ??= m['homeClubId']?.toString() ?? m['homeTeam']?.toString();
              awayClubId ??= m['awayClubId']?.toString() ?? m['awayTeam']?.toString();

              final hScore = m['homeScore'] != null ? int.tryParse(m['homeScore'].toString()) : null;
              final aScore = m['awayScore'] != null ? int.tryParse(m['awayScore'].toString()) : null;
              final status = m['status']?.toString() ?? '';

              if (hScore != null && aScore != null && status != 'scheduled' && status != 'suspended') {
                playedCount++;
                final isPromo = m['isPromotional'] == true;
                if (!isPromo) {
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
            }

            final homeClub = _findClub(clubs, homeClubId);
            final awayClub = _findClub(clubs, awayClubId);
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

                        // Botón de Cargar Jornada Completa (Solo Admin)
                        if (isAdmin && allMatches.isNotEmpty)
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
                        color: context.colors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          // Local
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                _buildClubSmallAvatar(homeClub),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    homeName,
                                    style: context.typography.titleSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Marcador Puntos Central
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$homeTotalPts pts',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.accent,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.textTertiary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$awayTotalPts pts',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Visitante
                          Expanded(
                            flex: 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    awayName,
                                    style: context.typography.titleSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
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
                    Text(
                      'Puntos de Jornada: $playedCount/${allMatches.length} partidos jugados (2 pts Victoria · 1 pt Empate)',
                      style: TextStyle(fontSize: 10, color: context.colors.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 14),

                    // ─── Lista de Partidos de las Categorías ───
                    ...displayedMatches.asMap().entries.map((entry) {
                      final match = entry.value;
                      int matchIndexInAll = allMatches.indexOf(match);
                      if (matchIndexInAll == -1) {
                        matchIndexInAll = allMatches.indexWhere((m) {
                          final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                          final tCat = (match['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                          return (mCat == tCat || m['category'] == match['category']) &&
                              m['homeClubId'] == match['homeClubId'] &&
                              m['awayClubId'] == match['awayClubId'];
                        });
                      }
                      final mHomeClub = _findClub(clubs, match['homeClubId'] ?? match['homeTeam'] ?? match['homeClub']) ?? homeClub;
                      final mAwayClub = _findClub(clubs, match['awayClubId'] ?? match['awayTeam'] ?? match['awayClub']) ?? awayClub;

                      final catLabel = match['category']?.toString() ?? 'Cat. General';
                      final status = match['status']?.toString() ?? 'scheduled';
                      final bool isFinished = status == 'finished' || status == 'finalizado';
                      final bool isLive = status == 'live' || status == 'en vivo';
                      final int? homeScore = match['homeScore'] != null ? int.tryParse(match['homeScore'].toString()) : null;
                      final int? awayScore = match['awayScore'] != null ? int.tryParse(match['awayScore'].toString()) : null;
                      final bool hasScores = homeScore != null && awayScore != null;

                      final List<dynamic> rawScorers = (match['scorers'] as List?) ?? [];
                      final List<dynamic> rawCards = (match['cards'] as List?) ?? [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLive
                                ? context.colors.error.withValues(alpha: 0.6)
                                : context.colors.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Categoría y Horario ───
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                    if (match['isPromotional'] == true) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 0.5),
                                        ),
                                        child: const Text(
                                          'PROMOCIONAL',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (match['time'] != null && match['time'].toString().isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 12, color: context.colors.textTertiary),
                                      const SizedBox(width: 3),
                                      Text(
                                        match['time'].toString(),
                                        style: TextStyle(fontSize: 11, color: context.colors.textTertiary, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // ─── Fila de Equipos y Marcador ───
                            Row(
                              children: [
                                // Local
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          mHomeClub?['name'] ?? 'Local',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildClubSmallAvatar(mHomeClub),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Marcador
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: status == 'suspended'
                                          ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                                          : (isLive ? context.colors.error.withValues(alpha: 0.5) : context.colors.border.withValues(alpha: 0.4)),
                                    ),
                                  ),
                                  child: status == 'suspended'
                                      ? const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.thunderstorm, size: 12, color: Color(0xFF38BDF8)),
                                            SizedBox(width: 4),
                                            Text(
                                              'SUSPENDIDO',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                                            ),
                                          ],
                                        )
                                      : (hasScores || isFinished || isLive
                                          ? Text(
                                              '${homeScore ?? 0} - ${awayScore ?? 0}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: isLive ? context.colors.error : context.colors.textPrimary,
                                              ),
                                            )
                                          : Text(
                                              'VS',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.accent),
                                            )),
                                ),
                                const SizedBox(width: 8),

                                // Visitante
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      _buildClubSmallAvatar(mAwayClub),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          mAwayClub?['name'] ?? 'Visitante',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // ─── Goleadores del partido ───
                            if (rawScorers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: rawScorers.map((sc) {
                                  final scMap = sc is Map ? Map<String, dynamic>.from(sc) : <String, dynamic>{};
                                  if (scMap.isEmpty) return const SizedBox.shrink();
                                  final isLight = Theme.of(context).brightness == Brightness.light;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF27272A),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isLight ? const Color(0xFFCBD5E1) : const Color(0xFF3F3F46),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sports_soccer,
                                          size: 12,
                                          color: isLight ? const Color(0xFFC1121F) : const Color(0xFFE63946),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${scMap['name']} (${scMap['goals'] ?? 1})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            // ─── Tarjetas del partido ───
                            if (rawCards.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: rawCards.map((c) {
                                  final cMap = c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{};
                                  if (cMap.isEmpty) return const SizedBox.shrink();
                                  final isRed = cMap['cardType']?.toString() == 'red';
                                  final isLight = Theme.of(context).brightness == Brightness.light;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? (isRed ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7))
                                          : (isRed ? context.colors.error.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isLight
                                            ? (isRed ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D))
                                            : (isRed ? context.colors.error.withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.square_rounded,
                                          size: 12,
                                          color: isRed
                                              ? (isLight ? const Color(0xFFDC2626) : context.colors.error)
                                              : (isLight ? const Color(0xFFD97706) : Colors.amber),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          cMap['name']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 10),

                            // ─── Fila de Estado y Botones de Acción Responsiva ───
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
                                  Flexible(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
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
                                          const SizedBox(width: 5),

                                          // Botón Tarjetas
                                          InkWell(
                                            onTap: () => _showMatchCardsModal(
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
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.square_rounded, size: 13, color: Colors.amber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Tarjetas',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Botón Resultado (Solo Admin)
                                          if (isAdmin) ...[
                                            const SizedBox(width: 5),
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
                                                  border: Border.all(color: context.colors.accent.withValues(alpha: 0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 12, color: context.colors.accent),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      hasScores ? 'Editar Goles' : 'Resultado',
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
                                        ],
                                      ),
                                    ),
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
    final logoUrl = extractClubLogo(club);
    final name = club?['name']?.toString() ?? '';
    final isLocal = club?['isLocal'] == true ||
        name.toLowerCase().contains('newbery') ||
        name.toLowerCase().contains('jn');

    if (isLocal) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC1121F), width: 1.2),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/app_logo.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.shield, size: 12, color: Color(0xFFE63946)),
            ),
          ),
        ),
      );
    }

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
        ),
        child: ClipOval(
          child: Image.network(
            logoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackInitial(name),
          ),
        ),
      );
    }

    return _buildFallbackInitial(name);
  }

  Widget _buildFallbackInitial(String name) {
    final clean = name.trim();
    final initial = clean.isNotEmpty ? clean[0].toUpperCase() : 'C';
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC1121F).withValues(alpha: 0.6), width: 0.8),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE63946),
          ),
        ),
      ),
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
    final List<bool> isPromoList = [];

    for (final m in matches) {
      homeControllers.add(TextEditingController(text: m['homeScore']?.toString() ?? '0'));
      awayControllers.add(TextEditingController(text: m['awayScore']?.toString() ?? '0'));
      final st = m['status']?.toString() ?? 'finished';
      statuses.add((st == 'finished' || st == 'live' || st == 'scheduled') ? st : 'finished');
      isPromoList.add(m['isPromotional'] == true);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calcular en vivo los puntos de la jornada (excluyendo promocionales)
            int liveHomePts = 0;
            int liveAwayPts = 0;
            for (int i = 0; i < matches.length; i++) {
              if (isPromoList[i]) continue; // Los partidos promocionales no suman puntos
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fixture['name'] ?? 'Fecha'}: $homeName vs $awayName',
                    style: const TextStyle(color: Color(0xFFE63946), fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242427),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF333338)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Puntos de Jornada: $liveHomePts - $liveAwayPts',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$homeName ($liveHomePts pts) · $awayName ($liveAwayPts pts)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '2 pts Victoria · 1 pt Empate (Promocionales no suman)',
                          style: TextStyle(color: Color(0xFFE63946), fontSize: 10, fontWeight: FontWeight.w500),
                        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222226),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF333338)),
                        ),
                        child: Row(
                          children: [
                            // Categoría y Chip Promo
                            SizedBox(
                              width: 76,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat.startsWith('20') ? 'Cat. $cat' : cat,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        isPromoList[i] = !isPromoList[i];
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isPromoList[i] ? Colors.orange.withValues(alpha: 0.2) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isPromoList[i] ? Colors.orange : Colors.white24,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        isPromoList[i] ? '★ PROMO' : '+ Promo',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: isPromoList[i] ? Colors.orange : Colors.white38,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Goles Local
                            SizedBox(
                              width: 38,
                              child: TextField(
                                controller: homeControllers[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF2A2A30),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text('-', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                            ),

                            // Goles Visitante
                            SizedBox(
                              width: 38,
                              child: TextField(
                                controller: awayControllers[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF2A2A30),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Selector de Estado
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: statuses[i],
                                    dropdownColor: const Color(0xFF2A2A30),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    items: const [
                                      DropdownMenuItem(value: 'finished', child: Text('Finalizado', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'live', child: Text('En Vivo', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'scheduled', child: Text('Programado', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'suspended', child: Text('Suspendido', overflow: TextOverflow.ellipsis)),
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
                    backgroundColor: const Color(0xFFC1121F),
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
                        'isPromotional': isPromoList[i],
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
                  child: const Text('Guardar Todos los Resultados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    int exactMatchIndex = -1;
    final targetCat = category.replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
    exactMatchIndex = matches.indexWhere((m) {
      final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
      return (mCat == targetCat || m['category'] == category) &&
          (homeClub == null || m['homeClubId'] == homeClub['id']) &&
          (awayClub == null || m['awayClubId'] == awayClub['id']);
    });
    if (exactMatchIndex == -1) {
      exactMatchIndex = (matchIndex >= 0 && matchIndex < matches.length) ? matchIndex : 0;
    }
    final match = Map<String, dynamic>.from(matches.isNotEmpty ? matches[exactMatchIndex] : {});

    final homeController = TextEditingController(text: match['homeScore']?.toString() ?? '0');
    final awayController = TextEditingController(text: match['awayScore']?.toString() ?? '0');
    String status = match['status']?.toString() ?? 'finished';
    if (status != 'finished' && status != 'live' && status != 'scheduled') {
      status = 'finished';
    }
    bool isPromotional = match['isPromotional'] == true;

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
                      Text(category.startsWith('20') ? 'Categoría $category' : category, style: const TextStyle(color: Color(0xFFE63946), fontSize: 12)),
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
                          child: Text('VS', style: TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.w900, fontSize: 15)),
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

                    const SizedBox(height: 12),

                    // Switch de Promocional
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242427),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Categoría Promocional', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('No computa puntos para la tabla de posiciones', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        value: isPromotional,
                        activeThumbColor: const Color(0xFFE63946),
                        trackColor: WidgetStateProperty.resolveWith((states) => isPromotional ? const Color(0xFFC1121F).withValues(alpha: 0.5) : const Color(0xFF333338)),
                        onChanged: (val) {
                          setDialogState(() => isPromotional = val);
                        },
                      ),
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
                    backgroundColor: const Color(0xFFC1121F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final hScore = int.tryParse(homeController.text.trim()) ?? 0;
                    final aScore = int.tryParse(awayController.text.trim()) ?? 0;

                    final currentMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
                    int saveIndex = currentMatches.indexWhere((m) {
                      final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                      final tCat = (match['category']?.toString() ?? category).replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                      final bool catMatch = mCat == tCat || m['category'] == match['category'] || m['category'] == category;
                      final bool homeMatch = m['homeClubId'] == match['homeClubId'] || (m['homeClubId'] == null && match['homeClubId'] == null);
                      final bool awayMatch = m['awayClubId'] == match['awayClubId'] || (m['awayClubId'] == null && match['awayClubId'] == null);
                      return catMatch && homeMatch && awayMatch;
                    });
                    if (saveIndex == -1) {
                      saveIndex = (exactMatchIndex >= 0 && exactMatchIndex < currentMatches.length) ? exactMatchIndex : 0;
                    }

                    currentMatches[saveIndex] = {
                      ...currentMatches[saveIndex],
                      'homeScore': hScore,
                      'awayScore': aScore,
                      'status': status,
                      'isPromotional': isPromotional,
                    };

                    await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                      'matches': currentMatches,
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
    int exactMatchIndex = -1;
    final targetCat = category.replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
    exactMatchIndex = matches.indexWhere((m) {
      final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
      return (mCat == targetCat || m['category'] == category) &&
          (homeClub == null || m['homeClubId'] == homeClub['id']) &&
          (awayClub == null || m['awayClubId'] == awayClub['id']);
    });
    if (exactMatchIndex == -1) {
      exactMatchIndex = (matchIndex >= 0 && matchIndex < matches.length) ? matchIndex : 0;
    }
    final match = Map<String, dynamic>.from(matches.isNotEmpty ? matches[exactMatchIndex] : {});
    final List<Map<String, dynamic>> matchScorers = (match['scorers'] as List?)
        ?.map((sc) => sc is Map ? Map<String, dynamic>.from(sc) : <String, dynamic>{})
        .where((sc) => sc.isNotEmpty)
        .toList() ?? [];

    final homeName = homeClub?['name'] ?? 'Local';
    final awayName = awayClub?['name'] ?? 'Visitante';

    String selectedTeam = homeName;
    final nameController = TextEditingController();
    final goalsController = TextEditingController(text: '1');
    String? selectedPlayerId;
    bool manualNameInput = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final allPlayers = ref.watch(playersStreamProvider).valueOrNull ?? [];
            final categoryClean = category
                .replaceAll('Categoría', '')
                .replaceAll('Cat.', '')
                .replaceAll('Cat', '')
                .trim()
                .toLowerCase();

            final categoryPlayers = allPlayers.where((p) {
              final cat = (p['category']?.toString() ?? '')
                  .replaceAll('Categoría', '')
                  .replaceAll('Cat.', '')
                  .replaceAll('Cat', '')
                  .trim()
                  .toLowerCase();
              return cat == categoryClean;
            }).toList();
            categoryPlayers.sort((a, b) => _getPlayerName(a).toLowerCase().compareTo(_getPlayerName(b).toLowerCase()));

            return StatefulBuilder(
              builder: (context, setModalState) {
                final bool isLocalSelected = selectedTeam == homeName ||
                    selectedTeam.toLowerCase().contains('newbery') ||
                    (homeClub != null && selectedTeam == homeClub['name']);

                return AlertDialog(
                  backgroundColor: const Color(0xFF18181A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.emoji_events_outlined, color: Color(0xFFE63946), size: 22),
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
                          style: const TextStyle(color: Color(0xFFE63946), fontSize: 13, fontWeight: FontWeight.w600),
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
                              final currentGoals = (sc['goals'] as num?)?.toInt() ?? 1;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF242427),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.sports_soccer, size: 16, color: Color(0xFFE63946)),
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
                                            sc['team']?.toString() ?? '',
                                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Controles de goles (+ / -)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              if (currentGoals > 1) {
                                                matchScorers[scIdx]['goals'] = currentGoals - 1;
                                              } else {
                                                matchScorers.removeAt(scIdx);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF333338),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.remove, size: 14, color: Colors.white70),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text(
                                            '$currentGoals ${currentGoals == 1 ? 'gol' : 'goles'}',
                                            style: const TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              matchScorers[scIdx]['goals'] = currentGoals + 1;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF333338),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.add, size: 14, color: Color(0xFFE63946)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setModalState(() {
                                              matchScorers.removeAt(scIdx);
                                            });
                                          },
                                        ),
                                      ],
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

                        // Selector de Jugadores o TextField
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
                                          child: const Text('📋 Usar lista', style: TextStyle(color: Color(0xFFE63946), fontSize: 11)),
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
                                                child: Text(
                                                  pName,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              );
                                            }),
                                            const DropdownMenuItem<String>(
                                              value: 'MANUAL',
                                              child: Text('✍️ Escribir otro nombre...', style: TextStyle(color: Color(0xFFE63946))),
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
                                              final pName = _getPlayerName(sel);
                                              setModalState(() {
                                                selectedPlayerId = val;
                                                nameController.text = pName;
                                                final existingIdx = matchScorers.indexWhere((sc) => sc['playerId'] == val || sc['name'] == pName);
                                                if (existingIdx == -1) {
                                                  matchScorers.add({
                                                    'name': pName,
                                                    'playerId': val,
                                                    'team': selectedTeam,
                                                    'goals': 1,
                                                    'isClub': isLocalSelected,
                                                  });
                                                }
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
                            foregroundColor: const Color(0xFFE63946),
                            side: const BorderSide(color: Color(0xFFC1121F)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Añadir a la lista'),
                          onPressed: () {
                            final pName = nameController.text.trim();
                            final gCount = int.tryParse(goalsController.text.trim()) ?? 1;
                            if (pName.isNotEmpty && gCount > 0) {
                              setModalState(() {
                                final existingIdx = matchScorers.indexWhere((sc) => sc['name']?.toString().toLowerCase() == pName.toLowerCase() && sc['team'] == selectedTeam);
                                if (existingIdx != -1) {
                                  matchScorers[existingIdx]['goals'] = gCount;
                                } else {
                                  matchScorers.add({
                                    'name': pName,
                                    'playerId': selectedPlayerId,
                                    'team': selectedTeam,
                                    'goals': gCount,
                                    'isClub': isLocalSelected,
                                  });
                                }
                                nameController.clear();
                                goalsController.text = '1';
                                selectedPlayerId = null;
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
                        backgroundColor: const Color(0xFFC1121F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        // Auto-incluir si hay un jugador escrito/seleccionado que no se añadió manualmente con el botón
                        final currentName = nameController.text.trim();
                        final currentGoals = int.tryParse(goalsController.text.trim()) ?? 1;
                        if (currentName.isNotEmpty && currentGoals > 0) {
                          final existingIdx = matchScorers.indexWhere((sc) => sc['name']?.toString().toLowerCase() == currentName.toLowerCase() && sc['team'] == selectedTeam);
                          if (existingIdx == -1) {
                            matchScorers.add({
                              'name': currentName,
                              'playerId': selectedPlayerId,
                              'team': selectedTeam,
                              'goals': currentGoals,
                              'isClub': isLocalSelected,
                            });
                          }
                        }

                        final currentMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
                        int saveIndex = currentMatches.indexWhere((m) {
                          final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                          final tCat = (match['category']?.toString() ?? category).replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                          final bool catMatch = mCat == tCat || m['category'] == match['category'] || m['category'] == category;
                          final bool homeMatch = m['homeClubId'] == match['homeClubId'] || (m['homeClubId'] == null && match['homeClubId'] == null);
                          final bool awayMatch = m['awayClubId'] == match['awayClubId'] || (m['awayClubId'] == null && match['awayClubId'] == null);
                          return catMatch && homeMatch && awayMatch;
                        });
                        if (saveIndex == -1) {
                          saveIndex = (exactMatchIndex >= 0 && exactMatchIndex < currentMatches.length) ? exactMatchIndex : 0;
                        }

                        currentMatches[saveIndex] = {
                          ...currentMatches[saveIndex],
                          'scorers': matchScorers,
                        };

                        await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                          'matches': currentMatches,
                        });

                        for (final sc in matchScorers) {
                          final effectiveCategory = (category == 'all' || category.isEmpty)
                              ? (match['category']?.toString() ?? 'Primera')
                              : category;

                          final pId = sc['playerId']?.toString();
                          final String docId = '${fixture['id']}_${saveIndex}_${pId ?? sc['name']}'.replaceAll(' ', '_');

                          await FirebaseFirestore.instance.collection('scorers').doc(docId).set({
                            'name': sc['name'],
                            'playerId': sc['playerId'],
                            'team': sc['team'],
                            'category': effectiveCategory,
                            'goals': sc['goals'] ?? 1,
                            'isClub': sc['isClub'] ?? isLocalSelected,
                            'fixtureId': fixture['id'],
                            'matchIndex': saveIndex,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (pId != null && pId.isNotEmpty) {
                            try {
                              await FirebaseFirestore.instance.collection('users').doc(pId).set({
                                'goals': FieldValue.increment(sc['goals'] ?? 1),
                              }, SetOptions(merge: true));
                            } catch (_) {}
                          }
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
      },
    );
  }

  // ─── Modal: Cargar Tarjetas del Partido ──────────────────────────────────
  void _showMatchCardsModal(
    BuildContext context, {
    required Map<String, dynamic> fixture,
    required int matchIndex,
    required Map<String, dynamic>? homeClub,
    required Map<String, dynamic>? awayClub,
    required String category,
  }) {
    final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    int exactMatchIndex = -1;
    final targetCat = category.replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
    exactMatchIndex = matches.indexWhere((m) {
      final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
      return (mCat == targetCat || m['category'] == category) &&
          (homeClub == null || m['homeClubId'] == homeClub['id']) &&
          (awayClub == null || m['awayClubId'] == awayClub['id']);
    });
    if (exactMatchIndex == -1) {
      exactMatchIndex = (matchIndex >= 0 && matchIndex < matches.length) ? matchIndex : 0;
    }
    final match = Map<String, dynamic>.from(matches.isNotEmpty ? matches[exactMatchIndex] : {});
    final List<Map<String, dynamic>> matchCards = (match['cards'] as List?)
        ?.map((c) => c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{})
        .where((c) => c.isNotEmpty)
        .toList() ?? [];

    final homeName = homeClub?['name'] ?? 'Local';
    final awayName = awayClub?['name'] ?? 'Visitante';

    String selectedTeam = homeName;
    String selectedCardType = 'yellow'; // 'yellow' | 'red'
    String? selectedPlayerId;
    final nameController = TextEditingController();
    bool manualNameInput = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final allPlayers = ref.watch(playersStreamProvider).valueOrNull ?? [];
            final categoryClean = category
                .replaceAll('Categoría', '')
                .replaceAll('Cat.', '')
                .replaceAll('Cat', '')
                .trim()
                .toLowerCase();

            final categoryPlayers = allPlayers.where((p) {
              final cat = (p['category']?.toString() ?? '')
                  .replaceAll('Categoría', '')
                  .replaceAll('Cat.', '')
                  .replaceAll('Cat', '')
                  .trim()
                  .toLowerCase();
              return cat == categoryClean;
            }).toList();
            categoryPlayers.sort((a, b) =>
                _getPlayerName(a).toLowerCase().compareTo(_getPlayerName(b).toLowerCase()));

            return StatefulBuilder(
              builder: (context, setModalState) {
                final bool isLocalSelected = selectedTeam == homeName ||
                    selectedTeam.toLowerCase().contains('newbery') ||
                    (homeClub != null && selectedTeam == homeClub['name']);

                return AlertDialog(
                  backgroundColor: const Color(0xFF18181A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.square_rounded, color: Colors.amber, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Tarjetas del Partido',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
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
                          style: const TextStyle(
                              color: Color(0xFFE63946),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),

                        // ── Lista actual de tarjetas ──────────────────────────
                        if (matchCards.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242427),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'No hay tarjetas registradas en este partido.',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Column(
                            children: matchCards.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final card = entry.value;
                              final isRed = card['cardType']?.toString() == 'red';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF242427),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.square_rounded,
                                      size: 16,
                                      color: isRed ? Colors.red : Colors.amber,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            card['name']?.toString() ?? '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            '${card['team']} · ${isRed ? 'Tarjeta Roja' : 'Tarjeta Amarilla'}',
                                            style: const TextStyle(
                                                color: Colors.white60, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.redAccent),
                                      onPressed: () {
                                        setModalState(() => matchCards.removeAt(idx));
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
                          'Agregar Tarjeta al Partido',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        // Tipo de tarjeta
                        const Text('Tipo de Tarjeta',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setModalState(() => selectedCardType = 'yellow'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selectedCardType == 'yellow'
                                        ? Colors.amber.withValues(alpha: 0.25)
                                        : const Color(0xFF242427),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedCardType == 'yellow'
                                          ? Colors.amber
                                          : const Color(0xFF444448),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.square_rounded,
                                          size: 16, color: Colors.amber),
                                      SizedBox(width: 6),
                                      Text('Amarilla',
                                          style: TextStyle(
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setModalState(() => selectedCardType = 'red'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selectedCardType == 'red'
                                        ? Colors.red.withValues(alpha: 0.25)
                                        : const Color(0xFF242427),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedCardType == 'red'
                                          ? Colors.red
                                          : const Color(0xFF444448),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.square_rounded,
                                          size: 16, color: Colors.red),
                                      SizedBox(width: 6),
                                      Text('Roja',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Selector de Equipo
                        const Text('Equipo',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
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

                        // Selector de jugador
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isLocalSelected
                                  ? 'Jugador del Club'
                                  : 'Nombre del Jugador',
                              style:
                                  const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            if (isLocalSelected && manualNameInput)
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    manualNameInput = false;
                                    nameController.clear();
                                  });
                                },
                                child: const Text('📋 Usar lista',
                                    style: TextStyle(
                                        color: Color(0xFFE63946), fontSize: 11)),
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
                                value: categoryPlayers
                                        .any((p) => p['id'] == selectedPlayerId)
                                    ? selectedPlayerId
                                    : null,
                                hint: const Text('Seleccionar Jugador...',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                                dropdownColor: const Color(0xFF242427),
                                isExpanded: true,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                items: [
                                  ...categoryPlayers.map((p) {
                                    final pName = _getPlayerName(p);
                                    return DropdownMenuItem<String>(
                                      value: p['id'] as String,
                                      child: Text(
                                        pName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }),
                                  const DropdownMenuItem<String>(
                                    value: 'MANUAL',
                                    child: Text('✍️ Escribir otro nombre...',
                                        style: TextStyle(
                                            color: Color(0xFFE63946))),
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
                                    final sel = categoryPlayers
                                        .firstWhere((p) => p['id'] == val);
                                    final pName = _getPlayerName(sel);
                                    setModalState(() {
                                      selectedPlayerId = val;
                                      nameController.text = pName;
                                      final existingIdx = matchCards.indexWhere((c) =>
                                          (c['playerId'] == val || c['name'] == pName) &&
                                          c['cardType'] == selectedCardType);
                                      if (existingIdx == -1) {
                                        matchCards.add({
                                          'name': pName,
                                          'playerId': val,
                                          'team': selectedTeam,
                                          'cardType': selectedCardType,
                                          'isClub': isLocalSelected,
                                        });
                                      }
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
                              hintText: isLocalSelected
                                  ? 'Ej: Nombre del jugador'
                                  : 'Ej: Jugador Rival',
                              hintStyle: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF242427),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selectedCardType == 'red'
                                ? Colors.red
                                : Colors.amber,
                            side: BorderSide(
                                color: selectedCardType == 'red'
                                    ? Colors.red
                                    : Colors.amber),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(
                            Icons.square_rounded,
                            size: 16,
                            color: selectedCardType == 'red' ? Colors.red : Colors.amber,
                          ),
                          label: Text('Añadir ${selectedCardType == 'red' ? 'Tarjeta Roja' : 'Tarjeta Amarilla'}'),
                          onPressed: () {
                            final pName = nameController.text.trim();
                            if (pName.isNotEmpty) {
                              setModalState(() {
                                final existingIdx = matchCards.indexWhere((c) =>
                                    c['name']?.toString().toLowerCase() == pName.toLowerCase() &&
                                    c['team'] == selectedTeam &&
                                    c['cardType'] == selectedCardType);
                                if (existingIdx == -1) {
                                  matchCards.add({
                                    'name': pName,
                                    'playerId': selectedPlayerId,
                                    'team': selectedTeam,
                                    'cardType': selectedCardType,
                                    'isClub': isLocalSelected,
                                  });
                                }
                                nameController.clear();
                                selectedPlayerId = null;
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
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        // Auto-incluir jugador si fue escrito o seleccionado y no se presionó el botón secundario
                        final currentName = nameController.text.trim();
                        if (currentName.isNotEmpty) {
                          final existingIdx = matchCards.indexWhere((c) =>
                              c['name']?.toString().toLowerCase() == currentName.toLowerCase() &&
                              c['team'] == selectedTeam &&
                              c['cardType'] == selectedCardType);
                          if (existingIdx == -1) {
                            matchCards.add({
                              'name': currentName,
                              'playerId': selectedPlayerId,
                              'team': selectedTeam,
                              'cardType': selectedCardType,
                              'isClub': isLocalSelected,
                            });
                          }
                        }

                        final currentMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
                        int saveIndex = currentMatches.indexWhere((m) {
                          final mCat = (m['category']?.toString() ?? '').replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                          final tCat = (match['category']?.toString() ?? category).replaceAll('Categoría', '').replaceAll('Cat.', '').replaceAll('Cat', '').trim().toLowerCase();
                          final bool catMatch = mCat == tCat || m['category'] == match['category'] || m['category'] == category;
                          final bool homeMatch = m['homeClubId'] == match['homeClubId'] || (m['homeClubId'] == null && match['homeClubId'] == null);
                          final bool awayMatch = m['awayClubId'] == match['awayClubId'] || (m['awayClubId'] == null && match['awayClubId'] == null);
                          return catMatch && homeMatch && awayMatch;
                        });
                        if (saveIndex == -1) {
                          saveIndex = (exactMatchIndex >= 0 && exactMatchIndex < currentMatches.length) ? exactMatchIndex : 0;
                        }

                        currentMatches[saveIndex] = {
                          ...currentMatches[saveIndex],
                          'cards': matchCards,
                        };

                        await ref
                            .read(firestoreServiceProvider)
                            .updateFixture(fixture['id'], {'matches': currentMatches});

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tarjetas guardadas correctamente!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Guardar Tarjetas',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── 1. Planilla de Resultados Oficiales UCIV ─────────────────────────────
  Widget _buildLeagueJornadaSheetTab() {
    final jornadasAsync = ref.watch(leagueJornadasStreamProvider);
    final clubsAsync = ref.watch(clubsStreamProvider);
    final clubs = clubsAsync.valueOrNull ?? [];

    return jornadasAsync.when(
      data: (allJornadas) {
        final filteredJornadas = allJornadas.where((j) {
          final t = (j['tournamentType'] ?? 'apertura').toString().toLowerCase().trim();
          return t == _sheetTournamentFilter;
        }).toList();

        Map<String, dynamic>? currentJornada;
        if (filteredJornadas.isNotEmpty) {
          if (_selectedJornadaId != null) {
            currentJornada = filteredJornadas.where((j) => j['id'] == _selectedJornadaId).firstOrNull;
          }
          currentJornada ??= filteredJornadas.first;
        }

        final rawCats = currentJornada?['categories'] as List?;
        final List<String> categories = (rawCats != null && rawCats.isNotEmpty)
            ? rawCats.map((c) => c.toString()).toList()
            : kDefaultCategories;

        final matches = (currentJornada?['matches'] as List?)
            ?.map((m) => m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{})
            .where((m) => m.isNotEmpty)
            .toList() ?? [];

        // Encontrar partido de Jorge Newbery en esta fecha si existe
        final jnMatch = matches.where((m) {
          final h = (m['homeTeam'] ?? '').toString().toLowerCase();
          final a = (m['awayTeam'] ?? '').toString().toLowerCase();
          return h.contains('newbery') || h.contains('jn') || a.contains('newbery') || a.contains('jn');
        }).firstOrNull;

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [
            // ─── Header: UCIV Badge & Selector Torneo ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC1121F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC1121F).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Color(0xFFE63946)),
                      SizedBox(width: 5),
                      Text(
                        'UCIV · Oficial',
                        style: TextStyle(
                          color: Color(0xFFE63946),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selector Torneo Apertura / Clausura
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sheetTournamentFilter,
                      dropdownColor: context.colors.surface,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE63946)),
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'apertura', child: Text('🏆 Torneo Apertura')),
                        DropdownMenuItem(value: 'clausura', child: Text('🏆 Torneo Clausura')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _sheetTournamentFilter = val;
                            final matching = allJornadas.where((j) => (j['tournamentType'] ?? 'apertura') == val).firstOrNull;
                            _selectedJornadaId = matching?['id']?.toString();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Selector de Fechas (Pills) ───
            if (filteredJornadas.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredJornadas.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final j = filteredJornadas[idx];
                    final isSelected = j['id'] == (currentJornada?['id']);
                    final title = j['fechaTitle']?.toString() ?? 'Fecha ${j['fechaNumber'] ?? (idx + 1)}';

                    return ChoiceChip(
                      label: Text(title),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedJornadaId = j['id']?.toString();
                        });
                      },
                      selectedColor: const Color(0xFFC1121F),
                      backgroundColor: context.colors.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : context.colors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFC1121F) : context.colors.border.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 14),

            if (currentJornada == null)
              JNCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 48, color: context.colors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'No hay planillas cargadas para el Torneo ${_sheetTournamentFilter == 'apertura' ? 'Apertura' : 'Clausura'}',
                      style: context.typography.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Las hojas de resultados oficiales de la liga se sincronizarán aquí automáticamente.',
                      style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              // ─── Card Destacada Jorge Newbery ───
              if (jnMatch != null) ...[
                _buildJorgeNewberyMatchHighlightCard(jnMatch, categories, clubs),
                const SizedBox(height: 14),
              ],

              // ─── Tabla Matriz Oficial de la Liga ───
              _buildOfficialMatrixTableCard(currentJornada, categories, matches, clubs),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error al cargar planillas: $err', style: TextStyle(color: context.colors.error))),
    );
  }

  Widget _buildJorgeNewberyMatchHighlightCard(
    Map<String, dynamic> jnMatch,
    List<String> categories,
    List<Map<String, dynamic>> clubs,
  ) {
    final matchCats = jnMatch['categories'] as Map<String, dynamic>?;
    final pts = calculateMatchPoints(matchCats, categories);

    final homePts = jnMatch['homeReportedPts'] != null
        ? int.tryParse(jnMatch['homeReportedPts'].toString()) ?? pts['homePts']!
        : pts['homePts']!;
    final awayPts = jnMatch['awayReportedPts'] != null
        ? int.tryParse(jnMatch['awayReportedPts'].toString()) ?? pts['awayPts']!
        : pts['awayPts']!;

    final homeName = jnMatch['homeTeam']?.toString() ?? 'Jorge Newbery';
    final awayName = jnMatch['awayTeam']?.toString() ?? 'Rival';

    final hClub = findMatchingClub(clubs, homeName);
    final aClub = findMatchingClub(clubs, awayName);
    final hDisplayName = hClub?['name'] ?? normalizeClubName(homeName);
    final aDisplayName = aClub?['name'] ?? normalizeClubName(awayName);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC1121F).withValues(alpha: 0.18),
            context.colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC1121F), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFE63946), size: 16),
              SizedBox(width: 6),
              Text(
                'RESULTADO DEL CLUB EN ESTA FECHA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE63946),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Enfrentamiento y Puntaje
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                // Local
                Expanded(
                  child: Row(
                    children: [
                      _buildClubSmallAvatar(hClub),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hDisplayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: hDisplayName.toLowerCase().contains('newbery')
                                    ? const Color(0xFFE63946)
                                    : context.colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$homePts pts',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: hDisplayName.toLowerCase().contains('newbery')
                                    ? const Color(0xFFE63946)
                                    : context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Center VS Badge
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC1121F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC1121F).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE63946),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Visitante
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              aDisplayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: aDisplayName.toLowerCase().contains('newbery')
                                    ? const Color(0xFFE63946)
                                    : context.colors.textPrimary,
                              ),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$awayPts pts',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: aDisplayName.toLowerCase().contains('newbery')
                                    ? const Color(0xFFE63946)
                                    : context.colors.textSecondary,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildClubSmallAvatar(aClub),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Badges por categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final hG = getCategoryGoals(matchCats, cat, 'home');
                final aG = getCategoryGoals(matchCats, cat, 'away');
                final hasScore = hG != null && aG != null;

                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Cat. $cat',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasScore ? '$hG - $aG' : '-',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: hasScore ? context.colors.textPrimary : context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialMatrixTableCard(
    Map<String, dynamic> currentJornada,
    List<String> categories,
    List<Map<String, dynamic>> matches,
    List<Map<String, dynamic>> clubs,
  ) {
    final tournamentType = (currentJornada['tournamentType'] ?? 'apertura').toString().toUpperCase();
    final fechaTitle = (currentJornada['fechaTitle'] ?? 'FECHA ${currentJornada['fechaNumber'] ?? ''}').toString().toUpperCase();
    final dateStr = formatDisplayDate(currentJornada['date']?.toString());

    const double rowHeight = 38.0;
    const double leftColWidth = 148.0;
    const double catColWidth = 46.0;
    const double ptsColWidth = 44.0;

    return JNCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Top Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.4))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNIÓN DE CLUBES INFANTILES VARELENSES (UCIV)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE63946),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'TORNEO $tournamentType · $fechaTitle RESULTADOS${dateStr.isNotEmpty ? ' ($dateStr)' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${matches.length} Partidos · ${categories.length} Categorías',
                  style: TextStyle(fontSize: 10, color: context.colors.textTertiary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Side-by-Side: Fixed Left Column + Horizontal Scrollable Right Table
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. COLUMNA FIJA: CLUBES ───
              SizedBox(
                width: leftColWidth,
                child: Column(
                  children: [
                    // Header Clubes
                    Container(
                      height: rowHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant,
                        border: Border(
                          right: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                          bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                        ),
                      ),
                      child: const Text(
                        'CLUBES',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFE63946)),
                      ),
                    ),

                    // Filas de Clubes
                    ...matches.asMap().entries.map((entry) {
                      final mIdx = entry.key;
                      final m = entry.value;
                      final rawH = (m['homeTeam'] ?? '').toString();
                      final rawA = (m['awayTeam'] ?? '').toString();
                      final isJNLocal = rawH.toLowerCase().contains('newbery') || rawH.toLowerCase().contains('jn');
                      final isJNAway = rawA.toLowerCase().contains('newbery') || rawA.toLowerCase().contains('jn');
                      final isJNMatch = isJNLocal || isJNAway;

                      final hClub = findMatchingClub(clubs, rawH);
                      final aClub = findMatchingClub(clubs, rawA);
                      final hDisplayName = hClub?['name'] ?? normalizeClubName(rawH);
                      final aDisplayName = aClub?['name'] ?? normalizeClubName(rawA);

                      final isEvenMatch = mIdx % 2 == 0;
                      final defaultMatchBg = isEvenMatch ? context.colors.surfaceVariant.withValues(alpha: 0.45) : Colors.transparent;

                      final homeBg = isJNLocal
                          ? const Color(0xFFC1121F).withValues(alpha: 0.22)
                          : (isJNMatch ? const Color(0xFFC1121F).withValues(alpha: 0.08) : defaultMatchBg);

                      final awayBg = isJNAway
                          ? const Color(0xFFC1121F).withValues(alpha: 0.22)
                          : (isJNMatch ? const Color(0xFFC1121F).withValues(alpha: 0.08) : defaultMatchBg);

                      final matchDividerBorder = BorderSide(
                        color: isJNMatch ? const Color(0xFFC1121F).withValues(alpha: 0.7) : context.colors.border.withValues(alpha: 0.85),
                        width: 2.2,
                      );
                      final innerRowBorder = BorderSide(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1.0,
                      );

                      return Column(
                        children: [
                          // Fila Local
                          Container(
                            height: rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: homeBg,
                              border: Border(
                                right: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                                bottom: innerRowBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildClubSmallAvatar(hClub),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    hDisplayName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isJNLocal ? FontWeight.w900 : FontWeight.w600,
                                      color: isJNLocal ? const Color(0xFFE63946) : context.colors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isJNLocal) ...[
                                  const SizedBox(width: 2),
                                  const Text('⭐', style: TextStyle(fontSize: 9)),
                                ],
                              ],
                            ),
                          ),

                          // Fila Visitante (con división gruesa que separa partidos)
                          Container(
                            height: rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: awayBg,
                              border: Border(
                                right: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                                bottom: matchDividerBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildClubSmallAvatar(aClub),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    aDisplayName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isJNAway ? FontWeight.w900 : FontWeight.w600,
                                      color: isJNAway ? const Color(0xFFE63946) : context.colors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isJNAway) ...[
                                  const SizedBox(width: 2),
                                  const Text('⭐', style: TextStyle(fontSize: 9)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              // ─── 2. SECCIÓN SCROLLABLE: CATEGORÍAS + PTS ───
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Categorías
                      Container(
                        height: rowHeight,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant,
                          border: Border(
                            bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            ...categories.map(
                              (cat) => SizedBox(
                                width: catColWidth,
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: ptsColWidth,
                              color: const Color(0xFFC1121F).withValues(alpha: 0.1),
                              child: const Center(
                                child: Text(
                                  'Pts',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFE63946)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filas de Goles y Puntos
                      ...matches.asMap().entries.map((entry) {
                        final mIdx = entry.key;
                        final m = entry.value;
                        final matchCats = m['categories'] as Map<String, dynamic>?;
                        final calcPts = calculateMatchPoints(matchCats, categories);

                        final rawH = (m['homeTeam'] ?? '').toString();
                        final rawA = (m['awayTeam'] ?? '').toString();
                        final isJNLocal = rawH.toLowerCase().contains('newbery') || rawH.toLowerCase().contains('jn');
                        final isJNAway = rawA.toLowerCase().contains('newbery') || rawA.toLowerCase().contains('jn');
                        final isJNMatch = isJNLocal || isJNAway;

                        final finalHomePts = m['homeReportedPts'] != null
                            ? int.tryParse(m['homeReportedPts'].toString()) ?? calcPts['homePts']!
                            : calcPts['homePts']!;
                        final finalAwayPts = m['awayReportedPts'] != null
                            ? int.tryParse(m['awayReportedPts'].toString()) ?? calcPts['awayPts']!
                            : calcPts['awayPts']!;

                        final isEvenMatch = mIdx % 2 == 0;
                        final defaultMatchBg = isEvenMatch ? context.colors.surfaceVariant.withValues(alpha: 0.45) : Colors.transparent;

                        final homeBg = isJNLocal
                            ? const Color(0xFFC1121F).withValues(alpha: 0.22)
                            : (isJNMatch ? const Color(0xFFC1121F).withValues(alpha: 0.08) : defaultMatchBg);

                        final awayBg = isJNAway
                            ? const Color(0xFFC1121F).withValues(alpha: 0.22)
                            : (isJNMatch ? const Color(0xFFC1121F).withValues(alpha: 0.08) : defaultMatchBg);

                        final matchDividerBorder = BorderSide(
                          color: isJNMatch ? const Color(0xFFC1121F).withValues(alpha: 0.7) : context.colors.border.withValues(alpha: 0.85),
                          width: 2.2,
                        );
                        final innerRowBorder = BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1.0,
                        );

                        return Column(
                          children: [
                            // Goles Local
                            Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: homeBg,
                                border: Border(bottom: innerRowBorder),
                              ),
                              child: Row(
                                children: [
                                  ...categories.map((cat) {
                                    final g = getCategoryGoals(matchCats, cat, 'home');
                                    return SizedBox(
                                      width: catColWidth,
                                      child: Center(
                                        child: Text(
                                          g != null ? g.toString() : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: g != null ? FontWeight.w800 : FontWeight.normal,
                                            color: g != null ? context.colors.textPrimary : context.colors.textTertiary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  Container(
                                    width: ptsColWidth,
                                    color: isJNLocal
                                        ? const Color(0xFFC1121F).withValues(alpha: 0.3)
                                        : const Color(0xFFC1121F).withValues(alpha: 0.05),
                                    child: Center(
                                      child: Text(
                                        '$finalHomePts',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: isJNLocal ? const Color(0xFFE63946) : context.colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Goles Visitante
                            Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: awayBg,
                                border: Border(bottom: matchDividerBorder),
                              ),
                              child: Row(
                                children: [
                                  ...categories.map((cat) {
                                    final g = getCategoryGoals(matchCats, cat, 'away');
                                    return SizedBox(
                                      width: catColWidth,
                                      child: Center(
                                        child: Text(
                                          g != null ? g.toString() : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: g != null ? FontWeight.w800 : FontWeight.normal,
                                            color: g != null ? context.colors.textPrimary : context.colors.textTertiary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  Container(
                                    width: ptsColWidth,
                                    color: isJNAway
                                        ? const Color(0xFFC1121F).withValues(alpha: 0.3)
                                        : const Color(0xFFC1121F).withValues(alpha: 0.05),
                                    child: Center(
                                      child: Text(
                                        '$finalAwayPts',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: isJNAway ? const Color(0xFFE63946) : context.colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Table Footer Legend
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(top: BorderSide(color: context.colors.border.withValues(alpha: 0.3))),
            ),
            child: const Text(
              'Regla de Puntuación: Victoria = 2 pts · Empate = 1 pt · Derrota = 0 pts',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE63946),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Tabla de Posiciones ──────────────────────────────────
  Widget _buildStandingsTab() {
    final jornadasAsync = ref.watch(leagueJornadasStreamProvider);
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);
    final rawCategories = ref.watch(appCategoriesProvider);

    final jornadas = jornadasAsync.valueOrNull ?? [];
    final fixtures = fixturesAsync.valueOrNull ?? [];
    final clubs = clubsAsync.valueOrNull ?? [];

    const double rowHeight = 42.0;
    const double leftColWidth = 158.0;

    // Categorías para la tabla de posiciones (excluyendo promocionales 2020 y 2021)
    final standingsCategoryOptions = rawCategories
        .where((cat) {
          final clean = cat.replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
          return clean != '2020' && clean != '2021';
        })
        .toList();

    if (standingsCategoryOptions.isEmpty) {
      standingsCategoryOptions.addAll(kDefaultCategories);
    }

    final standings = calculateStandings(
      leagueJornadas: jornadas,
      fixtures: fixtures,
      clubs: clubs,
      tournament: _standingsTournament,
      category: _standingsCategory,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      children: [
        // ─── Header: Controles de Torneo y Categoría ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _standingsTournament == 'anual'
                      ? 'Tabla Anual Acumulada'
                      : (_standingsTournament == 'apertura' ? 'Torneo Apertura' : 'Torneo Clausura'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE63946),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _standingsCategory == 'all'
                      ? 'Tabla General (Tira Completa)'
                      : 'Tabla de Posiciones · Cat. $_standingsCategory',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),

            // Dropdown de Torneo (Anual Acumulada, Apertura, Clausura)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _standingsTournament,
                  dropdownColor: context.colors.surface,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE63946)),
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'anual', child: Text('🏆 Anual (Acumulada)')),
                    DropdownMenuItem(value: 'apertura', child: Text('🏆 Apertura')),
                    DropdownMenuItem(value: 'clausura', child: Text('🏆 Clausura')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _standingsTournament = val);
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ─── Pills Selector de Categorías ───
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('🏆 General (Tira)'),
                  selected: _standingsCategory == 'all',
                  onSelected: (_) => setState(() => _standingsCategory = 'all'),
                  selectedColor: const Color(0xFFC1121F),
                  backgroundColor: context.colors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: _standingsCategory == 'all' ? Colors.white : context.colors.textSecondary,
                    fontWeight: _standingsCategory == 'all' ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _standingsCategory == 'all' ? const Color(0xFFC1121F) : context.colors.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              ...standingsCategoryOptions.map((cat) {
                final cleanCat = cat.replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
                final isSelected = _standingsCategory == cleanCat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Cat. $cleanCat'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _standingsCategory = cleanCat),
                    selectedColor: const Color(0xFFC1121F),
                    backgroundColor: context.colors.surfaceVariant,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : context.colors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFC1121F) : context.colors.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (standings.isEmpty)
          JNCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, size: 48, color: context.colors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'Sin datos de partidos jugados',
                  style: context.typography.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Carga las planillas de resultados para ver la tabla en vivo.',
                  style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          JNCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Side-by-Side: Fixed Left Column (# and EQUIPO) + Horizontal Scrollable Right Table
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── 1. COLUMNA FIJA: # Y EQUIPO ───
                    SizedBox(
                      width: leftColWidth,
                      child: Column(
                        children: [
                          // Header Fijo
                          Container(
                            height: rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceVariant,
                              border: Border(
                                right: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                                bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                              ),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Center(
                                    child: Text('#', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('EQUIPO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                ),
                              ],
                            ),
                          ),

                          // Filas de Equipos Fijos
                          ...standings.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final row = entry.value;
                            final isNewbery = row['isLocal'] == true ||
                                (row['name']?.toString() ?? '').toLowerCase().contains('newbery') ||
                                (row['name']?.toString() ?? '').toLowerCase().contains('jn');
                            final isPodium = idx < 3;
                            final isEven = idx % 2 == 0;
                            final rowBg = isNewbery
                                ? const Color(0xFFC1121F).withValues(alpha: 0.15)
                                : (isEven ? Colors.transparent : Colors.white.withValues(alpha: 0.02));

                            return Container(
                              height: rowHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: rowBg,
                                border: Border(
                                  right: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                                  bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.25)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // # Posición con Medalla
                                  SizedBox(
                                    width: 22,
                                    child: Center(
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: isPodium
                                              ? (idx == 0
                                                  ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                                                  : idx == 1
                                                      ? const Color(0xFFC0C0C0).withValues(alpha: 0.25)
                                                      : const Color(0xFFCD7F32).withValues(alpha: 0.25))
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              color: isPodium
                                                  ? (idx == 0
                                                      ? const Color(0xFFFFD700)
                                                      : idx == 1
                                                          ? const Color(0xFFE0E0E0)
                                                          : const Color(0xFFCD7F32))
                                                  : context.colors.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Escudo + Nombre
                                  _buildClubSmallAvatar(row),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${row['name']}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isNewbery ? FontWeight.w900 : FontWeight.w600,
                                        color: isNewbery ? const Color(0xFFE63946) : context.colors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isNewbery) ...[
                                    const SizedBox(width: 2),
                                    const Text('⭐', style: TextStyle(fontSize: 9)),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // ─── 2. SECCIÓN SCROLLABLE: PJ..PTS ───
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Estadísticas
                            Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: context.colors.surfaceVariant,
                                border: Border(
                                  bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5), width: 1.5),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 32, child: Center(child: Text('PJ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(width: 32, child: Center(child: Text('PG', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(width: 32, child: Center(child: Text('PE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(width: 32, child: Center(child: Text('PP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(width: 34, child: Center(child: Text('GF', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(width: 34, child: Center(child: Text('GC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(width: 36, child: Center(child: Text('DG', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                                  SizedBox(
                                    width: 44,
                                    child: Center(
                                      child: Text('PTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFE63946))),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Filas de Estadísticas
                            ...standings.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final row = entry.value;
                              final isNewbery = row['isLocal'] == true ||
                                  (row['name']?.toString() ?? '').toLowerCase().contains('newbery') ||
                                  (row['name']?.toString() ?? '').toLowerCase().contains('jn');
                              final dg = row['dg'] as int;
                              final isEven = idx % 2 == 0;
                              final rowBg = isNewbery
                                  ? const Color(0xFFC1121F).withValues(alpha: 0.15)
                                  : (isEven ? Colors.transparent : Colors.white.withValues(alpha: 0.02));

                              return Container(
                                height: rowHeight,
                                decoration: BoxDecoration(
                                  color: rowBg,
                                  border: Border(bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.25))),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 32, child: Center(child: Text('${row['pj']}', style: const TextStyle(fontSize: 11)))),
                                    SizedBox(width: 32, child: Center(child: Text('${row['pg']}', style: const TextStyle(fontSize: 11)))),
                                    SizedBox(width: 32, child: Center(child: Text('${row['pe']}', style: const TextStyle(fontSize: 11)))),
                                    SizedBox(width: 32, child: Center(child: Text('${row['pp']}', style: const TextStyle(fontSize: 11)))),
                                    SizedBox(width: 34, child: Center(child: Text('${row['gf']}', style: const TextStyle(fontSize: 11)))),
                                    SizedBox(width: 34, child: Center(child: Text('${row['gc']}', style: const TextStyle(fontSize: 11)))),
                                    SizedBox(
                                      width: 36,
                                      child: Center(
                                        child: Text(
                                          dg > 0 ? '+$dg' : '$dg',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: dg > 0
                                                ? context.colors.success
                                                : (dg < 0 ? context.colors.error : context.colors.textTertiary),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 44,
                                      color: isNewbery
                                          ? const Color(0xFFC1121F).withValues(alpha: 0.25)
                                          : const Color(0xFFC1121F).withValues(alpha: 0.05),
                                      child: Center(
                                        child: Text(
                                          '${row['pts']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: isNewbery ? const Color(0xFFE63946) : context.colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Table Footer Legend
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceVariant.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border(top: BorderSide(color: context.colors.border.withValues(alpha: 0.3))),
                  ),
                  child: const Text(
                    'Criterio de Desempate: Puntos > Dif. Goles > Goles a Favor > Nombre',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE63946),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── 3. Goleadores Tab ──────────────────────────────────
  Widget _buildScorersTab(bool canManage) {
    final scorersAsync = ref.watch(scorersStreamProvider(_selectedCategory));
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));

    final cleanCategory = _selectedCategory
        .replaceAll('Categoría', '')
        .replaceAll('Cat.', '')
        .replaceAll('Cat', '')
        .trim()
        .toLowerCase();

    return scorersAsync.when(
      data: (directScorers) {
        final fixtures = fixturesAsync.valueOrNull ?? [];
        final Map<String, Map<String, dynamic>> combinedMap = {};

        // 1. Extraer goleadores de todos los partidos del fixture
        for (final fix in fixtures) {
          final matches = List<Map<String, dynamic>>.from(fix['matches'] ?? []);
          for (final m in matches) {
            final mCat = (m['category']?.toString() ?? '')
                .replaceAll('Categoría', '')
                .replaceAll('Cat.', '')
                .replaceAll('Cat', '')
                .trim()
                .toLowerCase();

            final bool matchesCategory = _selectedCategory == 'all' ||
                _selectedCategory == 'Todas las Cat.' ||
                _selectedCategory.isEmpty ||
                mCat == cleanCategory ||
                (cleanCategory.isNotEmpty && mCat.contains(cleanCategory)) ||
                (mCat.isNotEmpty && cleanCategory.contains(mCat));

            if (!matchesCategory) continue;

            final scorersList = List<Map<String, dynamic>>.from(m['scorers'] ?? []);
            for (final sc in scorersList) {
              final name = sc['name']?.toString().trim() ?? '';
              if (name.isEmpty) continue;
              final pId = sc['playerId']?.toString().trim();
              final team = sc['team']?.toString().trim() ?? 'Club';
              final key = (pId != null && pId.isNotEmpty) ? pId : '${name.toLowerCase()}_${team.toLowerCase()}';
              final goals = (sc['goals'] is int)
                  ? sc['goals'] as int
                  : int.tryParse(sc['goals']?.toString() ?? '') ?? 1;
              final isClub = sc['isClub'] == true || team.toLowerCase().contains('newbery');

              if (combinedMap.containsKey(key)) {
                combinedMap[key]!['goals'] = (combinedMap[key]!['goals'] as int) + goals;
              } else {
                combinedMap[key] = {
                  'id': key,
                  'name': name,
                  'playerId': pId,
                  'team': team,
                  'category': m['category'] ?? _selectedCategory,
                  'goals': goals,
                  'isClub': isClub,
                };
              }
            }
          }
        }

        // 2. Extraer de la colección directa 'scorers' (para los que no provienen de fixture match)
        for (final sc in directScorers) {
          if (sc['fixtureId'] != null) {
            // Ya contabilizado en los partidos del fixture
            continue;
          }
          final name = sc['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final pId = sc['playerId']?.toString().trim();
          final team = sc['team']?.toString().trim() ?? 'Club';
          final key = (pId != null && pId.isNotEmpty) ? pId : '${name.toLowerCase()}_${team.toLowerCase()}';
          final goals = (sc['goals'] is int)
              ? sc['goals'] as int
              : int.tryParse(sc['goals']?.toString() ?? '') ?? 1;
          final isClub = sc['isClub'] == true || team.toLowerCase().contains('newbery');

          if (combinedMap.containsKey(key)) {
            combinedMap[key]!['goals'] = (combinedMap[key]!['goals'] as int) + goals;
          } else {
            combinedMap[key] = {
              'id': sc['id'] ?? key,
              'name': name,
              'playerId': pId,
              'team': team,
              'category': sc['category'] ?? _selectedCategory,
              'goals': goals,
              'isClub': isClub,
            };
          }
        }

        final List<Map<String, dynamic>> unifiedScorers = combinedMap.values.toList();
        unifiedScorers.sort((a, b) {
          final ga = a['goals'] as int? ?? 0;
          final gb = b['goals'] as int? ?? 0;
          return gb.compareTo(ga);
        });

        if (unifiedScorers.isEmpty) {
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
          itemCount: unifiedScorers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final scorer = unifiedScorers[index];
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
    final name = p['name']?.toString().trim() ?? '';
    final lastName = p['lastName']?.toString().trim() ?? '';
    final displayName = p['displayName']?.toString().trim() ?? '';
    final fullName = p['fullName']?.toString().trim() ?? '';

    if (name.isNotEmpty && lastName.isNotEmpty) {
      if (name.toLowerCase().contains(lastName.toLowerCase())) {
        return name;
      }
      return '$name $lastName';
    }
    if (name.isNotEmpty) return name;
    if (displayName.isNotEmpty) return displayName;
    if (fullName.isNotEmpty) return fullName;
    final fn = p['firstName']?.toString().trim() ?? '';
    final ln = p['lastName']?.toString().trim() ?? '';
    if (fn.isNotEmpty || ln.isNotEmpty) return '$fn $ln'.trim();
    return 'Jugador';
  }
}