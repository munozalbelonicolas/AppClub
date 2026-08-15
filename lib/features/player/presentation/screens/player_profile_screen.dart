import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_stat_card.dart';

class PlayerProfileScreen extends ConsumerStatefulWidget {
  const PlayerProfileScreen({super.key});
  @override
  ConsumerState<PlayerProfileScreen> createState() =>
      _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen>
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
    final sessionUser = ref.watch(currentUserProvider)!;
    final playerAsync = ref.watch(playerProfileStreamProvider(sessionUser.id));
    final Map<String, dynamic>? player = playerAsync.valueOrNull;

    if (player == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: const Text('Perfil del Jugador')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 48, color: context.colors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'No se encontró perfil',
                  style: context.typography.titleMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final fixtures = ref.watch(fixturesStreamProvider('all')).valueOrNull ?? [];
    final clubs = ref.watch(clubsStreamProvider).valueOrNull ?? [];

    final playerName = '${player['name'] ?? ''} ${player['lastName'] ?? ''}'.trim();
    final playerId = player['id']?.toString();

    final List<Map<String, dynamic>> goalEvents = [];
    int totalGoalsCount = 0;

    for (final fixture in fixtures) {
      final fixName = fixture['name']?.toString() ?? 'Fecha';
      final fixDate = fixture['date']?.toString() ?? '';
      final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);

      for (final match in matches) {
        final scorers = List<Map<String, dynamic>>.from(match['scorers'] ?? []);
        for (final sc in scorers) {
          final scName = sc['name']?.toString().trim().toLowerCase() ?? '';
          final scId = sc['playerId']?.toString();
          final targetName = playerName.toLowerCase();

          final bool isMatch = (scId != null && scId == playerId) ||
              (scName.isNotEmpty && (scName == targetName || scName.contains(targetName) || targetName.contains(scName)));

          if (isMatch) {
            final homeClub = clubs.where((c) => c['id'] == match['homeClubId']).firstOrNull;
            final awayClub = clubs.where((c) => c['id'] == match['awayClubId']).firstOrNull;

            final teamName = sc['team']?.toString() ?? '';
            String rivalName = 'Rival';

            if (teamName.isNotEmpty) {
              if (homeClub != null && teamName.toLowerCase() == homeClub['name']?.toString().toLowerCase()) {
                rivalName = awayClub?['name'] ?? 'Visitante';
              } else if (awayClub != null && teamName.toLowerCase() == awayClub['name']?.toString().toLowerCase()) {
                rivalName = homeClub?['name'] ?? 'Local';
              } else {
                rivalName = awayClub?['name'] ?? homeClub?['name'] ?? 'Rival';
              }
            } else {
              rivalName = awayClub?['name'] ?? homeClub?['name'] ?? 'Rival';
            }

            final goals = (sc['goals'] is int) ? sc['goals'] as int : int.tryParse(sc['goals']?.toString() ?? '') ?? 1;
            totalGoalsCount += goals;

            goalEvents.add({
              'fixtureName': fixName,
              'date': match['date']?.toString() ?? fixDate,
              'rivalName': rivalName,
              'category': match['category']?.toString() ?? fixture['category']?.toString() ?? player['category'] ?? '',
              'goals': goals,
            });
          }
        }
      }
    }

    final displayGoals = totalGoalsCount > 0 ? totalGoalsCount : (player['goals'] as int? ?? 0);

    // ─── Tarjetas ───────────────────────────────────────────────────────────
    final List<Map<String, dynamic>> cardEvents = [];
    int totalYellow = 0;
    int totalRed = 0;

    for (final fixture in fixtures) {
      final fixName = fixture['name']?.toString() ?? 'Fecha';
      final fixDate = fixture['date']?.toString() ?? '';
      final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);

