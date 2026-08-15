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

    final bool canManage = sessionUser?.isAdmin == true || sessionUser?.role == 'dt';

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
                      child: Text(cat == 'all' ? 'Todas las Categorías' : cat),
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

  // ─── 1. Fixture & Resultados Tab ──────────────────────────────────
  Widget _buildFixtureTab(bool canManage) {
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);
    final clubs = clubsAsync.valueOrNull ?? [];

    return fixturesAsync.when(
      data: (allFixtures) {
        final filteredFixtures = allFixtures.where((f) {
          if (_selectedCategory == 'all') return true;
          final cat = f['category']?.toString();
          return cat == null || cat == 'all' || cat == _selectedCategory;
        }).toList();

        if (filteredFixtures.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer, size: 48, color: context.colors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No hay fechas programadas para esta categoría',
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
          itemCount: filteredFixtures.length,
          itemBuilder: (context, fIndex) {
            final fixture = filteredFixtures[fIndex];
            final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
            final fixtureName = fixture['name'] ?? 'Fecha ${fIndex + 1}';
            final fixtureCategory = fixture['category'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: JNCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de la Fecha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fixtureName,
                          style: context.typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (fixtureCategory != null && fixtureCategory != 'all')
                          JNBadge(
                            label: fixtureCategory.toString().toUpperCase(),
                            type: JNBadgeType.accent,
                            small: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Sin partidos asignados',
                          style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                        ),
                      ),

                    // Lista de Partidos
                    ...matches.asMap().entries.map((entry) {
                      final mIndex = entry.key;
                      final match = entry.value;
                      final homeClub = clubs.where((c) => c['id'] == match['homeClubId']).firstOrNull;
                      final awayClub = clubs.where((c) => c['id'] == match['awayClubId']).firstOrNull;

                      final status = match['status']?.toString() ?? 'scheduled';
                      final bool isFinished = status == 'finished' || status == 'finalizado';
                      final bool isLive = status == 'live' || status == 'en vivo';
                      final int? homeScore = match['homeScore'] != null ? int.tryParse(match['homeScore'].toString()) : null;
                      final int? awayScore = match['awayScore'] != null ? int.tryParse(match['awayScore'].toString()) : null;
                      final bool hasScores = homeScore != null && awayScore != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLive
                                ? context.colors.error.withValues(alpha: 0.5)
                                : context.colors.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Fila de Equipos y Marcador
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Local
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _buildClubItem(homeClub, alignRight: true),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Centro: Marcador o VS
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isFinished
                                        ? context.colors.surface
                                        : (isLive ? context.colors.error.withValues(alpha: 0.15) : context.colors.surface),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasScores || isFinished || isLive)
                                        Text(
                                          '${homeScore ?? 0} - ${awayScore ?? 0}',
                                          style: context.typography.titleLarge.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: isLive ? context.colors.error : context.colors.textPrimary,
                                          ),
                                        )
                                      else
                                        Text(
                                          'VS',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: context.colors.accent,
                                          ),
                                        ),
                                      if (match['date'] != null && match['time'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${match['date']} · ${match['time']}',
                                          style: context.typography.labelSmall.copyWith(
                                            color: context.colors.textTertiary,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Visitante
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildClubItem(awayClub, alignRight: false),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Fila de Estado y Botón de Carga de Resultado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Badge de Estado
                                if (isLive)
                                  const JNBadge(label: '● EN VIVO', type: JNBadgeType.error, small: true)
                                else if (isFinished)
                                  const JNBadge(label: 'FINALIZADO', type: JNBadgeType.success, small: true)
                                else
                                  const JNBadge(label: 'PROGRAMADO', small: true),

                                // Botón de Cargar Resultado (Directivos y DTs)
                                if (canManage)
                                  InkWell(
                                    onTap: () => _showMatchResultModal(
                                      context,
                                      fixture: fixture,
                                      matchIndex: mIndex,
                                      homeClub: homeClub,
                                      awayClub: awayClub,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.colors.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: context.colors.accent.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.sports_soccer, size: 14, color: context.colors.accent),
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

  Widget _buildClubItem(Map<String, dynamic>? club, {required bool alignRight}) {
    final name = club?['name'] ?? 'Rival';
    final logoUrl = club?['logoUrl']?.toString();
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: context.colors.surfaceLight,
      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
      child: logoUrl == null || logoUrl.isEmpty ? const Icon(Icons.shield, size: 16) : null,
    );

    if (alignRight) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              name,
              style: context.typography.titleSmall,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 8),
          avatar,
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: context.typography.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  // Modal de Carga Rápida de Resultado
  void _showMatchResultModal(
    BuildContext context, {
    required Map<String, dynamic> fixture,
    required int matchIndex,
    required Map<String, dynamic>? homeClub,
    required Map<String, dynamic>? awayClub,
  }) {
    final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    final match = matches[matchIndex];

    final homeController = TextEditingController(
      text: match['homeScore']?.toString() ?? '0',
    );
    final awayController = TextEditingController(
      text: match['awayScore']?.toString() ?? '0',
    );
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
                  const Text('Cargar Resultado', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    // Equipos e Inputs de Goles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Local
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: context.colors.surfaceLight,
                                backgroundImage: homeClub?['logoUrl'] != null && homeClub!['logoUrl'].isNotEmpty
                                    ? NetworkImage(homeClub['logoUrl'])
                                    : null,
                                child: homeClub?['logoUrl'] == null ? const Icon(Icons.shield) : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                homeClub?['name'] ?? 'Local',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: homeController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF242427),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('VS', style: TextStyle(color: Color(0xFFE5B842), fontWeight: FontWeight.w900, fontSize: 16)),
                        ),

                        // Visitante
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: context.colors.surfaceLight,
                                backgroundImage: awayClub?['logoUrl'] != null && awayClub!['logoUrl'].isNotEmpty
                                    ? NetworkImage(awayClub['logoUrl'])
                                    : null,
                                child: awayClub?['logoUrl'] == null ? const Icon(Icons.shield) : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                awayClub?['name'] ?? 'Visitante',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: awayController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF242427),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Selector de Estado
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado del Partido', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF242427),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: status,
                              dropdownColor: const Color(0xFF242427),
                              isExpanded: true,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
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

  // ─── 2. Posiciones Tab (Calculada en Vivo) ──────────────────────────────────
  Widget _buildStandingsTab() {
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);

    final fixtures = fixturesAsync.valueOrNull ?? [];
    final clubs = clubsAsync.valueOrNull ?? [];

    // Calcular estadísticas en vivo
    final Map<String, Map<String, dynamic>> standingsMap = {};

    // Inicializar todos los clubes registrados
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

    // Filtrar fechas según la categoría seleccionada
    final filteredFixtures = fixtures.where((f) {
      if (_selectedCategory == 'all') return true;
      final cat = f['category']?.toString();
      return cat == null || cat == 'all' || cat == _selectedCategory;
    }).toList();

    // Procesar todos los partidos terminados o con marcador
    for (final f in filteredFixtures) {
      final matches = List<Map<String, dynamic>>.from(f['matches'] ?? []);
      for (final m in matches) {
        final homeClub = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
        final awayClub = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;

        final homeName = homeClub?['name']?.toString() ?? 'Local';
        final awayName = awayClub?['name']?.toString() ?? 'Visitante';

        final status = m['status']?.toString() ?? '';
        final hScore = m['homeScore'] != null ? int.tryParse(m['homeScore'].toString()) : null;
        final aScore = m['awayScore'] != null ? int.tryParse(m['awayScore'].toString()) : null;

        // Si el partido está finalizado o tiene marcador cargado
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

          if (hScore > aScore) {
            homeStat['won'] = (homeStat['won'] as int) + 1;
            homeStat['points'] = (homeStat['points'] as int) + 3;
            awayStat['lost'] = (awayStat['lost'] as int) + 1;
          } else if (hScore < aScore) {
            awayStat['won'] = (awayStat['won'] as int) + 1;
            awayStat['points'] = (awayStat['points'] as int) + 3;
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
    // Ordenar: Puntos DESC, Diferencia de Gol DESC, Goles a Favor DESC, Partidos Ganados DESC
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
                // Posición
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

                // Escudo y Nombre
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

                // PJ, G, E, P, DG, PTS
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
                  // Rank / Medalla
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

                  // Info Jugador
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

                  // Goles
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
}