import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  
  // Maps playerId to 'present' | 'absent' | 'justified' | 'late'
  final Map<String, String> _attendanceState = {};
  bool _isLoading = false;

  final List<String> _daysList = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCategory();
    });
  }

  void _initCategory() {
    final sessionUser = ref.read(currentUserProvider);
    if (sessionUser == null) return;

    if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
      setState(() => _selectedCategory = sessionUser.assignedCategories!.first);
    } else if (sessionUser.category != null) {
      setState(() => _selectedCategory = sessionUser.category);
    }
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _formattedDateDDMM => DateFormat('dd-MM').format(_selectedDate);

  Future<void> _saveAttendance(List<Map<String, dynamic>> players) async {
    if (_selectedCategory == null) return;
    
    setState(() => _isLoading = true);
    try {
      final sessionUser = ref.read(currentUserProvider)!;
      final Map<String, String> records = {};

      for (final p in players) {
        final id = p['id'] as String;
        records[id] = _attendanceState[id] ?? 'present';
      }

      await ref.read(firestoreServiceProvider).saveAttendanceDetailed(
        dateStr: _dateStr,
        formattedDate: _formattedDateDDMM,
        category: _selectedCategory!,
        dtId: sessionUser.id,
        records: records,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asistencia guardada para $_formattedDateDDMM'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar asistencia: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showScheduleModal(Map<String, dynamic>? currentSchedule) {
    if (_selectedCategory == null) return;
    
    final daysSelected = List<String>.from(currentSchedule?['days'] ?? []);
    final timeController = TextEditingController(text: currentSchedule?['time'] ?? '18:00 - 19:30');
    final locationController = TextEditingController(text: currentSchedule?['location'] ?? 'Cancha Principal JN');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: Text('Configurar Entrenamientos ($_selectedCategory)', style: context.typography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Días de Entrenamiento', style: context.typography.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _daysList.map((d) {
                        final isSelected = daysSelected.contains(d);
                        return FilterChip(
                          label: Text(d),
                          selected: isSelected,
                          selectedColor: context.colors.accent,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                daysSelected.add(d);
                              } else {
                                daysSelected.remove(d);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Horario (ej: 18:00 - 19:30 hs)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Cancha / Lugar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(firestoreServiceProvider).saveTrainingSchedule(
                          _selectedCategory!,
                          daysSelected,
                          timeController.text.trim(),
                          locationController.text.trim(),
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Horario de entrenamiento guardado'),
                          backgroundColor: context.colors.success,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusButton({
    required String label,
    required String tooltip,
    required Color activeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isSelected ? Colors.white : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) return const Scaffold();

    final allCategories = ref.watch(appCategoriesProvider);

    final isAdmin = sessionUser.role == 'directivo' || sessionUser.role == 'secretario';
    final isCoach = sessionUser.role == 'dt';

    List<String> categories = allCategories;
    if (isCoach) {
      categories = sessionUser.assignedCategories ?? [];
      if (categories.isEmpty && sessionUser.category != null) {
        categories = [sessionUser.category!];
      }
    }

    if (_selectedCategory == null && categories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCategory = categories.first);
      });
    }

    final allPlayersAsync = ref.watch(playersStreamProvider);
    final trainingScheduleAsync = _selectedCategory != null
        ? ref.watch(trainingScheduleStreamProvider(_selectedCategory!))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final attendanceHistoryAsync = _selectedCategory != null
        ? ref.watch(attendanceHistoryStreamProvider(_selectedCategory!))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Control Panel Card
          JNCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Date Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fecha de Clase:', style: context.typography.titleMedium),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _attendanceState.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        '${DateFormat('dd/MM/yyyy').format(_selectedDate)} ($_formattedDateDDMM)',
                        style: context.typography.titleMedium.copyWith(color: context.colors.primary),
                      ),
                    ),
                  ],
                ),
                
                // Category Selector
                if (categories.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Categoría:', style: context.typography.titleMedium),
                      DropdownButton<String>(
                        value: _selectedCategory,
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _attendanceState.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ] else if (_selectedCategory != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: JNBadge(label: 'CATEGORÍA $_selectedCategory', type: JNBadgeType.accent),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Training Schedule Card
          if (_selectedCategory != null)
            trainingScheduleAsync.when(
              data: (schedule) {
                final days = (schedule?['days'] as List<dynamic>?)?.join(', ') ?? 'No configurados';
                final time = schedule?['time'] ?? 'Sin horario';
                final location = schedule?['location'] ?? 'Sin cancha';

                return JNCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, color: context.colors.primary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entrenamientos $_selectedCategory', style: context.typography.titleSmall),
                            Text('Días: $days', style: context.typography.bodySmall),
                            Text('Horario: $time · Cancha: $location', style: context.typography.bodySmall),
                          ],
                        ),
                      ),
                      if (isAdmin || isCoach)
                        IconButton(
                          icon: Icon(Icons.edit_calendar, color: context.colors.accent),
                          onPressed: () => _showScheduleModal(schedule),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          const SizedBox(height: 16),

          // Player Attendance List
          if (_selectedCategory == null)
            const Center(child: Text('Selecciona una categoría'))
          else
            allPlayersAsync.when(
              data: (allPlayers) {
                final players = allPlayers
                    .where((p) => p['category'] == _selectedCategory)
                    .where((p) => p['role'] == null || p['role'] == 'jugador')
                    .where((p) => p['role'] != 'directivo' && p['role'] != 'secretario' && p['role'] != 'dt' && p['role'] != 'tutor' && p['role'] != 'socio')
                    .toList();
                
                if (players.isEmpty) {
                  return JNCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No hay jugadores registrados en la categoría $_selectedCategory'),
                    ),
                  );
                }
                
                final attendanceRecordAsync = ref.watch(attendanceStreamProvider('$_dateStr|$_selectedCategory'));
                
                return attendanceRecordAsync.when(
                  data: (record) {
                    if (_attendanceState.isEmpty && record != null) {
                      final Map<String, dynamic> rawRecords = record['records'] as Map<String, dynamic>? ?? {};
                      rawRecords.forEach((key, val) {
                        _attendanceState[key] = val.toString();
                      });

                      // Fallback for old present/absent arrays
                      if (_attendanceState.isEmpty) {
                        final present = List<String>.from(record['present'] ?? []);
                        final absent = List<String>.from(record['absent'] ?? []);
                        for (var p in present) {
                          _attendanceState[p] = 'present';
                        }
                        for (var a in absent) {
                          _attendanceState[a] = 'absent';
                        }
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Planilla (${players.length} Jugadores)',
                              style: context.typography.titleMedium,
                            ),
                            Text(
                              'P=Presente, A=Ausente, J=Justificado, T=Tardanza',
                              style: context.typography.labelSmall.copyWith(color: context.colors.textTertiary, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...players.map((player) {
                          final playerId = player['id'] as String;
                          final name = '${player['name']} ${player['lastName']}';
                          final currentStatus = _attendanceState[playerId] ?? 'present';

                          return JNCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                JNAvatar(name: name, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: context.typography.titleSmall),
                                      Text('Posición: ${player['position'] ?? 'Jugador'}', style: context.typography.bodySmall),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    _buildStatusButton(
                                      label: 'P',
                                      tooltip: 'Presente',
                                      activeColor: context.colors.success,
                                      isSelected: currentStatus == 'present',
                                      onTap: () => setState(() => _attendanceState[playerId] = 'present'),
                                    ),
                                    _buildStatusButton(
                                      label: 'A',
                                      tooltip: 'Ausente',
                                      activeColor: context.colors.error,
                                      isSelected: currentStatus == 'absent',
                                      onTap: () => setState(() => _attendanceState[playerId] = 'absent'),
                                    ),
                                    _buildStatusButton(
                                      label: 'J',
                                      tooltip: 'Justificado',
                                      activeColor: context.colors.accent,
                                      isSelected: currentStatus == 'justified',
                                      onTap: () => setState(() => _attendanceState[playerId] = 'justified'),
                                    ),
                                    _buildStatusButton(
                                      label: 'T',
                                      tooltip: 'Tardanza',
                                      activeColor: Colors.lightBlue,
                                      isSelected: currentStatus == 'late',
                                      onTap: () => setState(() => _attendanceState[playerId] = 'late'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        JNButton(
                          label: 'Guardar Asistencia ($_formattedDateDDMM)',
                          isLoading: _isLoading,
                          onPressed: () => _saveAttendance(players),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error cargando asistencia: $err')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error cargando jugadores: $err')),
            ),

          const SizedBox(height: 24),

          // Attendance History Card
          if (_selectedCategory != null)
            attendanceHistoryAsync.when(
              data: (historyList) {
                if (historyList.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Histórico de Asistencias por Fecha ($_selectedCategory)', style: context.typography.titleMedium),
                    const SizedBox(height: 8),
                    ...historyList.map((att) {
                      final dateStr = att['dateStr'] ?? att['date'] ?? '';
                      final formattedDate = att['formattedDate'] ?? dateStr;
                      final records = (att['records'] as Map<String, dynamic>?) ?? {};

                      int pCount = 0;
                      int aCount = 0;
                      records.forEach((k, v) {
                        if (v == 'present') pCount++;
                        if (v == 'absent') aCount++;
                      });

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: JNCard(
                          onTap: () {
                            try {
                              final parsed = DateTime.parse(dateStr);
                              setState(() {
                                _selectedDate = parsed;
                                _attendanceState.clear();
                              });
                            } catch (_) {}
                          },
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_month, color: context.colors.accent, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Fecha: $formattedDate', style: context.typography.titleSmall),
                                  const SizedBox(width: 8),
                                  Text('($dateStr)', style: context.typography.bodySmall),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('$pCount Presentes', style: TextStyle(color: context.colors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  Text('$aCount Ausentes', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
