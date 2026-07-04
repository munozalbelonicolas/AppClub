import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

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

    return Scaffold(
      backgroundColor: context.colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: context.colors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPlayerHeader(player),
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
            _buildStatsTab(player),
            _buildInfoTab(player),
            _buildMedicalTab(player),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader(Map<String, dynamic> player) {
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
              number: player['number'] as int,
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
                JNBadge(
                  label: player['category'] as String,
                  type: JNBadgeType.accent,
                ),
                const SizedBox(width: 8),
                JNBadge(
                  label: player['position'] as String,
                ),
                const SizedBox(width: 8),
                JNBadge(label: '#${player['number']}', type: JNBadgeType.info),
              ],
            ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

            const SizedBox(height: 16),

            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickStat(value: '${player['goals']}', label: 'Goles'),
                Container(width: 1, height: 30, color: context.colors.border),
                _QuickStat(value: '${player['assists']}', label: 'Asistencias'),
                Container(width: 1, height: 30, color: context.colors.border),
                _QuickStat(value: '${player['matches']}', label: 'Partidos'),
                Container(width: 1, height: 30, color: context.colors.border),
                _QuickStat(
                  value: '${player['attendance']}%',
                  label: 'Asistencia',
                ),
              ],
            ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(Map<String, dynamic> player) {
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
              value: '${player['goals']}',
              label: 'Goles',
              icon: Icons.sports_soccer,
              color: context.colors.primary,
            ),
            JNStatCard(
              value: '${player['assists']}',
              label: 'Asistencias',
              icon: Icons.handshake,
              color: context.colors.accent,
            ),
            JNStatCard(
              value: '${player['matches']}',
              label: 'Partidos',
              icon: Icons.stadium,
              color: context.colors.info,
            ),
            JNStatCard(
              value: '${player['yellowCards']}',
              label: 'Amarillas',
              icon: Icons.square,
              color: context.colors.warning,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        // Attendance ring
        Text('Asistencia general', style: context.typography.headlineSmall),
        const SizedBox(height: 16),
        Center(
              child: CircularPercentIndicator(
                radius: 70,
                lineWidth: 8,
                percent: (player['attendance'] as int) / 100,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${player['attendance']}%',
                      style: context.typography.headlineLarge.copyWith(
                        color: context.colors.success,
                      ),
                    ),
                    Text('asistencia', style: context.typography.bodySmall),
                  ],
                ),
                progressColor: context.colors.success,
                backgroundColor: context.colors.surfaceVariant,
                circularStrokeCap: CircularStrokeCap.round,
              ),
            )
            .animate(delay: 200.ms)
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.9, 0.9)),

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children:
          [
            _InfoTile(
              icon: Icons.cake,
              label: 'Edad',
              value: '${player['age']} años',
            ),
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Fecha de nacimiento',
              value: player['birthDate'] as String,
            ),
            _InfoTile(
              icon: Icons.sports,
              label: 'Posición',
              value: player['position'] as String,
            ),
            _InfoTile(
              icon: Icons.numbers,
              label: 'Dorsal',
              value: '#${player['number']}',
            ),
            _InfoTile(
              icon: Icons.category,
              label: 'Categoría',
              value: player['category'] as String,
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
            if (player.containsKey('parentName'))
              _InfoTile(
                icon: Icons.person,
                label: 'Padre/Madre',
                value: player['parentName'] as String,
              ),
            if (player.containsKey('parentPhone'))
              _InfoTile(
                icon: Icons.phone,
                label: 'Teléfono',
                value: player['parentPhone'] as String,
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
          Expanded(child: Text(label, style: context.typography.bodyMedium)),
          Text(value, style: context.typography.titleSmall),
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