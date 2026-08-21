import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/session_provider.dart';
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
    _currentMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = _currentMonth;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = _currentMonth;
    });
  }

  void _setToday() {
    setState(() {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _currentMonth = DateTime(now.year, now.month);
    });
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _getDayCode(String d) {
    final clean = d.toLowerCase().trim();
    if (clean.startsWith('lun')) return DateTime.monday;
    if (clean.startsWith('mar')) return DateTime.tuesday;
    if (clean.startsWith('mié') || clean.startsWith('mie')) return DateTime.wednesday;
    if (clean.startsWith('jue')) return DateTime.thursday;
    if (clean.startsWith('vie')) return DateTime.friday;
    if (clean.startsWith('sáb') || clean.startsWith('sab')) return DateTime.saturday;
    if (clean.startsWith('dom')) return DateTime.sunday;
    return -1;
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
    final sessionUser = ref.watch(currentUserProvider);
    final bool isAdmin = sessionUser?.isAdmin ?? false;
    final Set<String> allowedCategories = {};

    if (!isAdmin && sessionUser != null) {
      if (sessionUser.role == 'dt') {
        if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
          allowedCategories.addAll(sessionUser.assignedCategories!);
        } else if (sessionUser.category != null) {
          allowedCategories.add(sessionUser.category!);
        }
      } else if (sessionUser.role == 'jugador') {
        if (sessionUser.category != null) {
          allowedCategories.add(sessionUser.category!);
        }
      } else if (sessionUser.role == 'tutor' || sessionUser.role == 'padre') {
        if (sessionUser.category != null) {
          allowedCategories.add(sessionUser.category!);
        }
        final tutorChildren = ref.watch(tutorPlayersStreamProvider(sessionUser.id)).valueOrNull ?? [];
        for (final child in tutorChildren) {
          final cat = child['category']?.toString();
          if (cat != null && cat.isNotEmpty) {
            allowedCategories.add(cat);
          }
        }
      }
    }

    final eventsAsync = ref.watch(calendarEventsStreamProvider);
    final matchesAsync = ref.watch(matchesStreamProvider);
    final playersAsync = ref.watch(playersStreamProvider);
    final schedulesAsync = ref.watch(allTrainingSchedulesStreamProvider);
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);

    final rawEvents = eventsAsync.valueOrNull ?? [];
    final rawMatches = matchesAsync.valueOrNull ?? [];
    final rawPlayers = playersAsync.valueOrNull ?? [];
    final rawNovedades = ref.watch(allNovedadesStreamProvider).valueOrNull ?? [];
    final rawSchedules = schedulesAsync.valueOrNull ?? [];
    final rawFixtures = fixturesAsync.valueOrNull ?? [];
    final clubs = clubsAsync.valueOrNull ?? [];

    final List<Map<String, dynamic>> allEvents = [];

    for (final e in rawEvents) {
      final modifiedEvent = Map<String, dynamic>.from(e);
      if (modifiedEvent['eventCategory'] != null) {
        modifiedEvent['category'] = modifiedEvent['eventCategory'];
      }
      allEvents.add(modifiedEvent);
    }

    // 1. Partidos y Eventos creados desde Novedades/Comunicados por DT o Admin
    for (final n in rawNovedades) {
      final String? date = n['eventDate'] ?? n['date'] ?? (n['createdAt'] is Timestamp ? DateFormat('yyyy-MM-dd').format((n['createdAt'] as Timestamp).toDate()) : null);
      if (date != null && date.isNotEmpty) {
        final bool isMatch = n['eventType'] == 'partido' || n['isMatch'] == true;
        String title = n['title'] ?? 'Comunicado';

        if (isMatch) {
          String awayTeam = 'Rival';
          if (n['opponentClubId'] != null) {
            final club = clubs.where((c) => c['id'] == n['opponentClubId']).firstOrNull;
            if (club != null && club['name'] != null) {
              awayTeam = club['name'] as String;
            }
          }
          if (awayTeam == 'Rival' && n['title'] != null && n['title'].toString().isNotEmpty) {
            awayTeam = n['title'] as String;
          }
          final catLabel = (n['category'] ?? n['eventCategory'] ?? '').toString();
          final catSuffix = catLabel.isNotEmpty && catLabel != 'all' ? ' (Cat. $catLabel)' : '';
          title = 'Partido Amistoso$catSuffix: Jorge Newbery vs $awayTeam';
        }

        allEvents.add({
          'title': title,
          'type': isMatch ? 'match' : 'event',
          'date': date,
          'time': n['eventTime'] ?? n['time'] ?? 'A confirmar',
          'location': n['location'] ?? n['venue'] ?? 'Cancha Principal JN',
          'category': n['category'] ?? n['eventCategory'] ?? '',
        });
      }
    }

    // 2. Partidos de la colección 'matches'
    for (final m in rawMatches) {
      final date = m['date'] as String?;
      if (date == null || date.isEmpty) continue;
      final mCat = (m['category'] ?? '').toString();
      final catSuffix = mCat.isNotEmpty && mCat != 'all' ? ' (Cat. $mCat)' : '';
      allEvents.add({
        'title': 'Partido$catSuffix: ${m['homeTeam']} vs ${m['awayTeam']}',
        'type': 'match',
        'date': date,
        'time': m['time'] ?? 'A confirmar',
        'location': m['venue'] ?? m['location'] ?? 'Cancha Club',
        'category': mCat,
      });
    }

    // 3. Partidos cargados por el ADMIN en el Fixture
    for (final f in rawFixtures) {
      final matchesList = List<Map<String, dynamic>>.from(f['matches'] ?? []);
      final cat = f['category']?.toString() ?? 'all';

      for (final m in matchesList) {
        final date = m['date'] as String?;
        if (date == null || date.isEmpty) continue;

        final homeClub = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
        final awayClub = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;
        final homeName = homeClub?['name'] ?? 'Jorge Newbery';
        final awayName = awayClub?['name'] ?? 'Rival';
        final matchCat = (m['category'] ?? cat).toString();
        final catSuffix = matchCat.isNotEmpty && matchCat != 'all' ? ' - Cat. $matchCat' : '';

        allEvents.add({
          'title': 'Partido (${f['name'] ?? 'Fixture'}$catSuffix): $homeName vs $awayName',
          'type': 'match',
          'date': date,
          'time': m['time'] ?? 'A confirmar',
          'location': m['venue'] ?? m['location'] ?? 'Cancha Club',
          'category': matchCat,
        });
      }
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

    // Dynamic training events from DT training schedules
    final int daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    for (final schedule in rawSchedules) {
      final category = schedule['category']?.toString() ?? '';
      final time = schedule['time']?.toString() ?? '18:00 hs';
      final location = schedule['location']?.toString() ?? 'Cancha Club';
      final List<dynamic> days = schedule['days'] ?? [];

      final Set<int> targetWeekdays = days
          .map((d) => _getDayCode(d.toString()))
          .where((w) => w != -1)
          .toSet();

      if (targetWeekdays.isEmpty) continue;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        if (targetWeekdays.contains(date.weekday)) {
          final dateStr = _formatDateString(date);
          allEvents.add({
            'title': 'Entrenamiento Categoría $category',
            'type': 'training',
            'date': dateStr,
            'time': time,
            'location': location,
            'category': category,
          });
        }
      }
    }

    if (!isAdmin && allowedCategories.isNotEmpty) {
      allEvents.removeWhere((e) {
        final rawCat = (e['category'] as String?)?.trim().toLowerCase();
        // Eventos o avisos globales sin categoría específica son visibles para todos
        if (rawCat == null ||
            rawCat.isEmpty ||
            rawCat == 'all' ||
            rawCat == 'todos' ||
            rawCat == 'general' ||
            rawCat == 'club' ||
            rawCat == 'deportivo' ||
            rawCat == 'administrativo') {
          return false;
        }

        // Si el partido o evento tiene categoría asignada (ej: 2016), solo mostrar si coincide con la categoría del jugador/usuario
        return !allowedCategories.contains(rawCat);
      });
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
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month);
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