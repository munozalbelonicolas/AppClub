import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String _selectedFilter = 'Todos';
  late DateTime _selectedDate;
  late DateTime _currentMonth;

  final filters = ['Todos', 'Partidos', 'Entrenamientos', 'Eventos', 'Cumpleaños'];

  final List<String> _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectedDate = _currentMonth;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectedDate = _currentMonth;
    });
  }

  void _setToday() {
    setState(() {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _currentMonth = DateTime(now.year, now.month, 1);
    });
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _getFilteredEvents(List<Map<String, dynamic>> events) {
    final selectedDateStr = _formatDateString(_selectedDate);
    return events.where((e) {
      if (e['date'] != selectedDateStr) return false;
      
      if (_selectedFilter == 'Todos') return true;
      if (_selectedFilter == 'Partidos') return e['type'] == 'match';
      if (_selectedFilter == 'Entrenamientos') return e['type'] == 'training';
      if (_selectedFilter == 'Eventos') return e['type'] == 'event';
      if (_selectedFilter == 'Cumpleaños') return e['type'] == 'birthday';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsStreamProvider);
    final matchesAsync = ref.watch(matchesStreamProvider);
    final playersAsync = ref.watch(playersStreamProvider);

    final rawEvents = eventsAsync.valueOrNull ?? [];
    final rawMatches = matchesAsync.valueOrNull ?? [];
    final rawPlayers = playersAsync.valueOrNull ?? [];

    final List<Map<String, dynamic>> allEvents = [];

    for (final e in rawEvents) {
      final modifiedEvent = Map<String, dynamic>.from(e);
      if (modifiedEvent['eventCategory'] != null) {
        modifiedEvent['category'] = modifiedEvent['eventCategory'];
      }
      allEvents.add(modifiedEvent);
    }

    for (final m in rawMatches) {
      final date = m['date'] as String?;
      if (date == null) continue;
      allEvents.add({
        'title': '${m['homeTeam']} vs ${m['awayTeam']}',
        'type': 'match',
        'date': date,
        'time': m['time'] ?? '',
        'location': m['location'] ?? 'Cancha',
        'category': m['category'] ?? '',
      });
    }

    for (final p in rawPlayers) {
      if (p['birthDate'] != null) {
        final birthDate = (p['birthDate'] as Timestamp).toDate();
        final dateStr = '${_currentMonth.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
        final name = '${p['name'] ?? ''} ${p['lastName'] ?? ''}'.trim();
        final age = _currentMonth.year - birthDate.year;
        
        allEvents.add({
          'title': 'Cumpleaños de $name ($age años)',
          'type': 'birthday',
          'date': dateStr,
          'time': 'Todo el día',
          'location': '',
          'category': p['category'] ?? '',
        });
      }
    }

    final filteredEvents = _getFilteredEvents(allEvents);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, size: 22),
            onPressed: _setToday,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Month Header ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: context.colors.textSecondary),
                  onPressed: _prevMonth,
                ),
                Text('${_monthNames[_currentMonth.month]} ${_currentMonth.year}', style: context.typography.headlineMedium),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: context.colors.textSecondary),
                  onPressed: _nextMonth,
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
          ),

          // ─── Week Days Header ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: context.typography.labelSmall.copyWith(
                            color: context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ─── Calendar Grid ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildCalendarGrid(allEvents),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ─── Filters ──────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = filters[index];
                final isActive = _selectedFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? context.colors.primary
                          : context.colors.surfaceLight,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusRound,
                      ),
                      border: Border.all(
                        color: isActive ? context.colors.primary : context.colors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      f,
                      style: context.typography.labelMedium.copyWith(
                        color: isActive
                            ? Colors.white
                            : context.colors.textSecondary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ─── Events List ──────────────────────────
          Expanded(
            child: filteredEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay eventos para este día',
                            style: context.typography.titleMedium.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filteredEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return _CalendarEventCard(
                            title: event['title'] as String,
                            type: event['type'] as String,
                            date: event['date'] as String,
                            time: event['time'] as String,
                            location: event['location'] as String,
                            category: event['category'] as String,
                          )
                          .animate(delay: (100 + index * 60).ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: 0.03);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(List<Map<String, dynamic>> allEvents) {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)

    final eventDates = allEvents.map((e) => e['date'] as String).toSet();
    final matchDates = allEvents.where((e) => e['type'] == 'match').map((e) => e['date'] as String).toSet();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: daysInMonth + startWeekday - 1,
      itemBuilder: (context, index) {
        if (index < startWeekday - 1) return const SizedBox();

        final day = index - startWeekday + 2;
        if (day > daysInMonth) return const SizedBox();

        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final dateStr = _formatDateString(date);

        final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
        final now = DateTime.now();
        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
        final hasEvent = eventDates.contains(dateStr);
        final hasMatch = matchDates.contains(dateStr);

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primary
                  : isToday
                  ? context.colors.surfaceVariant
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: context.typography.titleSmall.copyWith(
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? context.colors.accent
                        : context.colors.textPrimary,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                if (hasEvent && !isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasMatch ? context.colors.primary : context.colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  final String title;
  final String type;
  final String date;
  final String time;
  final String location;
  final String category;

  const _CalendarEventCard({
    required this.title,
    required this.type,
    required this.date,
    required this.time,
    required this.location,
    required this.category,
  });

  Color _color(BuildContext context) {
    switch (type) {
      case 'match':
        return context.colors.primary;
      case 'training':
        return context.colors.success;
      case 'birthday':
        return context.colors.warning;
      default:
        return context.colors.accent;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'match':
        return Icons.sports_soccer;
      case 'training':
        return Icons.fitness_center;
      case 'birthday':
        return Icons.cake;
      default:
        return Icons.event;
    }
  }

  String get _typeLabel {
    switch (type) {
      case 'match':
        return 'PARTIDO';
      case 'training':
        return 'ENTRENAMIENTO';
      case 'birthday':
        return 'CUMPLEAÑOS';
      default:
        return 'EVENTO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return JNCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    JNBadge(
                      label: _typeLabel,
                      type: type == 'match'
                          ? JNBadgeType.error
                          : type == 'training'
                          ? JNBadgeType.success
                          : type == 'birthday'
                          ? JNBadgeType.warning
                          : JNBadgeType.accent,
                      small: true,
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      JNBadge(
                        label: category.toUpperCase(),
                        small: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: context.typography.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: context.colors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(time, style: context.typography.bodySmall),
                    if (location.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: context.typography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}