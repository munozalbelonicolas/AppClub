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
              onPressed: () => _openEditFixtureModal(context, clubs: clubs),
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

  void _openEditFixtureModal(BuildContext context, {required List<Map<String, dynamic>> clubs, Map<String, dynamic>? fixture}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditFixtureModal(
        clubs: clubs,
        fixture: fixture,
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
                        onPressed: () => _openEditFixtureModal(context, clubs: clubs, fixture: fixture),
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

class _EditFixtureModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? fixture;
  final List<Map<String, dynamic>> clubs;

  const _EditFixtureModal({
    this.fixture,
    required this.clubs,
  });

  @override
  ConsumerState<_EditFixtureModal> createState() => _EditFixtureModalState();
}

class _EditFixtureModalState extends ConsumerState<_EditFixtureModal> {
  late TextEditingController _nameController;
  late String _selectedCategory;
  DateTime? _matchDate;
  TimeOfDay? _matchTime;
  String? _homeClubId;
  String? _awayClubId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.fixture;
    _nameController = TextEditingController(text: f?['name'] ?? '');
    _selectedCategory = f?['category'] ?? 'all';

    final matches = List<Map<String, dynamic>>.from(f?['matches'] ?? []);
    final firstMatch = matches.isNotEmpty ? matches.first : null;

    _homeClubId = firstMatch?['homeClubId'] ??
        widget.clubs.where((c) => (c['name'] as String?)?.toLowerCase().contains('newbery') == true).firstOrNull?['id'] ??
        (widget.clubs.isNotEmpty ? widget.clubs.first['id'] : null);

    _awayClubId = firstMatch?['awayClubId'] ??
        widget.clubs.where((c) => c['id'] != _homeClubId).firstOrNull?['id'] ??
        (widget.clubs.length > 1 ? widget.clubs[1]['id'] : null);

    // Parse date
    final rawDate = firstMatch?['date'] ?? f?['date'];
    if (rawDate != null) {
      try {
        final parts = (rawDate as String).split('-');
        if (parts.length == 3) {
          _matchDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }
    _matchDate ??= DateTime.now();

    // Parse time
    final rawTime = firstMatch?['time'] ?? f?['time'];
    if (rawTime != null) {
      try {
        final clean = (rawTime as String).replaceAll('hs', '').trim();
        final parts = clean.split(':');
        if (parts.length >= 2) {
          _matchTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      } catch (_) {}
    }
    _matchTime ??= const TimeOfDay(hour: 15, minute: 30);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDateDisplay(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateISO(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeDisplay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre para la fecha')),
      );
      return;
    }

    if (_homeClubId == null || _awayClubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona Club Local y Visitante')),
      );
      return;
    }

    if (_homeClubId == _awayClubId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El Club Local y Visitante no pueden ser el mismo')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dateIso = _matchDate != null ? _formatDateISO(_matchDate!) : _formatDateISO(DateTime.now());
      final timeStr = _matchTime != null ? _formatTimeDisplay(_matchTime!) : '15:30';

      final matchesList = [
        {
          'homeClubId': _homeClubId,
          'awayClubId': _awayClubId,
          'date': dateIso,
          'time': timeStr,
          'status': 'scheduled',
        }
      ];

      final firestoreService = ref.read(firestoreServiceProvider);
      if (widget.fixture != null) {
        await firestoreService.updateFixture(widget.fixture!['id'], {
          'name': name,
          'category': _selectedCategory,
          'date': dateIso,
          'matches': matchesList,
        });
      } else {
        await firestoreService.addFixture({
          'name': name,
          'category': _selectedCategory,
          'date': dateIso,
          'matches': matchesList,
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
    final categories = ref.watch(appCategoriesProvider);
    final categoryOptions = ['all', ...categories];

    return Dialog(
      backgroundColor: const Color(0xFF18181A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Editar Fecha del Fixture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Nombre de la Fecha ───
              RichText(
                text: const TextSpan(
                  text: 'Nombre de la Fecha ',
                  style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                  children: [
                    TextSpan(text: '*', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF242427),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF333338)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF333338)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5B842)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Fecha y Categoría ───
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha del Encuentro / Jornada',
                          style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _matchDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('es', 'ES'),
                            );
                            if (picked != null) {
                              setState(() => _matchDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242427),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF333338)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _matchDate != null ? _formatDateDisplay(_matchDate!) : 'DD/MM/AAAA',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categoría',
                          style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF242427),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF333338)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              dropdownColor: const Color(0xFF242427),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: categoryOptions.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat == 'all' ? 'Todas las Cat.' : cat),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Encuentro / Partido Container ───
              const Text(
                'Encuentro / Partido',
                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E2E33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Local
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Local', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF28282D),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF3A3A40)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _homeClubId,
                                    dropdownColor: const Color(0xFF28282D),
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: widget.clubs.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c['id'] as String,
                                        child: Text(c['name'] as String, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _homeClubId = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // VS
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE5B842),
                            ),
                          ),
                        ),
                        // Visitante
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  text: 'Visitante / Rival ',
                                  style: TextStyle(fontSize: 12, color: Colors.white70),
                                  children: [
                                    TextSpan(text: '*', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF28282D),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF3A3A40)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _awayClubId,
                                    dropdownColor: const Color(0xFF28282D),
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: widget.clubs.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c['id'] as String,
                                        child: Text(c['name'] as String, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _awayClubId = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hora del Partido
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hora del Partido', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _matchTime ?? const TimeOfDay(hour: 15, minute: 30),
                            );
                            if (picked != null) {
                              setState(() => _matchTime = picked);
                            }
                          },
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF28282D),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF3A3A40)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _matchTime != null ? _formatTimeDisplay(_matchTime!) : '15:30',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                const Icon(Icons.access_time, size: 16, color: Colors.white54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Botones Cancelar y Guardar Fecha ───
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      backgroundColor: const Color(0xFF242427),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      backgroundColor: const Color(0xFFE5B842),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text(
                            'Guardar Fecha',
                            style: TextStyle(color: Color(0xFF121212), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}