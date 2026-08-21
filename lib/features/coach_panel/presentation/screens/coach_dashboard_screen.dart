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
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../lineup/presentation/screens/lineup_screen.dart';
import '../../../player/presentation/screens/consolidated_roster_screen.dart';
import '../../../results/presentation/screens/manage_scorers_screen.dart';
import 'create_coach_report_screen.dart';
import 'formation_screen.dart';

class CoachDashboardScreen extends ConsumerStatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  ConsumerState<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends ConsumerState<CoachDashboardScreen> {
  String? _selectedCategory; // null or 'Todas' means all assigned categories

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<String> coachCategories = (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty)
        ? List<String>.from(sessionUser.assignedCategories!)
        : (sessionUser.category != null && sessionUser.category!.isNotEmpty
            ? [sessionUser.category!]
            : <String>[]);

    if (_selectedCategory != null && _selectedCategory != 'Todas' && !coachCategories.contains(_selectedCategory)) {
      _selectedCategory = coachCategories.isNotEmpty ? coachCategories.first : 'Todas';
    }

    final isAllSelected = _selectedCategory == null || _selectedCategory == 'Todas';
    final activeCategoriesList = isAllSelected ? coachCategories : [_selectedCategory!];
    final String? effectiveCategory = isAllSelected ? null : _selectedCategory;

    final playersAsync = ref.watch(playersStreamProvider);
    final List<Map<String, dynamic>> allPlayers = (playersAsync.valueOrNull ?? [])
        .where((p) => p['role'] == null || p['role'] == 'jugador')
        .where((p) => p['role'] != 'directivo' && p['role'] != 'secretario' && p['role'] != 'dt' && p['role'] != 'tutor' && p['role'] != 'socio')
        .toList();
    
    // Filter players by activeCategoriesList
    final List<Map<String, dynamic>> players = allPlayers.where((p) {
      if (activeCategoriesList.isNotEmpty) {
        return activeCategoriesList.contains(p['category']);
      }
      return sessionUser.category != null ? p['category'] == sessionUser.category : true;
    }).toList();
    
