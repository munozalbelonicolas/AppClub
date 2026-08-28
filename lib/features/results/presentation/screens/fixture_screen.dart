import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../utils/league_jornada_utils.dart';

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

    final isPlayer = sessionUser.role == 'jugador';
    final playerCategory = sessionUser.category;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(isPlayer && playerCategory != null && playerCategory.isNotEmpty ? 'Fixture (Cat. $playerCategory)' : 'Fixture'),
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
              return _buildFixtureCard(fixture, clubs, sessionUser.isAdmin, playerCategory: isPlayer ? playerCategory : null);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: context.colors.error))),
      ),
    );
  }

  Future<void> _showSuspendByRainDialog(BuildContext context, Map<String, dynamic> fixture) async {
    final sessionUser = ref.read(currentUserProvider);
    final name = fixture['name'] ?? 'la jornada';
    final titleController = TextEditingController(text: '🌧️ Jornada Suspendida por Lluvia');
    final bodyController = TextEditingController(
      text: 'Atención: Por inclemencias climáticas, se suspenden los partidos de $name. Informaremos la reprogramación a la brevedad.',
    );
    bool sendPush = true;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF18181A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.thunderstorm, color: Color(0xFF38BDF8), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Suspender por Lluvia',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Deseas suspender todos los partidos de "$name"?',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF38BDF8),
                  checkColor: Colors.black,
                  title: const Text(
                    'Enviar Notificación Push a todos los usuarios',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  value: sendPush,
                  onChanged: (val) => setDialogState(() => sendPush = val ?? true),
                ),
                if (sendPush) ...[
                  const SizedBox(height: 8),
                  const Text('Título de la Notificación:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF242427),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF333338))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Mensaje a enviar:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: bodyController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF242427),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF333338))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.thunderstorm, size: 18),
              label: const Text('Suspender y Notificar', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final rawMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
                        final updatedMatches = rawMatches.map((m) {
                          return {
                            ...m,
                            'status': 'suspended',
                            'suspensionReason': 'Lluvia',
                          };
                        }).toList();

                        // 1. Actualizar fixture en Firestore
                        await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
                          'isSuspended': true,
                          'suspensionReason': 'Lluvia',
                          'matches': updatedMatches,
                        });

                        // 2. Enviar notificación push si está marcado
                        if (sendPush && sessionUser != null) {
                          await NotificationService().sendNotification(
                            title: titleController.text.trim(),
                            body: bodyController.text.trim(),
                            authorId: sessionUser.id,
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🌧️ Jornada suspendida por lluvia y notificada a todos los usuarios.'),
                              backgroundColor: Color(0xFF0284C7),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al suspender: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => isSaving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResumeFixtureDialog(BuildContext context, Map<String, dynamic> fixture) async {
    final name = fixture['name'] ?? 'la jornada';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: Color(0xFFE5B842), size: 24),
            SizedBox(width: 10),
            Text('Reanudar / Habilitar Fecha', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Deseas quitar la suspensión de "$name" y volver a habilitar los partidos como programados?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5B842),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Habilitar Fecha', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final rawMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
      final updatedMatches = rawMatches.map((m) {
        return {
          ...m,
          'status': 'scheduled',
          'suspensionReason': null,
        };
      }).toList();

      await ref.read(firestoreServiceProvider).updateFixture(fixture['id'], {
        'isSuspended': false,
        'suspensionReason': null,
        'matches': updatedMatches,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('☀️ Fecha reanudada y habilitada.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
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

  Widget _buildFixtureCard(Map<String, dynamic> fixture, List<Map<String, dynamic>> clubs, bool isAdmin, {String? playerCategory}) {
    final allMatches = List<Map<String, dynamic>>.from(fixture['matches'] ?? []);
    final matches = (playerCategory != null && playerCategory.isNotEmpty)
        ? allMatches.where((m) {
            final cat = m['category']?.toString();
            return cat == null || cat == 'all' || cat == playerCategory;
          }).toList()
        : allMatches;

    if (playerCategory != null && playerCategory.isNotEmpty && matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isFixtureSuspended = fixture['isSuspended'] == true ||
        (allMatches.isNotEmpty && allMatches.every((m) => m['status'] == 'suspended'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: JNCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header de la Tarjeta ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fixture['name'] ?? 'Fecha',
                        style: context.typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (fixture['venue'] != null && fixture['venue'].toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              fixture['isHomeVenue'] == false
                                  ? Icons.directions_bus_outlined
                                  : Icons.stadium_outlined,
                              size: 13,
                              color: fixture['isHomeVenue'] == false
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFFE5B842),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${fixture['venue']}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: fixture['isHomeVenue'] == false
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFFE5B842),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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

            // ─── Botón Suspender por lluvia / Reanudar (Debajo del label de fecha) ───
            if (isAdmin) ...[
              const SizedBox(height: 8),
              if (isFixtureSuspended)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                  ),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.amber),
                  label: const Text('Reanudar Fecha', style: TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _showResumeFixtureDialog(context, fixture),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF38BDF8), width: 0.8),
                    ),
                  ),
                  icon: const Icon(Icons.thunderstorm, size: 14, color: Color(0xFF38BDF8)),
                  label: const Text('Suspender por lluvia', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _showSuspendByRainDialog(context, fixture),
                ),
            ],

            // ─── Banner de Jornada Suspendida ───
            if (isFixtureSuspended) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.thunderstorm, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'JORNADA SUSPENDIDA POR LLUVIA',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            ...matches.map((m) {
              final homeClub = findMatchingClub(clubs, m['homeClubId']?.toString() ?? m['homeTeam']?.toString());
              final awayClub = findMatchingClub(clubs, m['awayClubId']?.toString() ?? m['awayTeam']?.toString());
              final bool isMatchSuspended = m['status'] == 'suspended';

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
                          if (m['category'] != null && m['category'].toString().isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m['category'].toString().startsWith('20') ? 'Cat. ${m['category']}' : '${m['category']}',
                                  style: context.typography.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.primary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (m['isPromotional'] == true) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 0.5),
                                    ),
                                    child: const Text(
                                      'PROMO',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.orange,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                          ],
                          if (isMatchSuspended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 0.5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.thunderstorm, size: 10, color: Color(0xFF38BDF8)),
                                  SizedBox(width: 3),
                                  Text(
                                    'SUSPENDIDO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textTertiary)),
                          if (m['time'] != null && m['time'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: context.colors.accent.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 10, color: context.colors.accent),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${m['time']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    final name = club?['name']?.toString() ?? '';
    final isLocal = club?['isLocal'] == true ||
        name.toLowerCase().contains('newbery') ||
        name.toLowerCase().contains('jn');
    final logoUrl = club?['logoUrl']?.toString() ??
        club?['shieldUrl']?.toString() ??
        club?['imageUrl']?.toString() ??
        club?['logo']?.toString();

    if (isLocal) {
      return Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5B842), width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/app_logo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.shield, size: 20, color: Color(0xFFE5B842)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(name.isNotEmpty ? name : 'Jorge Newbery', style: context.typography.labelSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      );
    }

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: ClipOval(
            child: logoUrl != null && logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF27272A),
                      child: Center(
                        child: Text(initial, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFE5B842))),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF27272A),
                    child: Center(
                      child: Text(initial, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFE5B842))),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: context.typography.labelSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
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
  bool _isHomeVenue = true;
  bool _isSaving = false;
  final Set<String> _promotionalCategories = {};
  final Map<String, TimeOfDay> _categoryTimes = {};

  TimeOfDay? _parseTime(dynamic raw) {
    if (raw == null) return null;
    try {
      final clean = raw.toString().replaceAll('hs', '').replaceAll('Hs', '').replaceAll('HS', '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return null;
  }

  static const Map<String, TimeOfDay> kOfficialUCIVSchedule = {
    '2011': TimeOfDay(hour: 10, minute: 0),
    '2012': TimeOfDay(hour: 10, minute: 50),
    '2013': TimeOfDay(hour: 11, minute: 40),
    '2014': TimeOfDay(hour: 12, minute: 30),
    '2015': TimeOfDay(hour: 13, minute: 20),
    '2016': TimeOfDay(hour: 17, minute: 20),
    '2017': TimeOfDay(hour: 16, minute: 30),
    '2018': TimeOfDay(hour: 15, minute: 40),
    '2019': TimeOfDay(hour: 14, minute: 50),
    '2020': TimeOfDay(hour: 14, minute: 10),
  };

  List<String> _sortCategories(List<String> raw) {
    final list = List<String>.from(raw);
    list.sort((a, b) {
      final numA = int.tryParse(a);
      final numB = int.tryParse(b);
      if (numA != null && numB != null) return numA.compareTo(numB);
      return a.compareTo(b);
    });
    return list;
  }

  void _setVenueMode(bool isHome) {
    setState(() {
      _isHomeVenue = isHome;
    });
  }

  void _applyOfficialSchedule() {
    setState(() {
      _promotionalCategories.remove('2019');
      _promotionalCategories.add('2020');
      kOfficialUCIVSchedule.forEach((cat, time) {
        _categoryTimes[cat] = time;
      });
    });
  }

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

    final existingVenue = f?['venue']?.toString() ??
        f?['location']?.toString() ??
        firstMatch?['venue']?.toString() ??
        firstMatch?['location']?.toString();
    final isHomeVenueStored = f?['isHomeVenue'] ?? firstMatch?['isHomeVenue'];

    if (isHomeVenueStored != null) {
      _isHomeVenue = isHomeVenueStored == true;
    } else if (existingVenue != null && existingVenue.isNotEmpty) {
      _isHomeVenue = !existingVenue.toLowerCase().contains('visitante');
    } else {
      _isHomeVenue = true;
    }

    if (f != null) {
      for (final m in matches) {
        if (m['isPromotional'] == true) {
          final cat = m['category']?.toString();
          if (cat != null && cat.isNotEmpty) {
            _promotionalCategories.add(cat);
          }
        }
      }
    } else {
      // Default promocionales for new fixtures (only 2020)
      _promotionalCategories.add('2020');
    }

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
    _matchTime = _parseTime(rawTime) ?? const TimeOfDay(hour: 10, minute: 0);

    // Initialize category times (prioritize existing match times, or fall back to official UCIV schedule)
    final categories = ref.read(appCategoriesProvider);
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final matchForCat = matches.where((m) => m['category'] == cat).firstOrNull;
      final parsed = _parseTime(matchForCat?['time']);
      if (parsed != null) {
        _categoryTimes[cat] = parsed;
      } else if (kOfficialUCIVSchedule.containsKey(cat)) {
        _categoryTimes[cat] = kOfficialUCIVSchedule[cat]!;
      } else {
        _categoryTimes[cat] = _matchTime ?? const TimeOfDay(hour: 10, minute: 0);
      }
    }
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

  void _autoScheduleTimes(TimeOfDay startTime, int intervalMinutes) {
    final categories = ref.read(appCategoriesProvider);
    int currentMinutes = startTime.hour * 60 + startTime.minute;
    setState(() {
      for (final cat in categories) {
        final h = (currentMinutes ~/ 60) % 24;
        final m = currentMinutes % 60;
        _categoryTimes[cat] = TimeOfDay(hour: h, minute: m);
        currentMinutes += intervalMinutes;
      }
    });
  }

  void _applyTimeToAll(TimeOfDay time) {
    final categories = ref.read(appCategoriesProvider);
    setState(() {
      for (final cat in categories) {
        _categoryTimes[cat] = time;
      }
    });
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
      final rawCategories = ref.read(appCategoriesProvider);
      final categories = _sortCategories(rawCategories);
      final List<Map<String, dynamic>> matchesList = [];
      final existingMatches = List<Map<String, dynamic>>.from(widget.fixture?['matches'] ?? []);
      final venueStr = _isHomeVenue ? 'Cancha Local' : 'Cancha Visitante';

      if (_selectedCategory == 'all' || _selectedCategory.isEmpty) {
        for (final cat in categories) {
          final isPromo = _promotionalCategories.contains(cat);
          final catTime = _categoryTimes[cat] ?? _matchTime ?? const TimeOfDay(hour: 10, minute: 0);
          final timeStr = _formatTimeDisplay(catTime);
          final existing = existingMatches.where((m) => m['category'] == cat).firstOrNull;
          if (existing != null) {
            matchesList.add({
              ...existing,
              'category': cat,
              'homeClubId': _homeClubId,
              'awayClubId': _awayClubId,
              'date': dateIso,
              'time': timeStr,
              'isPromotional': isPromo,
              'venue': venueStr,
              'location': venueStr,
              'isHomeVenue': _isHomeVenue,
            });
          } else {
            matchesList.add({
              'category': cat,
              'homeClubId': _homeClubId,
              'awayClubId': _awayClubId,
              'date': dateIso,
              'time': timeStr,
              'status': 'scheduled',
              'homeScore': null,
              'awayScore': null,
              'scorers': [],
              'isPromotional': isPromo,
              'venue': venueStr,
              'location': venueStr,
              'isHomeVenue': _isHomeVenue,
            });
          }
        }
      } else {
        final isPromo = _promotionalCategories.contains(_selectedCategory);
        final catTime = _categoryTimes[_selectedCategory] ?? _matchTime ?? const TimeOfDay(hour: 10, minute: 0);
        final timeStr = _formatTimeDisplay(catTime);
        final existing = existingMatches.where((m) => m['category'] == _selectedCategory).firstOrNull ??
            (existingMatches.isNotEmpty ? existingMatches.first : null);
        if (existing != null) {
          matchesList.add({
            ...existing,
            'category': _selectedCategory,
            'homeClubId': _homeClubId,
            'awayClubId': _awayClubId,
            'date': dateIso,
            'time': timeStr,
            'isPromotional': isPromo,
            'venue': venueStr,
            'location': venueStr,
            'isHomeVenue': _isHomeVenue,
          });
        } else {
          matchesList.add({
            'category': _selectedCategory,
            'homeClubId': _homeClubId,
            'awayClubId': _awayClubId,
            'date': dateIso,
            'time': timeStr,
            'status': 'scheduled',
            'homeScore': null,
            'awayScore': null,
            'scorers': [],
            'isPromotional': isPromo,
            'venue': venueStr,
            'location': venueStr,
            'isHomeVenue': _isHomeVenue,
          });
        }
      }

      final firestoreService = ref.read(firestoreServiceProvider);
      if (widget.fixture != null) {
        await firestoreService.updateFixture(widget.fixture!['id'], {
          'name': name,
          'category': _selectedCategory,
          'date': dateIso,
          'venue': venueStr,
          'location': venueStr,
          'isHomeVenue': _isHomeVenue,
          'matches': matchesList,
        });
      } else {
        await firestoreService.addFixture({
          'name': name,
          'category': _selectedCategory,
          'date': dateIso,
          'venue': venueStr,
          'location': venueStr,
          'isHomeVenue': _isHomeVenue,
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
    final rawCategories = ref.watch(appCategoriesProvider);
    final sortedCategories = _sortCategories(rawCategories);
    final Set<String> categorySet = {'all', ...sortedCategories};
    if (_selectedCategory.isNotEmpty) {
      categorySet.add(_selectedCategory);
    }
    final categoryOptions = categorySet.toList();
    final effectiveCategory = categoryOptions.contains(_selectedCategory) ? _selectedCategory : 'all';

    final effectiveHomeClubId = widget.clubs.any((c) => c['id'] == _homeClubId)
        ? _homeClubId
        : (widget.clubs.isNotEmpty ? widget.clubs.first['id'] as String? : null);

    final effectiveAwayClubId = widget.clubs.any((c) => c['id'] == _awayClubId)
        ? _awayClubId
        : (widget.clubs.length > 1
            ? widget.clubs[1]['id'] as String?
            : (widget.clubs.isNotEmpty ? widget.clubs.first['id'] as String? : null));

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
                          'Fecha de la Jornada',
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
                              value: effectiveCategory,
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
              const SizedBox(height: 16),

              // ─── Categorías Promocionales (Exhibición) ───
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF242427),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333338)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star_outline, color: Color(0xFFE5B842), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Categorías Promocionales (Exhibición)',
                            style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Los partidos promocionales no computan puntos en la tabla de posiciones.',
                      style: TextStyle(fontSize: 11, color: Colors.white60, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    if (effectiveCategory == 'all') ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sortedCategories.map((cat) {
                          final isPromo = _promotionalCategories.contains(cat);
                          return FilterChip(
                            label: Text(cat),
                            selected: isPromo,
                            selectedColor: const Color(0xFFE5B842),
                            checkmarkColor: Colors.black,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isPromo ? FontWeight.bold : FontWeight.normal,
                              color: isPromo ? Colors.black : Colors.white70,
                            ),
                            backgroundColor: const Color(0xFF1E1E22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: isPromo ? const Color(0xFFE5B842) : const Color(0xFF3A3A40),
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _promotionalCategories.add(cat);
                                } else {
                                  _promotionalCategories.remove(cat);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Marcar Cat. $effectiveCategory como Promocional',
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        value: _promotionalCategories.contains(effectiveCategory),
                        activeColor: const Color(0xFFE5B842),
                        checkColor: Colors.black,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _promotionalCategories.add(effectiveCategory);
                            } else {
                              _promotionalCategories.remove(effectiveCategory);
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Encuentro / Equipos y Cancha ───
              const Text(
                'Encuentro / Partido',
                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E2E33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Equipos Local y Visitante
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
                                    value: effectiveHomeClubId,
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
                                    value: effectiveAwayClubId,
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
                    const Divider(color: Color(0xFF2E2E33), height: 1),
                    const SizedBox(height: 12),

                    // ─── Cancha Local o Visitante ───
                    const Text(
                      'Cancha / Condición',
                      style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _setVenueMode(true),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _isHomeVenue ? const Color(0xFFE5B842).withValues(alpha: 0.2) : const Color(0xFF242427),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isHomeVenue ? const Color(0xFFE5B842) : const Color(0xFF333338),
                                  width: _isHomeVenue ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stadium_outlined,
                                    size: 16,
                                    color: _isHomeVenue ? const Color(0xFFE5B842) : Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cancha Local',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _isHomeVenue ? FontWeight.bold : FontWeight.normal,
                                      color: _isHomeVenue ? const Color(0xFFE5B842) : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _setVenueMode(false),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: !_isHomeVenue ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : const Color(0xFF242427),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !_isHomeVenue ? const Color(0xFF38BDF8) : const Color(0xFF333338),
                                  width: !_isHomeVenue ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_bus_outlined,
                                    size: 16,
                                    color: !_isHomeVenue ? const Color(0xFF38BDF8) : Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cancha Visitante',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_isHomeVenue ? FontWeight.bold : FontWeight.normal,
                                      color: !_isHomeVenue ? const Color(0xFF38BDF8) : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Sección: Horarios por Categoría (UCIV Oficial) ───
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.schedule, color: Color(0xFFE5B842), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Horarios por Categoría (UCIV)',
                              style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (effectiveCategory == 'all')
                          PopupMenuButton<String>(
                            color: const Color(0xFF28282D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            icon: const Icon(Icons.auto_fix_high, color: Color(0xFFE5B842), size: 20),
                            tooltip: 'Opciones de horarios',
                            onSelected: (val) {
                              if (val == 'uciv') {
                                _applyOfficialSchedule();
                              } else {
                                final baseTime = _matchTime ?? const TimeOfDay(hour: 10, minute: 0);
                                if (val == '50') {
                                  _autoScheduleTimes(baseTime, 50);
                                } else if (val == '60') {
                                  _autoScheduleTimes(baseTime, 60);
                                } else if (val == 'same') {
                                  _applyTimeToAll(baseTime);
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'uciv',
                                child: Row(
                                  children: [
                                    Icon(Icons.emoji_events, color: Color(0xFFE5B842), size: 16),
                                    SizedBox(width: 8),
                                    Text('Horarios Oficiales UCIV', style: TextStyle(color: Color(0xFFE5B842), fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: '50',
                                child: Text('Escalonar cada 50 min (desde hora base)', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ),
                              const PopupMenuItem(
                                value: '60',
                                child: Text('Escalonar cada 60 min (1 hora)', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ),
                              const PopupMenuItem(
                                value: 'same',
                                child: Text('Misma hora para todas', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Configura la hora a la que juega cada categoría según el cronograma oficial de la liga.',
                      style: TextStyle(fontSize: 11, color: Colors.white60, height: 1.3),
                    ),
                    const SizedBox(height: 12),

                    // Botón Destacado: Cargar Horarios Oficiales UCIV
                    if (effectiveCategory == 'all') ...[
                      InkWell(
                        onTap: _applyOfficialSchedule,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFE5B842).withValues(alpha: 0.25),
                                const Color(0xFFB45309).withValues(alpha: 0.20),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5B842).withValues(alpha: 0.6)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt, color: Color(0xFFE5B842), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Cargar Horarios Oficiales UCIV',
                                style: TextStyle(
                                  color: Color(0xFFE5B842),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Hora Base y Auto-escalonar
                    Row(
                      children: [
                        const Text('Hora Base:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _matchTime ?? const TimeOfDay(hour: 10, minute: 0),
                            );
                            if (picked != null) {
                              setState(() {
                                _matchTime = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF28282D),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3A3A40)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _matchTime != null ? _formatTimeDisplay(_matchTime!) : '10:00',
                                  style: const TextStyle(color: Color(0xFFE5B842), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.access_time, size: 14, color: Color(0xFFE5B842)),
                              ],
                            ),
                          ),
                        ),
                        if (effectiveCategory == 'all') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                side: const BorderSide(color: Color(0xFF3A3A40)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                _autoScheduleTimes(_matchTime ?? const TimeOfDay(hour: 10, minute: 0), 50);
                              },
                              child: const Text('Auto-escalonar (+50m)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de Categorías con sus Horarios Individuales (En orden cronológico de juego)
                    if (effectiveCategory == 'all') ...[
                      Column(
                        children: sortedCategories.map((cat) {
                          final timeForCat = _categoryTimes[cat] ?? _matchTime ?? const TimeOfDay(hour: 10, minute: 0);
                          final isPromo = _promotionalCategories.contains(cat);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242427),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF333338)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5B842).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        cat.startsWith('20') ? 'Cat. $cat' : cat,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE5B842)),
                                      ),
                                    ),
                                    if (isPromo) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 0.5),
                                        ),
                                        child: const Text(
                                          'PROMO',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: timeForCat,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _categoryTimes[cat] = picked;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E2E33),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF444448)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.access_time, size: 14, color: Color(0xFFE5B842)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_formatTimeDisplay(timeForCat)} hs',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit, size: 12, color: Colors.white38),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Builder(
                        builder: (context) {
                          final timeForCat = _categoryTimes[effectiveCategory] ?? _matchTime ?? const TimeOfDay(hour: 10, minute: 0);
                          return InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: timeForCat,
                              );
                              if (picked != null) {
                                setState(() {
                                  _categoryTimes[effectiveCategory] = picked;
                                });
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
                                    'Horario Cat. $effectiveCategory:',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 16, color: Color(0xFFE5B842)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_formatTimeDisplay(timeForCat)} hs',
                                        style: const TextStyle(color: Color(0xFFE5B842), fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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