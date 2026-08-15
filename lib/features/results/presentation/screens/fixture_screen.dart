import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

class FixtureScreen extends ConsumerStatefulWidget {
  const FixtureScreen({super.key});

  @override
  ConsumerState<FixtureScreen> createState() => _FixtureScreenState();
}

class _FixtureScreenState extends ConsumerState<FixtureScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider)!;
    final fixturesAsync = ref.watch(fixturesStreamProvider('all'));
    final clubsAsync = ref.watch(clubsStreamProvider);
    final clubs = clubsAsync.value ?? [];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Fixture'),
        actions: [
          if (sessionUser.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddFixtureDialog(context, clubs),
            ),
        ],
      ),
      body: fixturesAsync.when(
        data: (fixtures) {
          if (fixtures.isEmpty) {
            return Center(
              child: Text(
                'No hay fechas en el fixture.',
                style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            itemCount: fixtures.length,
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemBuilder: (context, index) {
              final fixture = fixtures[index];
              return _buildFixtureCard(fixture, clubs, sessionUser.isAdmin);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: context.colors.error))),
      ),
    );
  }

  Widget _buildFixtureCard(Map<String, dynamic> fixture, List<Map<String, dynamic>> clubs, bool isAdmin) {
    final matches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: JNCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fixture['name'] ?? 'Fecha', style: context.typography.titleMedium),
                if (isAdmin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: context.colors.primary, size: 20),
                        tooltip: 'Editar Fecha y Partidos',
                        onPressed: () => _showEditFixtureDialog(context, fixture, clubs),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: context.colors.error, size: 20),
                        tooltip: 'Eliminar Fecha',
                        onPressed: () {
                          ref.read(firestoreServiceProvider).deleteFixture(fixture['id']);
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...matches.map((m) {
              final homeClub = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
              final awayClub = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildClubLogo(homeClub),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textTertiary)),
                          if (m['date'] != null && m['time'] != null) ...[
                            const SizedBox(height: 4),
                            Text('${m['date']} ${m['time']}', style: context.typography.labelSmall.copyWith(color: context.colors.textSecondary, fontSize: 10)),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClubLogo(awayClub),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildClubLogo(Map<String, dynamic>? club) {
    if (club == null) {
      return Column(
        children: [
          CircleAvatar(radius: 20, backgroundColor: context.colors.surfaceLight, child: const Icon(Icons.shield, size: 20)),
          const SizedBox(height: 4),
          Text('?', style: context.typography.labelSmall),
        ],
      );
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: context.colors.surfaceLight,
          backgroundImage: club['logoUrl'] != null && club['logoUrl'].toString().isNotEmpty
              ? NetworkImage(club['logoUrl'])
              : null,
          child: (club['logoUrl'] == null || club['logoUrl'].toString().isEmpty)
              ? const Icon(Icons.shield, size: 20)
              : null,
        ),
        const SizedBox(height: 4),
        Text(club['name'] ?? '', style: context.typography.labelSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
  }

  void _showAddFixtureDialog(BuildContext context, List<Map<String, dynamic>> clubs) {
    final nameController = TextEditingController();
    final List<Map<String, dynamic>> newMatches = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: Text('Nueva Fecha', style: context.typography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Nombre (Ej: 1ra Fecha)'),
                    ),
                    const SizedBox(height: 16),
                    Text('Partidos', style: context.typography.titleSmall),
                    const SizedBox(height: 8),
                    ...newMatches.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      final home = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
                      final away = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${home?['name'] ?? '?'} vs ${away?['name'] ?? '?'}', style: context.typography.bodyMedium),
                        subtitle: m['date'] != null && m['time'] != null ? Text('${m['date']} ${m['time']}', style: context.typography.bodySmall) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () {
                                _showAddOrEditMatchDialog(context, clubs, initialMatch: m, onSave: (updated) {
                                  setDialogState(() {
                                    newMatches[i] = updated;
                                  });
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: context.colors.error),
                              onPressed: () {
                                setDialogState(() {
                                  newMatches.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Partido'),
                      onPressed: () {
                        _showAddOrEditMatchDialog(context, clubs, onSave: (match) {
                          setDialogState(() {
                            newMatches.add(match);
                          });
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty && newMatches.isNotEmpty) {
                      await ref.read(firestoreServiceProvider).addFixture({
                        'name': nameController.text.trim(),
                        'category': 'all',
                        'matches': newMatches,
                      });
                      if (context.mounted) Navigator.pop(context);
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

  void _showEditFixtureDialog(BuildContext context, Map<String, dynamic> fixture, List<Map<String, dynamic>> clubs) {
    final nameController = TextEditingController(text: fixture['name'] ?? '');
    final List<Map<String, dynamic>> editedMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: Text('Editar Fecha y Partidos', style: context.typography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: context.typography.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Nombre de la fecha'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Partidos de esta fecha', style: context.typography.titleSmall),
                        Text('${editedMatches.length}', style: context.typography.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (editedMatches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Sin partidos asignados.', style: TextStyle(color: context.colors.textTertiary)),
                      ),
                    ...editedMatches.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      final home = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
                      final away = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${home?['name'] ?? '?'} vs ${away?['name'] ?? '?'}', style: context.typography.bodyMedium),
                        subtitle: m['date'] != null && m['time'] != null ? Text('${m['date']} ${m['time']}', style: context.typography.bodySmall) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, size: 18, color: context.colors.primary),
                              tooltip: 'Editar partido',
                              onPressed: () {
                                _showAddOrEditMatchDialog(context, clubs, initialMatch: m, onSave: (updated) {
                                  setDialogState(() {
                                    editedMatches[i] = updated;
                                  });
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: context.colors.error),
                              tooltip: 'Eliminar partido',
                              onPressed: () {
                                setDialogState(() {
                                  editedMatches.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Partido a la Fecha'),
                      onPressed: () {
                        _showAddOrEditMatchDialog(context, clubs, onSave: (match) {
                          setDialogState(() {
                            editedMatches.add(match);
                          });
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                        'name': nameController.text.trim(),
                        'matches': editedMatches,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Fecha actualizada correctamente!'),
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

  void _showAddOrEditMatchDialog(
    BuildContext context,
    List<Map<String, dynamic>> clubs, {
    Map<String, dynamic>? initialMatch,
    required Function(Map<String, dynamic>) onSave,
  }) {
    String? homeClubId = initialMatch?['homeClubId'];
    String? awayClubId = initialMatch?['awayClubId'];
    DateTime? matchDate;
    TimeOfDay? matchTime;

    if (initialMatch?['date'] != null) {
      try {
        final parts = (initialMatch!['date'] as String).split('-');
        if (parts.length == 3) {
          matchDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }
    matchDate ??= DateTime.now();

    if (initialMatch?['time'] != null) {
      try {
        final cleanTime = (initialMatch!['time'] as String).replaceAll('hs', '').trim();
        final parts = cleanTime.split(':');
        if (parts.length >= 2) {
          matchTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      } catch (_) {}
    }
    matchTime ??= const TimeOfDay(hour: 15, minute: 0);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dateStr = matchDate != null
                ? '${matchDate!.year}-${matchDate!.month.toString().padLeft(2, '0')}-${matchDate!.day.toString().padLeft(2, '0')}'
                : 'Seleccionar fecha';
            final timeStr = matchTime != null
                ? '${matchTime!.hour.toString().padLeft(2, '0')}:${matchTime!.minute.toString().padLeft(2, '0')}'
                : 'Seleccionar hora';

            final isEditing = initialMatch != null;

            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: Text(isEditing ? 'Editar Partido' : 'Agregar Partido', style: context.typography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      dropdownColor: context.colors.surface,
                      initialValue: homeClubId,
                      decoration: const InputDecoration(labelText: 'Club Local'),
                      items: clubs.map((c) => DropdownMenuItem<String>(value: c['id'], child: Text(c['name'], style: context.typography.bodyLarge))).toList(),
                      onChanged: (val) => setDialogState(() => homeClubId = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      dropdownColor: context.colors.surface,
                      initialValue: awayClubId,
                      decoration: const InputDecoration(labelText: 'Club Visitante'),
                      items: clubs.map((c) => DropdownMenuItem<String>(value: c['id'], child: Text(c['name'], style: context.typography.bodyLarge))).toList(),
                      onChanged: (val) => setDialogState(() => awayClubId = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: matchDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                locale: const Locale('es', 'ES'),
                              );
                              if (date != null) {
                                setDialogState(() => matchDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Fecha', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              child: Text(dateStr, style: context.typography.bodyLarge),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: matchTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setDialogState(() => matchTime = time);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Hora', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              child: Text(timeStr, style: context.typography.bodyLarge),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
                  onPressed: () {
                    if (homeClubId != null && awayClubId != null && matchDate != null && matchTime != null) {
                      onSave({
                        'homeClubId': homeClubId,
                        'awayClubId': awayClubId,
                        'date': dateStr,
                        'time': timeStr,
                        'status': initialMatch?['status'] ?? 'scheduled',
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(isEditing ? 'Guardar' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}