    final Map<String, dynamic>? nextMatch;
    if (!isAllSelected) {
      nextMatch = ref.watch(nextMatchProvider(_selectedCategory!));
    } else {
      Map<String, dynamic>? soonest;
      for (final cat in coachCategories) {
        final m = ref.watch(nextMatchProvider(cat));
        if (m != null) {
          if (soonest == null) {
            soonest = m;
          } else {
            final dateA = soonest['date']?.toString() ?? '';
            final dateB = m['date']?.toString() ?? '';
            if (dateB.isNotEmpty && (dateA.isEmpty || dateB.compareTo(dateA) < 0)) {
              soonest = m;
            }
          }
        }
      }
      nextMatch = soonest ?? (coachCategories.isEmpty ? ref.watch(nextMatchProvider('')) : null);
    }
    final clubs = ref.watch(clubsStreamProvider).valueOrNull ?? [];


    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Panel DT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            tooltip: 'Programar Partido',
            onPressed: () => _showCreateMatchDialog(
              context,
              ref,
              sessionUser,
              clubs,
              defaultCategory: effectiveCategory,
            ),
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
                        '${coachCategories.isNotEmpty ? coachCategories.join(', ') : (sessionUser.category ?? 'Sin categoría')} • Temporada ${DateTime.now().year}',
                        style: context.typography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const JNBadge(label: 'DT', type: JNBadgeType.accent),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          // ─── Category Filter Selector (if multiple categories) ───────
          if (coachCategories.length > 1) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Todas (${coachCategories.length})'),
                      selected: isAllSelected,
                      selectedColor: context.colors.primary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: isAllSelected ? context.colors.primary : context.colors.border,
                        width: isAllSelected ? 1.5 : 0.5,
                      ),
                      labelStyle: TextStyle(
                        color: isAllSelected ? context.colors.primary : context.colors.textSecondary,
                        fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = 'Todas');
                        }
                      },
                    ),
                  ),
                  ...coachCategories.map((cat) {
                    final isSelected = !isAllSelected && _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Categoría $cat'),
                        selected: isSelected,
                        selectedColor: context.colors.primary.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSelected ? context.colors.primary : context.colors.border,
                          width: isSelected ? 1.5 : 0.5,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? context.colors.primary : context.colors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],

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
                MaterialPageRoute(
                  builder: (_) => LineupScreen(initialCategory: effectiveCategory),
                ),
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
            onAction: () => _showCreateMatchDialog(
              context,
              ref,
              sessionUser,
              clubs,
              defaultCategory: effectiveCategory,
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          if (nextMatch != null) ...[
            Builder(
              builder: (context) {
                final currentMatch = nextMatch!;
                return JNCard(
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
                                    '${currentMatch['homeTeam']} vs ${currentMatch['awayTeam']}',
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
                            onPressed: () => _showEditMatchDialog(context, ref, sessionUser, clubs, currentMatch),
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
                                if (currentMatch['source'] == 'novedad') {
                                  await ref.read(firestoreServiceProvider).deleteNovedad(currentMatch['id']);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (currentMatch['category'] != null && currentMatch['category'].toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Cat. ${currentMatch['category']}',
                                style: context.typography.labelSmall.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              '${currentMatch['date']} · ${currentMatch['time']} · ${currentMatch['venue']}',
                              style: context.typography.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.list_alt,
                              label: 'Convocatoria',
                              color: context.colors.primary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LineupScreen(
                                      initialCategory: effectiveCategory,
                                      initialMatchId: currentMatch['id'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.format_list_numbered,
                              label: 'Formación',
                              color: context.colors.accent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FormationScreen(matchId: currentMatch['id']),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.note_add,
                              label: 'Notas',
                              color: context.colors.info,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateCoachReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
          ] else ...[
            JNCard(
              padding: const EdgeInsets.all(16),
              onTap: () => _showCreateMatchDialog(
                context,
                ref,
                sessionUser,
                clubs,
                defaultCategory: effectiveCategory,
              ),
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
            title: !isAllSelected
                ? 'Plantel Categoría $_selectedCategory'
                : (coachCategories.length > 1
                    ? 'Plantel (${coachCategories.join(', ')})'
                    : 'Plantel ${coachCategories.isNotEmpty ? coachCategories.first : 'General'}'),
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
                                      const SizedBox(width: 6),
                                      Text('·', style: context.typography.bodySmall),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${player['age'] ?? '-'} años',
                                        style: context.typography.bodySmall,
                                      ),
                                      if (isAllSelected && coachCategories.length > 1 && player['category'] != null) ...[
                                        const SizedBox(width: 6),
                                        Text('·', style: context.typography.bodySmall),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: context.colors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Cat. ${player['category']}',
                                            style: context.typography.labelSmall.copyWith(
                                              color: context.colors.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: context.typography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
              ),
            ),
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
  List<Map<String, dynamic>> clubs, {
  String? defaultCategory,
}) {
  final titleController = TextEditingController(text: 'Partido Amistoso');
  final bodyController = TextEditingController(text: 'Convocatoria y detalles del partido');
  final venueController = TextEditingController(text: 'Cancha Principal JN');
  final formKey = GlobalKey<FormState>();

  final appCategories = ref.read(appCategoriesProvider);
  final List<String> coachCategories = (sessionUser.assignedCategories != null && (sessionUser.assignedCategories as List).isNotEmpty)
      ? List<String>.from(sessionUser.assignedCategories)
      : (sessionUser.category != null && sessionUser.category.toString().isNotEmpty
          ? [sessionUser.category.toString()]
          : <String>[]);
  final availableCategories = coachCategories.isNotEmpty ? coachCategories : appCategories;

  DateTime? eventDate;
  TimeOfDay? eventTime;
  bool hasTransport = false;
  String? selectedOpponentId;
  String selectedCategory = (defaultCategory != null && defaultCategory != 'Todas' && availableCategories.contains(defaultCategory))
      ? defaultCategory
      : (availableCategories.isNotEmpty ? availableCategories.first : '');

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
                    if (availableCategories.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        dropdownColor: context.colors.surface,
                        initialValue: selectedCategory.isNotEmpty && availableCategories.contains(selectedCategory) ? selectedCategory : availableCategories.first,
                        decoration: const InputDecoration(
                          labelText: 'Categoría del Partido *',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: availableCategories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text('Categoría $cat', style: context.typography.bodyLarge),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                            });
                          }
                        },
                        validator: (val) => (val == null || val.isEmpty) ? 'Selecciona una categoría' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
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
                      'awayTeam': (selectedOpponentId != null)
                          ? (clubs.where((c) => c['id'] == selectedOpponentId).firstOrNull?['name'] ?? 'Rival')
                          : 'Rival',
                      'opponentName': (selectedOpponentId != null)
                          ? (clubs.where((c) => c['id'] == selectedOpponentId).firstOrNull?['name'] ?? 'Rival')
                          : null,
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
  final titleController = TextEditingController(text: match['title'] ?? (match['homeTeam'] != null ? '${match['homeTeam']} vs ${match['awayTeam']}' : 'Partido'));
  final bodyController = TextEditingController(text: match['body'] ?? '');
  final venueController = TextEditingController(text: match['venue'] ?? match['location'] ?? 'Cancha Principal JN');
  final formKey = GlobalKey<FormState>();

  final appCategories = ref.read(appCategoriesProvider);
  final List<String> coachCategories = (sessionUser.assignedCategories != null && (sessionUser.assignedCategories as List).isNotEmpty)
      ? List<String>.from(sessionUser.assignedCategories)
      : (sessionUser.category != null && sessionUser.category.toString().isNotEmpty
          ? [sessionUser.category.toString()]
          : <String>[]);
  final availableCategories = coachCategories.isNotEmpty ? coachCategories : appCategories;

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
  String selectedCategory = (match['category'] != null && match['category'].toString().isNotEmpty)
      ? match['category'].toString()
      : (availableCategories.isNotEmpty ? availableCategories.first : '');
  if (!availableCategories.contains(selectedCategory) && selectedCategory.isNotEmpty) {
    availableCategories.insert(0, selectedCategory);
  }

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
                    if (availableCategories.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        dropdownColor: context.colors.surface,
                        initialValue: selectedCategory.isNotEmpty && availableCategories.contains(selectedCategory) ? selectedCategory : availableCategories.first,
                        decoration: const InputDecoration(
                          labelText: 'Categoría del Partido *',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: availableCategories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text('Categoría $cat', style: context.typography.bodyLarge),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                            });
                          }
                        },
                        validator: (val) => (val == null || val.isEmpty) ? 'Selecciona una categoría' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
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
                        'awayTeam': (selectedOpponentId != null)
                            ? (clubs.where((c) => c['id'] == selectedOpponentId).firstOrNull?['name'] ?? 'Rival')
                            : 'Rival',
                        'opponentName': (selectedOpponentId != null)
                            ? (clubs.where((c) => c['id'] == selectedOpponentId).firstOrNull?['name'] ?? 'Rival')
                            : null,
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