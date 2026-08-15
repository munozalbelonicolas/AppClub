import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import 'player_attendance_screen.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _selectedCategory;
  final Set<String> _customDateColumns = {};
  String? _activeDateColumnForBulk;
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

  Color _getStatusBgColor(String? status) {
    switch (status) {
      case 'present':
      case 'P':
        return const Color(0xFF15803D); // Green
      case 'absent':
      case 'A':
        return const Color(0xFFB91C1C); // Red
      case 'justified':
      case 'J':
        return const Color(0xFFD4AF37); // Gold
      case 'late':
      case 'T':
        return const Color(0xFF0284C7); // Blue
      default:
        return Colors.transparent;
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'justified':
      case 'J':
        return Colors.black;
      case 'present':
      case 'P':
      case 'absent':
      case 'A':
      case 'late':
      case 'T':
        return Colors.white;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'present':
        return 'P';
      case 'absent':
        return 'A';
      case 'justified':
        return 'J';
      case 'late':
        return 'T';
      default:
        return '-';
    }
  }

  String _getNextStatus(String? current) {
    switch (current) {
      case 'present':
      case 'P':
        return 'absent';
      case 'absent':
      case 'A':
        return 'justified';
      case 'justified':
      case 'J':
        return 'late';
      case 'late':
      case 'T':
        return '';
      default:
        return 'present';
    }
  }

  Future<void> _updateCellStatus({
    required String playerId,
    required String dateStr,
    required String newStatus,
    required Map<String, String> existingRecordsForDate,
  }) async {
    if (_selectedCategory == null) return;
    final sessionUser = ref.read(currentUserProvider)!;

    final updatedRecords = Map<String, String>.from(existingRecordsForDate);
    if (newStatus.isEmpty) {
      updatedRecords.remove(playerId);
    } else {
      updatedRecords[playerId] = newStatus;
    }

    String formattedDate = dateStr;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        formattedDate = '${parts[2]}/${parts[1]}';
      }
    } catch (_) {}

    await ref.read(firestoreServiceProvider).saveAttendanceDetailed(
      dateStr: dateStr,
      formattedDate: formattedDate,
      category: _selectedCategory!,
      dtId: sessionUser.id,
      records: updatedRecords,
    );
  }

  Future<void> _markAllPresentForDate({
    required String dateStr,
    required List<Map<String, dynamic>> players,
    required Map<String, String> existingRecordsForDate,
  }) async {
    if (_selectedCategory == null || players.isEmpty) return;
    final sessionUser = ref.read(currentUserProvider)!;

    final updatedRecords = Map<String, String>.from(existingRecordsForDate);
    for (final p in players) {
      final id = p['id'] as String;
      updatedRecords[id] = 'present';
    }

    String formattedDate = dateStr;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        formattedDate = '${parts[2]}/${parts[1]}';
      }
    } catch (_) {}

    await ref.read(firestoreServiceProvider).saveAttendanceDetailed(
      dateStr: dateStr,
      formattedDate: formattedDate,
      category: _selectedCategory!,
      dtId: sessionUser.id,
      records: updatedRecords,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Todos marcados como Presentes para $formattedDate'),
          backgroundColor: context.colors.success,
        ),
      );
    }
  }

  Future<void> _addNewDateColumn() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );

    if (date != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      setState(() {
        _customDateColumns.add(dateStr);
        _activeDateColumnForBulk = dateStr;
      });
    }
  }

  void _showStatusPickerModal({
    required String playerName,
    required String dateStr,
    required String currentStatus,
    required Map<String, String> existingRecordsForDate,
    required String playerId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistencia: $playerName',
                  style: context.typography.titleMedium,
                ),
                Text(
                  'Fecha: $dateStr',
                  style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildModalStatusOption(
                      label: 'P - Presente',
                      statusKey: 'present',
                      bgColor: const Color(0xFF15803D),
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.pop(modalContext);
                        _updateCellStatus(
                          playerId: playerId,
                          dateStr: dateStr,
                          newStatus: 'present',
                          existingRecordsForDate: existingRecordsForDate,
                        );
                      },
                    ),
                    _buildModalStatusOption(
                      label: 'A - Ausente',
                      statusKey: 'absent',
                      bgColor: const Color(0xFFB91C1C),
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.pop(modalContext);
                        _updateCellStatus(
                          playerId: playerId,
                          dateStr: dateStr,
                          newStatus: 'absent',
                          existingRecordsForDate: existingRecordsForDate,
                        );
                      },
                    ),
                    _buildModalStatusOption(
                      label: 'J - Justificado',
                      statusKey: 'justified',
                      bgColor: const Color(0xFFD4AF37),
                      textColor: Colors.black,
                      onTap: () {
                        Navigator.pop(modalContext);
                        _updateCellStatus(
                          playerId: playerId,
                          dateStr: dateStr,
                          newStatus: 'justified',
                          existingRecordsForDate: existingRecordsForDate,
                        );
                      },
                    ),
                    _buildModalStatusOption(
                      label: 'T - Tardanza',
                      statusKey: 'late',
                      bgColor: const Color(0xFF0284C7),
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.pop(modalContext);
                        _updateCellStatus(
                          playerId: playerId,
                          dateStr: dateStr,
                          newStatus: 'late',
                          existingRecordsForDate: existingRecordsForDate,
                        );
                      },
                    ),
                    _buildModalStatusOption(
                      label: '- Sin marcar',
                      statusKey: '',
                      bgColor: context.colors.surfaceVariant,
                      textColor: context.colors.textSecondary,
                      onTap: () {
                        Navigator.pop(modalContext);
                        _updateCellStatus(
                          playerId: playerId,
                          dateStr: dateStr,
                          newStatus: '',
                          existingRecordsForDate: existingRecordsForDate,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalStatusOption({
    required String label,
    required String statusKey,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
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

  Widget _buildReferenceChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) return const Scaffold();

    if (sessionUser.role == 'tutor' || sessionUser.role == 'jugador') {
      return const PlayerAttendanceScreen();
    }

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
          // Category Selector
          if (categories.length > 1)
            JNCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seleccionar Categoría:', style: context.typography.titleMedium),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text('Categoría $c'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          _customDateColumns.clear();
                          _activeDateColumnForBulk = null;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

          if (categories.length > 1) const SizedBox(height: 12),

          // Training Schedule Card
          if (_selectedCategory != null)
            trainingScheduleAsync.when(
              data: (schedule) {
                final days = (schedule?['days'] as List<dynamic>?)?.join(', ') ?? 'No configurados';
                final time = schedule?['time'] ?? 'Sin horario';
                final location = schedule?['location'] ?? 'Sin cancha';

                return JNCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, color: context.colors.primary, size: 24),
                      const SizedBox(width: 12),
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
                          icon: Icon(Icons.edit_calendar, color: context.colors.accent, size: 20),
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

          // ─── PLANILLA DE ASISTENCIA DIARIA (Spreadsheet Matrix Table) ───
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

                return attendanceHistoryAsync.when(
                  data: (historyList) {
                    // Extract date columns from history + custom added date columns
                    final Map<String, Map<String, String>> historyMapByDate = {};
                    for (final doc in historyList) {
                      final dateStr = doc['dateStr'] ?? doc['date'] ?? '';
                      if (dateStr.isNotEmpty) {
                        final records = Map<String, String>.from(
                          (doc['records'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
                        );
                        historyMapByDate[dateStr] = records;
                      }
                    }

                    final Set<String> allDateColsSet = {};
                    allDateColsSet.addAll(historyMapByDate.keys);
                    allDateColsSet.addAll(_customDateColumns);

                    // Ensure today's date column is present if empty
                    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    if (allDateColsSet.isEmpty) {
                      allDateColsSet.add(todayStr);
                    }

                    final List<String> sortedDateColumns = allDateColsSet.toList()
                      ..sort((a, b) => b.compareTo(a)); // Descending: Newest left, Oldest right

                    _activeDateColumnForBulk ??= sortedDateColumns.first;

                    final String activeBulkDate = _activeDateColumnForBulk ?? sortedDateColumns.first;
                    final Map<String, String> activeBulkRecords = historyMapByDate[activeBulkDate] ?? {};

                    return JNCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header title & Controls
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'PLANILLA DE ASISTENCIA DIARIA ($_selectedCategory)',
                                  style: context.typography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Haz clic en cualquier celda para alternar estado (P: Presente, A: Ausente, J: Justificado, T: Tardanza).',
                            style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 12),

                          // Controls: Add Date & Bulk All Present
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.colors.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: _addNewDateColumn,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Agregar Fecha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () => _markAllPresentForDate(
                                  dateStr: activeBulkDate,
                                  players: players,
                                  existingRecordsForDate: activeBulkRecords,
                                ),
                                icon: const Icon(Icons.check_circle, size: 16, color: Color(0xFF15803D)),
                                label: Text(
                                  'Todos Presentes (${activeBulkDate.split('-').length == 3 ? '${activeBulkDate.split('-')[2]}/${activeBulkDate.split('-')[1]}' : activeBulkDate})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // References Bar
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text('Referencias:', style: context.typography.labelSmall.copyWith(fontWeight: FontWeight.bold, fontSize: 11)),
                                const SizedBox(width: 6),
                                _buildReferenceChip('P = Presente', const Color(0xFF15803D), Colors.white),
                                const SizedBox(width: 4),
                                _buildReferenceChip('A = Ausente', const Color(0xFFB91C1C), Colors.white),
                                const SizedBox(width: 4),
                                _buildReferenceChip('J = Justificado', const Color(0xFFD4AF37), Colors.black),
                                const SizedBox(width: 4),
                                _buildReferenceChip('T = Tardanza', const Color(0xFF0284C7), Colors.white),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ─── Horizontally & Vertically Scrollable Spreadsheet Matrix Table ───
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.colors.border),
                              color: context.colors.surfaceVariant.withValues(alpha: 0.3),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Sticky Left Column: Player Names
                                Container(
                                  width: 140,
                                  decoration: BoxDecoration(
                                    border: Border(right: BorderSide(color: context.colors.border, width: 2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Header Cell
                                      Container(
                                        height: 40,
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        color: context.colors.surface,
                                        child: Text(
                                          'Jugador',
                                          style: context.typography.labelSmall.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 1, thickness: 1),
                                      // Player Name Rows
                                      ...players.map((p) {
                                        final name = '${p['name'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                                        return Container(
                                          height: 44,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
                                          ),
                                          child: Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.typography.bodySmall.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),

                                // 2. Scrollable Date Columns
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: sortedDateColumns.map((dateStr) {
                                        final records = historyMapByDate[dateStr] ?? {};

                                        String formattedDDMM = dateStr;
                                        try {
                                          final parts = dateStr.split('-');
                                          if (parts.length == 3) {
                                            formattedDDMM = '${parts[2]}/${parts[1]}';
                                          }
                                        } catch (_) {}

                                        final isSelectedDate = dateStr == activeBulkDate;

                                        return Container(
                                          width: 68,
                                          decoration: BoxDecoration(
                                            border: Border(right: BorderSide(color: context.colors.border, width: 0.5)),
                                          ),
                                          child: Column(
                                            children: [
                                              // Date Header Cell
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _activeDateColumnForBulk = dateStr;
                                                  });
                                                },
                                                child: Container(
                                                  height: 40,
                                                  alignment: Alignment.center,
                                                  color: isSelectedDate
                                                      ? context.colors.primary.withValues(alpha: 0.2)
                                                      : context.colors.surface,
                                                  child: Text(
                                                    formattedDDMM,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: context.colors.accent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const Divider(height: 1, thickness: 1),
                                              // Status Cells for each player
                                              ...players.map((p) {
                                                final playerId = p['id'] as String;
                                                final playerName = '${p['name']} ${p['lastName']}';
                                                final status = records[playerId];

                                                final bgColor = _getStatusBgColor(status);
                                                final textColor = _getStatusTextColor(status);
                                                final label = _getStatusLabel(status);

                                                return GestureDetector(
                                                  onTap: () {
                                                    final nextStatus = _getNextStatus(status);
                                                    _updateCellStatus(
                                                      playerId: playerId,
                                                      dateStr: dateStr,
                                                      newStatus: nextStatus,
                                                      existingRecordsForDate: records,
                                                    );
                                                  },
                                                  onLongPress: () {
                                                    _showStatusPickerModal(
                                                      playerName: playerName,
                                                      dateStr: formattedDDMM,
                                                      currentStatus: status ?? '',
                                                      existingRecordsForDate: records,
                                                      playerId: playerId,
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 44,
                                                    alignment: Alignment.center,
                                                    margin: const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: bgColor,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: status == null || status.isEmpty
                                                            ? context.colors.border
                                                            : Colors.transparent,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: textColor,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error cargando planilla: $err')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error cargando jugadores: $err')),
            ),
        ],
      ),
    );
  }
}
