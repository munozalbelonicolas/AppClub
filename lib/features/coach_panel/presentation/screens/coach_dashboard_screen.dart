import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_section_header.dart';
import '../../../../core/widgets/jn_stat_card.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../lineup/presentation/screens/lineup_screen.dart';
import '../../../player/presentation/screens/consolidated_roster_screen.dart';
import '../../../results/presentation/screens/manage_scorers_screen.dart';
import 'create_coach_report_screen.dart';
import 'formation_screen.dart';

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final playersAsync = ref.watch(playersStreamProvider);
    final List<Map<String, dynamic>> allPlayers = (playersAsync.valueOrNull ?? [])
        .where((p) => p['role'] == null || p['role'] == 'jugador')
        .where((p) => p['role'] != 'directivo' && p['role'] != 'secretario' && p['role'] != 'dt' && p['role'] != 'tutor' && p['role'] != 'socio')
        .toList();
    
    // Filter players by assignedCategories or category
    final List<Map<String, dynamic>> players = allPlayers.where((p) {
      if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
        return sessionUser.assignedCategories!.contains(p['category']);
      }
      return p['category'] == sessionUser.category;
    }).toList();
    
    final String activeCat = (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty)
        ? sessionUser.assignedCategories!.first
        : (sessionUser.category ?? '');
    final Map<String, dynamic>? nextMatch = ref.watch(nextMatchProvider(activeCat));
    final clubs = ref.watch(clubsStreamProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Panel DT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            tooltip: 'Programar Partido',
            onPressed: () => _showCreateMatchDialog(context, ref, sessionUser, clubs),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Coach Header ─────────────────────────
          JNCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                JNAvatar(
                  name: '${sessionUser.name} ${sessionUser.lastName}',
                  size: 50,
                  borderColor: context.colors.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DT ${sessionUser.name} ${sessionUser.lastName}',
                        style: context.typography.titleLarge,
                      ),
                      Text(
                        '${sessionUser.assignedCategories?.join(', ') ?? sessionUser.category ?? 'Sin categoría'} • Temporada ${DateTime.now().year}',
                        style: context.typography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const JNBadge(label: 'DT', type: JNBadgeType.accent),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ─── Team Stats Overview ──────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              JNStatCard(
                value: '${players.length}',
                label: 'Jugadores',
                icon: Icons.groups,
                color: context.colors.info,
              ),
              JNStatCard(
                value: '13',
                label: 'Puntos',
                icon: Icons.emoji_events,
                color: context.colors.accent,
              ),
              JNStatCard(
                value: '1°',
                label: 'Posición',
                icon: Icons.leaderboard,
                color: context.colors.success,
              ),
              JNStatCard(
                value: '5',
                label: 'Partidos',
                icon: Icons.sports_soccer,
                color: context.colors.primary,
              ),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),
          JNCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              );
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.how_to_reg, color: context.colors.accent, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Control de Asistencia e Historial', style: context.typography.titleMedium),
                      Text('Tomar asistencia por fecha y consultar historial cargado', style: context.typography.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          JNCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConsolidatedRosterScreen()),
              );
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: context.colors.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consolidado de Jugadores', style: context.typography.titleMedium),
                      Text('Listado completo y exportación a Excel', style: context.typography.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          JNCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LineupScreen()),
              );
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.shield, color: context.colors.accent, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Formación & Alineación de Equipo', style: context.typography.titleMedium),
                      Text('Gestionar titulares y convocatoria para el próximo partido', style: context.typography.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Next Match Actions ───────────────────
          JNSectionHeader(
            title: 'Próximo partido',
            actionLabel: '+ Programar Partido',
            onAction: () => _showCreateMatchDialog(context, ref, sessionUser, clubs),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          if (nextMatch != null) ...[
            JNCard(
              padding: const EdgeInsets.all(16),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.sports_soccer,
                              size: 18,
                              color: context.colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${nextMatch['homeTeam']} vs ${nextMatch['awayTeam']}',
                                style: context.typography.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: context.colors.primary, size: 20),
                        tooltip: 'Editar Partido',
                        onPressed: () => _showEditMatchDialog(context, ref, sessionUser, clubs, nextMatch),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: context.colors.error, size: 20),
                        tooltip: 'Eliminar Partido',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar Partido'),
                              content: const Text('¿Estás seguro de que deseas eliminar este partido programado?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            if (nextMatch['source'] == 'novedad') {
                              await ref.read(firestoreServiceProvider).deleteNovedad(nextMatch['id']);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${nextMatch['date']} · ${nextMatch['time']} · ${nextMatch['venue']}',
                    style: context.typography.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.list_alt,
                          label: 'Convocatoria',
                          color: context.colors.primary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.format_list_numbered,
                          label: 'Formación',
                          color: context.colors.accent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FormationScreen(matchId: nextMatch['id']),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.note_add,
                          label: 'Notas',
                          color: context.colors.info,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
          ] else ...[
            JNCard(
              padding: const EdgeInsets.all(16),
              onTap: () => _showCreateMatchDialog(context, ref, sessionUser, clubs),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: context.colors.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sin partido programado', style: context.typography.titleMedium),
                        Text('Toca aquí para definir la fecha del próximo partido', style: context.typography.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.colors.textTertiary),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ─── Squad ────────────────────────────────
          JNSectionHeader(
            title: 'Plantel ${sessionUser.assignedCategories?.join(', ') ?? sessionUser.category ?? 'Sin categoría'}',
            actionLabel: '${players.length} jugadores',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          if (players.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.groups, size: 48, color: context.colors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      'No hay jugadores registrados en esta(s) categoría(s)',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          ...players.asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  JNCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            JNAvatar(
                              name: '${player['name']} ${player['lastName']}',
                              size: 40,
                              number: player['number'] != null ? int.tryParse(player['number'].toString()) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${player['name']} ${player['lastName']}',
                                    style: context.typography.titleSmall,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        player['position']?.toString() ?? 'Sin Posición',
                                        style: context.typography.bodySmall,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('·', style: context.typography.bodySmall),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${player['age'] ?? '-'} años',
                                        style: context.typography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sports_soccer,
                                      size: 12,
                                      color: context.colors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${player['goals'] ?? 0}',
                                      style: context.typography.labelMedium.copyWith(
                                        color: context.colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${player['attendance'] ?? 0}%',
                                  style: context.typography.bodySmall.copyWith(
                                    color: (int.tryParse(player['attendance']?.toString() ?? '0') ?? 0) >= 90
                                        ? context.colors.success
                                        : context.colors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate(delay: (300 + index * 60).ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.03),
            );
          }),

          const SizedBox(height: 24),

          // ─── Comunicación Institucional ─────────────
          const JNSectionHeader(
            title: 'Comunicación Institucional',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          JNCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envía informes o novedades importantes directamente a la directiva del club.',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateCoachReportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar Informe a Directiva'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Gestión de Goleadores ─────────────
          const JNSectionHeader(
            title: 'Gestión Deportiva',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          JNCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageScorersScreen(),
                ),
              );
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sports_soccer, color: context.colors.accent, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Goleadores por Categoría', style: context.typography.titleMedium),
                      Text('Gestionar la tabla de goleadores de la liga.', style: context.typography.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.textTertiary),
              ],
            ),
          ).animate(delay: 550.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: context.typography.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

void _showCreateMatchDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic sessionUser,
  List<Map<String, dynamic>> clubs,
) {
  final titleController = TextEditingController(text: 'Partido Amistoso');
  final bodyController = TextEditingController(text: 'Convocatoria y detalles del partido');
  final venueController = TextEditingController(text: 'Cancha Principal JN');
  final formKey = GlobalKey<FormState>();

  DateTime? eventDate;
  TimeOfDay? eventTime;
  bool hasTransport = false;
  String? selectedOpponentId;
  String selectedCategory = (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty)
      ? sessionUser.assignedCategories!.first
      : (sessionUser.category ?? 'Sub-12');

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(color: context.colors.border, width: 0.5),
            ),
            title: Text(
              'Programar Nuevo Partido',
              style: context.typography.titleLarge,
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: titleController,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Título de la novedad',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ingresa un título'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyController,
                      maxLines: 2,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Detalles / Descripción',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Fecha del Partido
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: eventDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            eventDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Partido *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          eventDate != null
                              ? '${eventDate!.day.toString().padLeft(2, '0')}/${eventDate!.month.toString().padLeft(2, '0')}/${eventDate!.year}'
                              : 'Seleccionar Fecha',
                          style: context.typography.bodyLarge.copyWith(
                            color: eventDate != null ? null : context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hora del Partido
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: eventTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            eventTime = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora del Partido',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          eventTime != null
                              ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')} hs'
                              : 'Seleccionar Hora',
                          style: context.typography.bodyLarge.copyWith(
                            color: eventTime != null ? null : context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: venueController,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Lugar / Cancha',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      dropdownColor: context.colors.surface,
                      initialValue: selectedOpponentId,
                      decoration: const InputDecoration(
                        labelText: 'Club Rival (Opcional)',
                      ),
                      items: clubs.where((c) => c['isLocal'] != true).map((club) {
                        return DropdownMenuItem<String>(
                          value: club['id'],
                          child: Text(club['name'], style: context.typography.bodyLarge),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedOpponentId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Row(
                        children: [
                          Icon(Icons.directions_bus, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Traslado Incluido'),
                        ],
                      ),
                      value: hasTransport,
                      activeThumbColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          hasTransport = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    if (eventDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor selecciona la fecha del partido')),
                      );
                      return;
                    }
                    final firestoreService = ref.read(firestoreServiceProvider);
                    final dateStr = '${eventDate!.year}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}';
                    final timeStr = eventTime != null
                        ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')} hs'
                        : 'A confirmar';
                    final venueStr = venueController.text.trim().isNotEmpty
                        ? venueController.text.trim()
                        : 'Cancha Principal JN';

                    await firestoreService.addNovedad({
                      'title': titleController.text.trim(),
                      'body': bodyController.text.trim(),
                      'category': selectedCategory,
                      'authorId': sessionUser.id,
                      'authorName': '${sessionUser.name} ${sessionUser.lastName}',
                      'authorRole': sessionUser.role,
                      'isMatch': true,
                      'eventType': 'partido',
                      'hasTransport': hasTransport,
                      'opponentClubId': selectedOpponentId,
                      'eventDate': dateStr,
                      'date': dateStr,
                      'eventTime': timeStr,
                      'time': timeStr,
                      'location': venueStr,
                      'venue': venueStr,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Partido programado con éxito!'),
                          backgroundColor: context.colors.success,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Programar'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showEditMatchDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic sessionUser,
  List<Map<String, dynamic>> clubs,
  Map<String, dynamic> match,
) {
  final titleController = TextEditingController(text: match['title'] ?? match['homeTeam'] != null ? '${match['homeTeam']} vs ${match['awayTeam']}' : 'Partido');
  final bodyController = TextEditingController(text: match['body'] ?? '');
  final venueController = TextEditingController(text: match['venue'] ?? match['location'] ?? 'Cancha Principal JN');
  final formKey = GlobalKey<FormState>();

  DateTime? eventDate;
  if (match['date'] != null) {
    try {
      final parts = (match['date'] as String).split('-');
      if (parts.length == 3) {
        eventDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}
  }
  eventDate ??= DateTime.now();

  TimeOfDay? eventTime;
  if (match['time'] != null) {
    try {
      final cleanTime = (match['time'] as String).replaceAll('hs', '').trim();
      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        eventTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
  }
  eventTime ??= const TimeOfDay(hour: 15, minute: 0);

  bool hasTransport = match['hasTransport'] == true;
  String? selectedOpponentId = match['opponentClubId'];
  String selectedCategory = match['category'] ?? (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty
      ? sessionUser.assignedCategories!.first
      : (sessionUser.category ?? 'Sub-12'));

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(color: context.colors.border, width: 0.5),
            ),
            title: Text(
              'Editar Partido',
              style: context.typography.titleLarge,
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: titleController,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Título del partido / novedad',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ingresa un título'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyController,
                      maxLines: 2,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Detalles / Descripción',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Fecha del Partido
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: eventDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          locale: const Locale('es', 'ES'),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            eventDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Partido *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          eventDate != null
                              ? '${eventDate!.day.toString().padLeft(2, '0')}/${eventDate!.month.toString().padLeft(2, '0')}/${eventDate!.year}'
                              : 'Seleccionar Fecha',
                          style: context.typography.bodyLarge.copyWith(
                            color: eventDate != null ? null : context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hora del Partido
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: eventTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            eventTime = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora del Partido',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          eventTime != null
                              ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')} hs'
                              : 'Seleccionar Hora',
                          style: context.typography.bodyLarge.copyWith(
                            color: eventTime != null ? null : context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: venueController,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Lugar / Cancha',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      dropdownColor: context.colors.surface,
                      initialValue: selectedOpponentId,
                      decoration: const InputDecoration(
                        labelText: 'Club Rival (Opcional)',
                      ),
                      items: clubs.where((c) => c['isLocal'] != true).map((club) {
                        return DropdownMenuItem<String>(
                          value: club['id'],
                          child: Text(club['name'], style: context.typography.bodyLarge),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedOpponentId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Row(
                        children: [
                          Icon(Icons.directions_bus, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Traslado Incluido'),
                        ],
                      ),
                      value: hasTransport,
                      activeThumbColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          hasTransport = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    if (eventDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor selecciona la fecha del partido')),
                      );
                      return;
                    }
                    final firestoreService = ref.read(firestoreServiceProvider);
                    final dateStr = '${eventDate!.year}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}';
                    final timeStr = eventTime != null
                        ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')} hs'
                        : 'A confirmar';
                    final venueStr = venueController.text.trim().isNotEmpty
                        ? venueController.text.trim()
                        : 'Cancha Principal JN';

                    if (match['source'] == 'novedad') {
                      await firestoreService.updateNovedad(match['id'], {
                        'title': titleController.text.trim(),
                        'body': bodyController.text.trim(),
                        'category': selectedCategory,
                        'hasTransport': hasTransport,
                        'opponentClubId': selectedOpponentId,
                        'eventDate': dateStr,
                        'date': dateStr,
                        'eventTime': timeStr,
                        'time': timeStr,
                        'location': venueStr,
                        'venue': venueStr,
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Partido actualizado correctamente!'),
                          backgroundColor: context.colors.success,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Guardar Cambios'),
              ),
            ],
          );
        },
      );
    },
  );
}