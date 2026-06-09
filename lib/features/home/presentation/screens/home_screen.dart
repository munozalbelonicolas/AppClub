import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_match_card.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_section_header.dart';
import '../../../../data/mock/mock_data.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;
    final player = MockData.currentPlayer;
    final nextMatch = MockData.nextMatch;
    final pendingPayment = MockData.payments.firstWhere((p) => p['status'] == 'pending');
    final unreadAnnouncements = MockData.announcements.where((a) => a['read'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, ${user['name']} 👋',
                            style: AppTypography.headlineLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${player['name']} ${player['lastName']} · ${player['category']}',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onNavigate(4), // settings
                      child: JNAvatar(
                        name: '${user['name']} ${user['lastName']}',
                        size: 44,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ─── Next Match Banner ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: JNMatchCard(
                  homeTeam: nextMatch['homeTeam'] as String,
                  awayTeam: nextMatch['awayTeam'] as String,
                  homeScore: nextMatch['homeScore'] as int?,
                  awayScore: nextMatch['awayScore'] as int?,
                  date: _formatDate(nextMatch['date'] as String),
                  time: nextMatch['time'] as String,
                  venue: nextMatch['venue'] as String,
                  status: nextMatch['status'] as String,
                  isHero: true,
                  onTap: () => onNavigate(3),
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.05),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ─── Quick Actions ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.how_to_reg,
                      label: 'Asistencia',
                      color: AppColors.success,
                      badge: null,
                      onTap: () => onNavigate(1),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.payment,
                      label: 'Cuotas',
                      color: AppColors.accent,
                      badge: '1',
                      onTap: () => onNavigate(2),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.calendar_month,
                      label: 'Calendario',
                      color: AppColors.info,
                      badge: null,
                      onTap: () => onNavigate(1),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.campaign,
                      label: 'Noticias',
                      color: AppColors.primary,
                      badge: unreadAnnouncements > 0 ? '$unreadAnnouncements' : null,
                      onTap: () => onNavigate(2),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Payment Status ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: JNCard(
                  onTap: () => onNavigate(2),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, size: 22, color: AppColors.warning),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cuota ${pendingPayment['month']}', style: AppTypography.titleMedium),
                            Text(
                              'Vence el ${_formatDate(pendingPayment['dueDate'] as String)}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_formatNumber(pendingPayment['amount'] as int)}',
                            style: AppTypography.titleLarge.copyWith(color: AppColors.warning),
                          ),
                          JNBadge.pending(),
                        ],
                      ),
                    ],
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideX(begin: 0.03),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Player Quick Stats ─────────────────────
            SliverToBoxAdapter(
              child: JNSectionHeader(
                title: 'Estadísticas de ${player['name']}',
                actionLabel: 'Ver perfil',
                onAction: () {},
              ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _MiniStatCard(value: '${player['goals']}', label: 'Goles', icon: Icons.sports_soccer, color: AppColors.primary),
                    const SizedBox(width: 10),
                    _MiniStatCard(value: '${player['assists']}', label: 'Asistencias', icon: Icons.handshake, color: AppColors.accent),
                    const SizedBox(width: 10),
                    _MiniStatCard(value: '${player['matches']}', label: 'Partidos', icon: Icons.stadium, color: AppColors.info),
                    const SizedBox(width: 10),
                    _MiniStatCard(value: '${player['attendance']}%', label: 'Asistencia', icon: Icons.check_circle, color: AppColors.success),
                  ],
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Upcoming Events ────────────────────────
            SliverToBoxAdapter(
              child: JNSectionHeader(
                title: 'Próximos eventos',
                actionLabel: 'Ver todos',
                onAction: () => onNavigate(1),
              ).animate(delay: 450.ms).fadeIn(duration: 400.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final events = MockData.calendarEvents.take(3).toList();
                  if (index >= events.length) return null;
                  final event = events[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _EventTile(
                      title: event['title'] as String,
                      type: event['type'] as String,
                      date: _formatDate(event['date'] as String),
                      time: event['time'] as String,
                      location: event['location'] as String,
                    ).animate(delay: (500 + index * 80).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03),
                  );
                },
                childCount: 3,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Recent Results ─────────────────────────
            SliverToBoxAdapter(
              child: JNSectionHeader(
                title: 'Últimos resultados',
                actionLabel: 'Ver todos',
                onAction: () => onNavigate(3),
              ).animate(delay: 650.ms).fadeIn(duration: 400.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final played = MockData.matches.where((m) => m['status'] == 'played').toList().reversed.toList();
                  if (index >= played.length || index >= 3) return null;
                  final match = played[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: JNMatchCard(
                      homeTeam: match['homeTeam'] as String,
                      awayTeam: match['awayTeam'] as String,
                      homeScore: match['homeScore'] as int?,
                      awayScore: match['awayScore'] as int?,
                      date: _formatDate(match['date'] as String),
                      time: match['time'] as String,
                      status: 'played',
                    ).animate(delay: (700 + index * 80).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03),
                  );
                },
                childCount: 3,
              ),
            ),

            // ─── Announcements ──────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            SliverToBoxAdapter(
              child: JNSectionHeader(
                title: 'Comunicados',
                actionLabel: 'Ver todos',
                onAction: () => onNavigate(2),
              ).animate(delay: 850.ms).fadeIn(duration: 400.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final announcements = MockData.announcements.take(2).toList();
                  if (index >= announcements.length) return null;
                  final ann = announcements[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _AnnouncementCard(
                      title: ann['title'] as String,
                      body: ann['body'] as String,
                      date: _formatDate(ann['date'] as String),
                      category: ann['category'] as String,
                      priority: ann['priority'] as String,
                      isRead: ann['read'] as bool,
                    ).animate(delay: (900 + index * 80).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03),
                  );
                },
                childCount: 2,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final day = int.parse(parts[2]);
    final month = int.parse(parts[1]);
    return '$day ${months[month]}';
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k'.replaceAll('.', '.');
    }
    return number.toString();
  }
}

// ─── Quick Action Button ──────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: JNCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mini Stat Card ─────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return JNCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTypography.headlineMedium.copyWith(color: color)),
              Text(label.toUpperCase(), style: AppTypography.statLabel),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Event Tile ──────────────────────────────────────
class _EventTile extends StatelessWidget {
  final String title;
  final String type;
  final String date;
  final String time;
  final String location;

  const _EventTile({
    required this.title,
    required this.type,
    required this.date,
    required this.time,
    required this.location,
  });

  Color get _typeColor {
    switch (type) {
      case 'match':
        return AppColors.primary;
      case 'training':
        return AppColors.success;
      default:
        return AppColors.accent;
    }
  }

  IconData get _typeIcon {
    switch (type) {
      case 'match':
        return Icons.sports_soccer;
      case 'training':
        return Icons.fitness_center;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return JNCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: _typeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon, size: 18, color: _typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '$date · $time',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

// ─── Announcement Card ──────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String body;
  final String date;
  final String category;
  final String priority;
  final bool isRead;

  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.date,
    required this.category,
    required this.priority,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return JNCard(
      border: !isRead
          ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1)
          : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(title, style: AppTypography.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(date, style: AppTypography.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              JNBadge(
                label: category.toUpperCase(),
                type: category == 'deportivo'
                    ? JNBadgeType.accent
                    : category == 'administrativo'
                        ? JNBadgeType.info
                        : JNBadgeType.neutral,
                small: true,
              ),
              if (priority == 'high') ...[
                const SizedBox(width: 6),
                const JNBadge(label: 'IMPORTANTE', type: JNBadgeType.error, small: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