      for (final match in matches) {
        final cards = List<Map<String, dynamic>>.from(match['cards'] ?? []);
        for (final card in cards) {
          final cName = card['name']?.toString().trim().toLowerCase() ?? '';
          final cId = card['playerId']?.toString();
          final targetName = playerName.toLowerCase();

          final bool isMatch = (cId != null && cId == playerId) ||
              (cName.isNotEmpty && (cName == targetName || cName.contains(targetName) || targetName.contains(cName)));

          if (isMatch) {
            final isRed = card['cardType']?.toString() == 'red';
            if (isRed) {
              totalRed++;
            } else {
              totalYellow++;
            }
            final homeClub = clubs.where((c) => c['id'] == match['homeClubId']).firstOrNull;
            final awayClub = clubs.where((c) => c['id'] == match['awayClubId']).firstOrNull;
            final teamName = card['team']?.toString() ?? '';
            String rivalName = 'Rival';
            if (teamName.isNotEmpty && homeClub != null &&
                teamName.toLowerCase() == homeClub['name']?.toString().toLowerCase()) {
              rivalName = awayClub?['name'] ?? 'Visitante';
            } else if (teamName.isNotEmpty && awayClub != null &&
                teamName.toLowerCase() == awayClub['name']?.toString().toLowerCase()) {
              rivalName = homeClub?['name'] ?? 'Local';
            } else {
              rivalName = awayClub?['name'] ?? homeClub?['name'] ?? 'Rival';
            }
            cardEvents.add({
              'fixtureName': fixName,
              'date': match['date']?.toString() ?? fixDate,
              'rivalName': rivalName,
              'category': match['category']?.toString() ?? fixture['category']?.toString() ?? player['category'] ?? '',
              'cardType': card['cardType']?.toString() ?? 'yellow',
            });
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: context.colors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPlayerHeader(player, displayGoals),
            ),
            title: innerBoxIsScrolled
                ? Text(
                    '${player['name']} ${player['lastName']}',
                    style: context.typography.titleLarge,
                  )
                : null,
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Estadísticas'),
                  Tab(text: 'Info'),
                  Tab(text: 'Médica'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildStatsTab(player, displayGoals, goalEvents, cardEvents, totalYellow, totalRed),
            _buildInfoTab(player),
            _buildMedicalTab(player),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader(Map<String, dynamic> player, int displayGoals) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.colors.primary.withValues(alpha: 0.2),
            context.colors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            JNAvatar(
              name: '${player['name']} ${player['lastName']}',
              size: 88,
              borderColor: context.colors.accent,
              borderWidth: 3,
              number: player['number'] as int? ?? 0,
            ).animate().scale(
              begin: const Offset(0.8, 0.8),
              duration: 500.ms,
              curve: Curves.easeOut,
            ),

            const SizedBox(height: 14),

            Text(
              '${player['name']} ${player['lastName']}',
              style: context.typography.headlineLarge,
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (player['category'] != null)
                  JNBadge(
                    label: player['category'] as String,
                    type: JNBadgeType.accent,
                  ),
                const SizedBox(width: 8),
                if (player['position'] != null)
                  JNBadge(
                    label: player['position'] as String,
                  ),
                const SizedBox(width: 8),
                if (player['number'] != null)
                  JNBadge(label: '#${player['number']}', type: JNBadgeType.info),
              ],
            ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

            const SizedBox(height: 16),

            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickStat(value: '$displayGoals', label: 'Goles'),
                Container(width: 1, height: 30, color: context.colors.border),
                _QuickStat(value: '${player['assists'] ?? 0}', label: 'Asistencias'),
                Container(width: 1, height: 30, color: context.colors.border),
                _QuickStat(value: '${player['matches'] ?? 0}', label: 'Partidos'),
              ],
            ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(
    Map<String, dynamic> player,
    int displayGoals,
    List<Map<String, dynamic>> goalEvents,
    List<Map<String, dynamic>> cardEvents,
    int totalYellow,
    int totalRed,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Stat cards grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            JNStatCard(
              value: '$displayGoals',
              label: 'Goles en Torneo',
              icon: Icons.sports_soccer,
              color: context.colors.primary,
            ),
            JNStatCard(
              value: '${player['assists'] ?? 0}',
              label: 'Asistencias',
              icon: Icons.handshake,
              color: context.colors.accent,
            ),
            JNStatCard(
              value: '${player['matches'] ?? 0}',
              label: 'Partidos',
              icon: Icons.stadium,
              color: context.colors.info,
            ),
            JNStatCard(
              value: '$totalYellow',
              label: 'Amarillas',
              icon: Icons.square_rounded,
              color: Colors.amber,
            ),
            JNStatCard(
              value: '$totalRed',
              label: 'Rojas',
              icon: Icons.square_rounded,
              color: Colors.red,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        // ─── Historial de Goles en Torneo ───
        Text('Historial de Goles ($displayGoals)', style: context.typography.headlineSmall),
        const SizedBox(height: 12),

        if (goalEvents.isEmpty)
          JNCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sports_soccer, size: 28, color: context.colors.textTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aún no se registran goles oficiales en este torneo.',
                    style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: goalEvents.map((gEvent) {
              final catStr = gEvent['category'].toString();
              return JNCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(Icons.sports_soccer, color: context.colors.accent, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'vs ${gEvent['rivalName']}',
                            style: context.typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${gEvent['fixtureName']} · Cat. ${catStr.startsWith('20') ? catStr : catStr}'
                            '${gEvent['date'].toString().isNotEmpty ? ' · ${gEvent['date']}' : ''}',
                            style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${gEvent['goals']} ${gEvent['goals'] == 1 ? 'Gol' : 'Goles'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

        // ─── Historial de Tarjetas ───
        if (cardEvents.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Tarjetas Recibidas ($totalYellow 🟨 · $totalRed 🟥)',
            style: context.typography.headlineSmall,
          ),
          const SizedBox(height: 12),
          Column(
            children: cardEvents.map((cEvent) {
              final isRed = cEvent['cardType'] == 'red';
              return JNCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isRed ? Colors.red : Colors.amber)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.square_rounded,
                        color: isRed ? Colors.red : Colors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'vs ${cEvent['rivalName']}',
                            style: context.typography.titleMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cEvent['fixtureName']} · Cat. ${cEvent['category']}'
                            '${cEvent['date'].toString().isNotEmpty ? ' · ${cEvent['date']}' : ''}',
                            style: context.typography.bodySmall.copyWith(
                                color: context.colors.textTertiary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isRed ? Colors.red : Colors.amber)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRed ? 'ROJA' : 'AMARILLA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isRed ? Colors.red : Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 24),

        // Performance summary
        Text('Rendimiento por partido', style: context.typography.headlineSmall),
        const SizedBox(height: 12),
        JNCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _PerformanceRow(
                label: 'Goles por partido',
                value: (player['goals'] as int) / (player['matches'] as int),
              ),
              const SizedBox(height: 12),
              _PerformanceRow(
                label: 'Asistencias por partido',
                value: (player['assists'] as int) / (player['matches'] as int),
              ),
              const SizedBox(height: 12),
              _PerformanceRow(
                label: 'Participación en goles',
                value:
                    ((player['goals'] as int) + (player['assists'] as int)) /
                    20,
                maxValue: 1.5,
                color: context.colors.accent,
              ),
            ],
          ),
        ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> player) {
    String fmt(dynamic raw) {
      if (raw == null) return '—';
      if (raw is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(raw.toDate());
      }
      if (raw is DateTime) {
        return DateFormat('dd/MM/yyyy').format(raw);
      }
      return raw.toString();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children:
          [
            _InfoTile(
              icon: Icons.cake,
              label: 'Edad',
              value: player['age'] != null ? '${player['age']} años' : '—',
            ),
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Fecha de nacimiento',
              value: fmt(player['birthDate']),
            ),
            _InfoTile(
              icon: Icons.sports,
              label: 'Posición',
              value: fmt(player['position']),
            ),
            _InfoTile(
              icon: Icons.numbers,
              label: 'Dorsal',
              value: player['number'] != null ? '#${player['number']}' : '—',
            ),
            _InfoTile(
              icon: Icons.category,
              label: 'Categoría',
              value: fmt(player['category']),
            ),
            if (player.containsKey('height'))
              _InfoTile(
                icon: Icons.height,
                label: 'Altura',
                value: fmt(player['height']),
              ),
            if (player.containsKey('weight'))
              _InfoTile(
                icon: Icons.monitor_weight_outlined,
                label: 'Peso',
                value: fmt(player['weight']),
              ),
            if (player.containsKey('fatherName') && (player['fatherName'] as String).isNotEmpty)
              _InfoTile(
                icon: Icons.person,
                label: 'Tutor/a 1',
                value: fmt(player['fatherName']),
              ),
            if (player.containsKey('motherName') && (player['motherName'] as String).isNotEmpty)
              _InfoTile(
                icon: Icons.person_2,
                label: 'Tutor/a 2',
                value: fmt(player['motherName']),
              ),
            if (player.containsKey('phone1') && (player['phone1'] as String).isNotEmpty)
              _InfoTile(
                icon: Icons.phone,
                label: 'Teléfono 1',
                value: fmt(player['phone1']),
              ),
            if (player.containsKey('phone2') && (player['phone2'] as String).isNotEmpty)
              _InfoTile(
                icon: Icons.phone_android,
                label: 'Teléfono 2',
                value: fmt(player['phone2']),
              ),
          ].asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: e.value
                  .animate(delay: (e.key * 60).ms)
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.03),
            );
          }).toList(),
    );
  }

  Widget _buildMedicalTab(Map<String, dynamic> player) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Medical status card
        JNCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.success.withValues(alpha: 0.08),
              context.colors.surfaceLight,
            ],
          ),
          border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.verified,
                  size: 28,
                  color: context.colors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apto médico vigente',
                      style: context.typography.titleLarge.copyWith(
                        color: context.colors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Última revisión: 15 Mar 2026',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms),

        const SizedBox(height: 16),

        if (player.containsKey('bloodType'))
          _InfoTile(
            icon: Icons.bloodtype,
            label: 'Grupo sanguíneo',
            value: player['bloodType'] as String,
          ),
        if (player.containsKey('height'))
          _InfoTile(
            icon: Icons.height,
            label: 'Altura',
            value: player['height'] as String,
          ),
        if (player.containsKey('weight'))
          _InfoTile(
            icon: Icons.monitor_weight_outlined,
            label: 'Peso',
            value: player['weight'] as String,
          ),

        const SizedBox(height: 16),
        Text('Observaciones', style: context.typography.headlineSmall),
        const SizedBox(height: 8),
        JNCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sin alergias conocidas. Última revisión médica sin observaciones. Apto para actividad física completa.',
            style: context.typography.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  const _QuickStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: context.typography.headlineMedium),
        Text(label, style: context.typography.labelSmall),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return JNCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: context.colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: context.typography.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: context.typography.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color? color;
  const _PerformanceRow({
    required this.label,
    required this.value,
    this.maxValue = 1.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: context.typography.bodySmall),
            Text(
              value.toStringAsFixed(2),
              style: context.typography.labelMedium.copyWith(color: c),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (value / maxValue).clamp(0.0, 1.0),
            backgroundColor: context.colors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(c),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: context.colors.background, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}