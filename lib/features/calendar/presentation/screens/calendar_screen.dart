import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../data/mock/mock_data.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _selectedFilter = 'Todos';
  int _selectedDay = 14; // June 14 selected by default (match day)

  final filters = ['Todos', 'Partidos', 'Entrenamientos', 'Eventos'];

  List<Map<String, dynamic>> get _filteredEvents {
    return MockData.calendarEvents.where((e) {
      if (_selectedFilter == 'Todos') return true;
      if (_selectedFilter == 'Partidos') return e['type'] == 'match';
      if (_selectedFilter == 'Entrenamientos') return e['type'] == 'training';
      if (_selectedFilter == 'Eventos') return e['type'] == 'event';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, size: 22),
            onPressed: () => setState(() => _selectedDay = DateTime.now().day),
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
                  icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
                Text(
                  'Junio 2026',
                  style: AppTypography.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
          ),

          // ─── Week Days Header ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ─── Calendar Grid ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildCalendarGrid(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
                      border: Border.all(
                        color: isActive ? AppColors.primary : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      f,
                      style: AppTypography.labelMedium.copyWith(
                        color: isActive ? Colors.white : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: _filteredEvents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];
                return _CalendarEventCard(
                  title: event['title'] as String,
                  type: event['type'] as String,
                  date: event['date'] as String,
                  time: event['time'] as String,
                  location: event['location'] as String,
                  category: event['category'] as String,
                ).animate(delay: (300 + index * 60).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // June 2026 starts on Monday (day 1 = Monday)
    final daysInMonth = 30;
    final startWeekday = 1; // Monday = 1

    // Event days for highlighting
    final eventDays = MockData.calendarEvents.map((e) {
      return int.parse((e['date'] as String).split('-')[2]);
    }).toSet();

    final matchDays = MockData.calendarEvents
        .where((e) => e['type'] == 'match')
        .map((e) => int.parse((e['date'] as String).split('-')[2]))
        .toSet();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: daysInMonth + startWeekday - 1,
      itemBuilder: (context, index) {
        if (index < startWeekday - 1) return const SizedBox();

        final day = index - startWeekday + 2;
        if (day > daysInMonth) return const SizedBox();

        final isSelected = day == _selectedDay;
        final hasEvent = eventDays.contains(day);
        final hasMatch = matchDays.contains(day);
        final isToday = day == 8; // June 8

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.surfaceVariant
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: AppTypography.titleSmall.copyWith(
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? AppColors.accent
                            : AppColors.textPrimary,
                    fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (hasEvent && !isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasMatch ? AppColors.primary : AppColors.success,
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

  Color get _color {
    switch (type) {
      case 'match':
        return AppColors.primary;
      case 'training':
        return AppColors.success;
      default:
        return AppColors.accent;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'match':
        return Icons.sports_soccer;
      case 'training':
        return Icons.fitness_center;
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
      default:
        return 'EVENTO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return JNCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 22, color: _color),
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
                              : JNBadgeType.accent,
                      small: true,
                    ),
                    const SizedBox(width: 6),
                    JNBadge(label: category.toUpperCase(), type: JNBadgeType.neutral, small: true),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(time, style: AppTypography.bodySmall),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
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
