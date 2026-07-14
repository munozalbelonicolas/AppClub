import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
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
  
  // Maps playerId to true (present) or false (absent)
  final Map<String, bool> _attendanceState = {};
  bool _isLoading = false;

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

  Future<void> _saveAttendance(List<Map<String, dynamic>> players) async {
    if (_selectedCategory == null) return;
    
    setState(() => _isLoading = true);
    try {
      final sessionUser = ref.read(currentUserProvider)!;
      final List<String> present = [];
      final List<String> absent = [];
      
      for (final p in players) {
        final id = p['id'] as String;
        // Default to present if not explicitly marked
        final isPresent = _attendanceState[id] ?? true; 
        if (isPresent) {
          present.add(id);
        } else {
          absent.add(id);
        }
      }

      await ref.read(firestoreServiceProvider).saveAttendance(
        _dateStr,
        _selectedCategory!,
        sessionUser.id,
        present,
        absent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Asistencia guardada exitosamente'),
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

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) return const Scaffold();

    final categories = sessionUser.assignedCategories ?? [];
    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    final allPlayersAsync = ref.watch(playersStreamProvider);
    
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: context.colors.surface,
            child: Column(
              children: [
                // Date Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fecha:',
                      style: context.typography.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: context.colors.primary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _attendanceState.clear(); // reset state for new date
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: context.typography.titleMedium.copyWith(
                          color: context.colors.primary,
                        ),
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
                      Text(
                        'Categoría:',
                        style: context.typography.titleMedium,
                      ),
                      DropdownButton<String>(
                        value: _selectedCategory,
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          );
                        }).toList(),
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
                ],
              ],
            ),
          ),
          
          // Player List
          Expanded(
            child: _selectedCategory == null
                ? const Center(child: Text('Selecciona una categoría'))
                : allPlayersAsync.when(
                    data: (allPlayers) {
                      final players = allPlayers.where((p) => p['category'] == _selectedCategory).toList();
                      
                      if (players.isEmpty) {
                        return Center(
                          child: Text(
                            'No hay jugadores en esta categoría',
                            style: context.typography.bodyLarge,
                          ),
                        );
                      }
                      
                      // Fetch saved attendance for this date/category
                      final attendanceRecordAsync = ref.watch(attendanceStreamProvider('$_dateStr|$_selectedCategory'));
                      
                      return attendanceRecordAsync.when(
                        data: (record) {
                          // Initialize state from DB if we haven't modified it yet
                          if (_attendanceState.isEmpty && record != null) {
                            final present = List<String>.from(record['present'] ?? []);
                            final absent = List<String>.from(record['absent'] ?? []);
                            
                            for (var p in present) {
                              _attendanceState[p] = true;
                            }
                            for (var a in absent) {
                              _attendanceState[a] = false;
                            }
                          }
                          
                          return ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index];
                              final playerId = player['id'] as String;
                              final name = '${player['name']} ${player['lastName']}';
                              
                              // Default is present
                              final isPresent = _attendanceState[playerId] ?? true;
                              
                              return JNCard(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isPresent 
                                        ? context.colors.success.withValues(alpha: 0.2)
                                        : context.colors.error.withValues(alpha: 0.2),
                                    child: Icon(
                                      isPresent ? Icons.check : Icons.close,
                                      color: isPresent ? context.colors.success : context.colors.error,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: context.typography.titleMedium,
                                  ),
                                  trailing: Switch(
                                    value: isPresent,
                                    activeThumbColor: context.colors.success,
                                    onChanged: (val) {
                                      setState(() {
                                        _attendanceState[playerId] = val;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const Center(child: Text('Error cargando asistencia')),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Center(child: Text('Error cargando jugadores')),
                  ),
          ),
          
          // Save Button
          if (_selectedCategory != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: allPlayersAsync.maybeWhen(
                  data: (allPlayers) {
                    final players = allPlayers.where((p) => p['category'] == _selectedCategory).toList();
                    if (players.isEmpty) return const SizedBox.shrink();
                    
                    return JNButton(
                      label: 'Guardar Asistencia',
                      isLoading: _isLoading,
                      onPressed: () => _saveAttendance(players),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
