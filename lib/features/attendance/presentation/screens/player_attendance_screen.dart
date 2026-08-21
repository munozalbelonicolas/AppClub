import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_card.dart';

class PlayerAttendanceScreen extends ConsumerStatefulWidget {
  final String? playerId;
  final Map<String, dynamic>? initialPlayer;

  const PlayerAttendanceScreen({
    super.key,
    this.playerId,
    this.initialPlayer,
  });

  @override
  ConsumerState<PlayerAttendanceScreen> createState() =>
      _PlayerAttendanceScreenState();
}

class _PlayerAttendanceScreenState
    extends ConsumerState<PlayerAttendanceScreen> {
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    if (widget.playerId != null) {
      _selectedChildId = widget.playerId;
    }
  }

  String _formatDateHuman(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]) ?? 2026;
        final month = int.tryParse(parts[1]) ?? 1;
        final day = int.tryParse(parts[2]) ?? 1;
        final dt = DateTime(year, month, day);

        const weekdayNames = [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
          'Domingo'
        ];
        const monthNames = [
          'Enero',
          'Febrero',
          'Marzo',
          'Abril',
          'Mayo',
          'Junio',
          'Julio',
          'Agosto',
          'Septiembre',
          'Octubre',
          'Noviembre',
          'Diciembre'
        ];

        final weekday = weekdayNames[dt.weekday - 1];
        final monthName = monthNames[dt.month - 1];
        return '$weekday $day de $monthName';
      }
    } catch (_) {}
    return dateStr;
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'present':
      case 'P':
        return const Color(0xFF15803D); // Verde
      case 'absent':
      case 'A':
        return const Color(0xFFB91C1C); // Rojo
      case 'justified':
      case 'J':
        return const Color(0xFFD4AF37); // Dorado
      case 'late':
      case 'T':
        return const Color(0xFF0284C7); // Azul
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'present':
      case 'P':
        return 'Presente';
      case 'absent':
      case 'A':
        return 'Ausente';
      case 'justified':
      case 'J':
        return 'Justificado';
      case 'late':
      case 'T':
        return 'Tardanza';
      default:
        return 'Sin Registro';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'present':
      case 'P':
        return Icons.check_circle;
      case 'absent':
      case 'A':
        return Icons.cancel;
      case 'justified':
      case 'J':
        return Icons.shield;
      case 'late':
      case 'T':
        return Icons.access_time_filled;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: const Text('Asistencia')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isTutor = sessionUser.role == 'tutor';

    if (isTutor) {
      final childrenAsync =
          ref.watch(tutorPlayersStreamProvider(sessionUser.id));

      return childrenAsync.when(
        data: (children) {
          if (children.isEmpty) {
            return Scaffold(
              backgroundColor: context.colors.background,
              appBar: AppBar(
                title: const Text('Control de Asistencia'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off,
                          size: 56, color: context.colors.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes jugadores vinculados a tu cuenta.',
                        style: context.typography.titleMedium.copyWith(
                          color: context.colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Resolve active child
          final globalSelectedChild = ref.watch(selectedChildProvider);
          Map<String, dynamic> activeChild = children.first;

          if (_selectedChildId != null) {
            final match = children
                .where((c) => c['id'] == _selectedChildId)
                .firstOrNull;
            if (match != null) activeChild = match;
          } else if (globalSelectedChild != null) {
            final match = children
                .where((c) => c['id'] == globalSelectedChild['id'])
                .firstOrNull;
            if (match != null) activeChild = match;
          }

          return _buildPlayerAttendanceView(
            context: context,
            player: activeChild,
            availableChildren: children,
            isTutor: true,
          );
        },
        loading: () => Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            title: const Text('Control de Asistencia'),
            backgroundColor: Colors.transparent,
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            title: const Text('Control de Asistencia'),
            backgroundColor: Colors.transparent,
          ),
          body: Center(child: Text('Error cargando datos: $err')),
        ),
      );
    }

    // Direct player login or specific player ID
    final targetPlayerId = widget.playerId ?? sessionUser.id;
    final playerProfileAsync =
        ref.watch(playerProfileStreamProvider(targetPlayerId));

    final Map<String, dynamic> fallbackPlayer = widget.initialPlayer ?? {
      'id': targetPlayerId,
      'name': sessionUser.name,
      'lastName': sessionUser.lastName,
      'category': sessionUser.category ?? '',
      'photoUrl': sessionUser.avatarUrl,
    };

    return playerProfileAsync.when(
      data: (playerData) {
        final Map<String, dynamic> player = playerData ?? fallbackPlayer;
        return _buildPlayerAttendanceView(
          context: context,
          player: player,
          availableChildren: [],
          isTutor: false,
        );
      },
      loading: () => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: const Text('Control de Asistencia'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _buildPlayerAttendanceView(
        context: context,
        player: fallbackPlayer,
        availableChildren: [],
        isTutor: false,
      ),
    );
  }

  Widget _buildPlayerAttendanceView({
    required BuildContext context,
    required Map<String, dynamic> player,
    required List<Map<String, dynamic>> availableChildren,
    required bool isTutor,
  }) {
    final String playerId = player['id']?.toString() ?? '';
    final String playerName =
        '${player['name'] ?? ''} ${player['lastName'] ?? ''}'.trim();
    final String displayName =
        playerName.isNotEmpty ? playerName : 'Jugador';
    final String category = player['category']?.toString() ?? '';
    final String? photoUrl =
        (player['photoUrl'] ?? player['avatarUrl']) as String?;

    final attendanceHistoryAsync = category.isNotEmpty
        ? ref.watch(attendanceHistoryStreamProvider(category))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    final trainingScheduleAsync = category.isNotEmpty
        ? ref.watch(trainingScheduleStreamProvider(category))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: attendanceHistoryAsync.when(
        data: (historyList) {
          // Extract and sort sessions
          final List<Map<String, dynamic>> playerSessions = [];

          for (final doc in historyList) {
            final dateStr = doc['dateStr'] ?? doc['date'] ?? '';
            if (dateStr.isEmpty) continue;

            final formattedDate = doc['formattedDate'] ??
                (dateStr.length >= 10
                    ? '${dateStr.substring(8, 10)}/${dateStr.substring(5, 7)}'
                    : dateStr);

            final records = Map<String, String>.from(
              (doc['records'] as Map<String, dynamic>?)
                      ?.map((k, v) => MapEntry(k, v.toString())) ??
                  {},
            );

            String? status = records[playerId];

            // Fallback to legacy arrays
            if (status == null || status.isEmpty) {
              final presentList =
                  List<String>.from(doc['present'] ?? []);
              final absentList = List<String>.from(doc['absent'] ?? []);
              if (presentList.contains(playerId)) {
                status = 'present';
              } else if (absentList.contains(playerId)) {
                status = 'absent';
              }
            }

            playerSessions.add({
              'dateStr': dateStr,
              'formattedDate': formattedDate,
              'status': status ?? '',
              'rawDoc': doc,
            });
          }

          // ─── Sort descending: Newest to Oldest ───
          playerSessions.sort((a, b) {
            final String dateA = a['dateStr'] ?? '';
            final String dateB = b['dateStr'] ?? '';
            return dateB.compareTo(dateA); // Newest first!
          });

          // Metrics calculation
          int presentCount = 0;
          int absentCount = 0;
          int justifiedCount = 0;
          int totalRecordedSessions = 0;

          for (final s in playerSessions) {
            final st = s['status'] as String?;
            if (st != null && st.isNotEmpty) {
              totalRecordedSessions++;
              if (st == 'present' || st == 'P') presentCount++;
              if (st == 'absent' || st == 'A') absentCount++;
              if (st == 'justified' || st == 'J') justifiedCount++;
            }
          }

          final double attendancePercentage = totalRecordedSessions > 0
              ? (presentCount / totalRecordedSessions) * 100
              : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              // ─── Header: Player Card & Child Switcher ───
              JNCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        JNAvatar(
                          name: displayName,
                          imageUrl: photoUrl,
                          size: 52,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: context.typography.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: context.colors.primary
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      category.isNotEmpty
                                          ? 'Categoría $category'
                                          : 'Sin categoría',
                                      style: TextStyle(
                                        color: context.colors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Multi-child switcher for tutors
                    if (isTutor && availableChildren.length > 1) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cambiar jugador:',
                            style: context.typography.bodySmall.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: playerId,
                              isDense: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                              ),
                              style: context.typography.bodyMedium.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              items: availableChildren.map((c) {
                                final cName =
                                    '${c['name'] ?? ''} ${c['lastName'] ?? ''}'
                                        .trim();
                                final cCat = c['category'] ?? '';
                                return DropdownMenuItem<String>(
                                  value: c['id'] as String,
                                  child: Text('$cName ($cCat)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedChildId = val);
                                  final newChild = availableChildren
                                      .where((c) => c['id'] == val)
                                      .firstOrNull;
                                  if (newChild != null) {
                                    ref
                                        .read(selectedChildProvider.notifier)
                                        .state = newChild;
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

              const SizedBox(height: 14),

              // ─── Training Schedule Info ───
              if (category.isNotEmpty)
                trainingScheduleAsync.when(
                  data: (schedule) {
                    final days =
                        (schedule?['days'] as List<dynamic>?)?.join(', ') ??
                            'No configurados';
                    final time = schedule?['time'] ?? 'Sin horario';
                    final location =
                        schedule?['location'] ?? 'Cancha Principal JN';

                    return JNCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colors.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: context.colors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Entrenamientos Categoría $category',
                                  style: context.typography.titleSmall,
                                ),
                                Text(
                                  'Días: $days · Horario: $time',
                                  style: context.typography.bodySmall.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Lugar: $location',
                                  style: context.typography.bodySmall.copyWith(
                                    color: context.colors.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 400.ms);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

              const SizedBox(height: 16),

              // ─── KPI Stats Summary ───
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Asistencia',
                      value: '${attendancePercentage.toStringAsFixed(0)}%',
                      icon: Icons.percent,
                      color: attendancePercentage >= 75
                          ? const Color(0xFF15803D)
                          : (attendancePercentage >= 50
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFFB91C1C)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Presentes',
                      value: '$presentCount',
                      icon: Icons.check_circle,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Ausentes',
                      value: '$absentCount',
                      icon: Icons.cancel,
                      color: const Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Justificados',
                      value: '$justifiedCount',
                      icon: Icons.shield,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // ─── Section Header ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Historial de Entrenamientos',
                    style: context.typography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${playerSessions.length} fechas',
                      style: context.typography.labelSmall.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── Chronological Attendance List (Newest to Oldest) ───
              if (playerSessions.isEmpty)
                JNCard(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 44,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay registros de asistencia aún para la categoría $category.',
                          style: context.typography.bodyMedium.copyWith(
                            color: context.colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: playerSessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = playerSessions[index];
                    final dateStr = item['dateStr'] as String;
                    final formattedDate = item['formattedDate'] as String;
                    final status = item['status'] as String;

                    final color = _getStatusColor(status);
                    final label = _getStatusLabel(status);
                    final icon = _getStatusIcon(status);
                    final humanDate = _formatDateHuman(dateStr);

                    final bool isLatest = index == 0;

                    return JNCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Status icon container
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 14),
                          // Date and Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      humanDate,
                                      style: context.typography.titleSmall
                                          .copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isLatest) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.colors.accent
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ÚLTIMO',
                                          style: TextStyle(
                                            color: context.colors.accent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fecha: $formattedDate · Categoría $category',
                                  style: context.typography.bodySmall.copyWith(
                                    color: context.colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: status == 'justified' || status == 'J'
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (50 * index).ms).fadeIn(duration: 300.ms);
                  },
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar historial de asistencias: $err'),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.typography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.typography.labelSmall.copyWith(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
