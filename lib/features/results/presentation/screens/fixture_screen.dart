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
              tooltip: 'Nueva Fecha',
              onPressed: () => _openEditFixtureScreen(context, clubs: clubs),
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

  void _openEditFixtureScreen(BuildContext context, {required List<Map<String, dynamic>> clubs, Map<String, dynamic>? fixture}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditFixtureScreen(
          clubs: clubs,
          fixture: fixture,
        ),
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
                        onPressed: () => _openEditFixtureScreen(context, clubs: clubs, fixture: fixture),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: context.colors.error, size: 20),
                        tooltip: 'Eliminar Fecha',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar Fecha'),
                              content: Text('¿Deseas eliminar "${fixture['name'] ?? 'esta fecha'}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(firestoreServiceProvider).deleteFixture(fixture['id']);
                          }
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
}

class EditFixtureScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? fixture;
  final List<Map<String, dynamic>> clubs;

  const EditFixtureScreen({
    super.key,
    this.fixture,
    required this.clubs,
  });

  @override
  ConsumerState<EditFixtureScreen> createState() => _EditFixtureScreenState();
}

class _EditFixtureScreenState extends ConsumerState<EditFixtureScreen> {
  late TextEditingController _nameController;
  late List<Map<String, dynamic>> _matches;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fixture?['name'] ?? '');
    _matches = widget.fixture?['matches'] != null
        ? List<Map<String, dynamic>>.from(
            (widget.fixture!['matches'] as List).map((m) => Map<String, dynamic>.from(m as Map)),
          )
        : [];
    if (_matches.isEmpty) {
      // Add one empty match default for convenience
      _matches.add({
        'homeClubId': widget.clubs.isNotEmpty ? widget.clubs.first['id'] : null,
        'awayClubId': widget.clubs.length > 1 ? widget.clubs[1]['id'] : null,
        'date': _formatDate(DateTime.now()),
        'time': '15:00',
        'status': 'scheduled',
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addMatch() {
    setState(() {
      _matches.add({
        'homeClubId': widget.clubs.isNotEmpty ? widget.clubs.first['id'] : null,
        'awayClubId': widget.clubs.length > 1 ? widget.clubs[1]['id'] : null,
        'date': _formatDate(DateTime.now()),
        'time': '15:00',
        'status': 'scheduled',
      });
    });
  }

  void _removeMatch(int index) {
    setState(() {
      _matches.removeAt(index);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre para la fecha (Ej: 1ra Fecha)')),
      );
      return;
    }

    if (_matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos un partido')),
      );
      return;
    }

    for (int i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      if (m['homeClubId'] == null || m['awayClubId'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selecciona club local y visitante para el Partido #${i + 1}')),
        );
        return;
      }
      if (m['homeClubId'] == m['awayClubId']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El Club Local y Visitante no pueden ser el mismo en el Partido #${i + 1}')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      if (widget.fixture != null) {
        await firestoreService.updateFixture(widget.fixture!['id'], {
          'name': name,
          'matches': _matches,
        });
      } else {
        await firestoreService.addFixture({
          'name': name,
          'category': 'all',
          'matches': _matches,
        });
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.fixture != null ? 'Fecha actualizada con éxito!' : 'Fecha creada con éxito!'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.fixture != null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Fecha y Partidos' : 'Nueva Fecha'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Guardar', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ─── Nombre de la fecha ───
          JNCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Datos de la Fecha', style: context.typography.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: context.typography.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la fecha *',
                    hintText: 'Ej: 1ra Fecha, 2da Fecha, Cuartos de Final',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Encabezado de Partidos ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Partidos (${_matches.length})', style: context.typography.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Agregar Partido'),
                onPressed: _addMatch,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ─── Tarjetas de Partidos Inline ───
          ..._matches.asMap().entries.map((entry) {
            final index = entry.key;
            final match = entry.value;
            return _buildMatchEditorCard(index, match);
          }),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: context.colors.primary),
            ),
            icon: Icon(Icons.add, color: context.colors.primary),
            label: Text('Agregar Otro Partido a la Fecha', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600)),
            onPressed: _addMatch,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? 'Guardar Cambios' : 'Crear Fecha', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildMatchEditorCard(int index, Map<String, dynamic> match) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: JNCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Partido #${index + 1}', style: context.typography.labelMedium.copyWith(color: context.colors.primary)),
                ),
                if (_matches.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: context.colors.error, size: 20),
                    tooltip: 'Eliminar partido',
                    onPressed: () => _removeMatch(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Club Local
            DropdownButtonFormField<String>(
              dropdownColor: context.colors.surface,
              initialValue: match['homeClubId'],
              decoration: const InputDecoration(
                labelText: 'Club Local',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              items: widget.clubs.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text(c['name'] as String, style: context.typography.bodyMedium),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  match['homeClubId'] = val;
                });
              },
            ),
            const SizedBox(height: 12),
            // Club Visitante
            DropdownButtonFormField<String>(
              dropdownColor: context.colors.surface,
              initialValue: match['awayClubId'],
              decoration: const InputDecoration(
                labelText: 'Club Visitante',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              items: widget.clubs.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text(c['name'] as String, style: context.typography.bodyMedium),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  match['awayClubId'] = val;
                });
              },
            ),
            const SizedBox(height: 12),
            // Fecha y Hora
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime initial = DateTime.now();
                      if (match['date'] != null) {
                        try {
                          final parts = (match['date'] as String).split('-');
                          if (parts.length == 3) {
                            initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                          }
                        } catch (_) {}
                      }
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('es', 'ES'),
                      );
                      if (picked != null) {
                        setState(() {
                          match['date'] = _formatDate(picked);
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        match['date'] ?? 'Seleccionar',
                        style: context.typography.bodyMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      TimeOfDay initial = const TimeOfDay(hour: 15, minute: 0);
                      if (match['time'] != null) {
                        try {
                          final clean = (match['time'] as String).replaceAll('hs', '').trim();
                          final parts = clean.split(':');
                          if (parts.length >= 2) {
                            initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                          }
                        } catch (_) {}
                      }
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initial,
                      );
                      if (picked != null) {
                        setState(() {
                          match['time'] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        prefixIcon: Icon(Icons.access_time, size: 18),
                      ),
                      child: Text(
                        match['time'] ?? '15:00',
                        style: context.typography.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}