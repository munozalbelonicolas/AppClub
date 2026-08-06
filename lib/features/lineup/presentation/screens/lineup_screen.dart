import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

class LineupScreen extends ConsumerStatefulWidget {
  const LineupScreen({super.key});

  @override
  ConsumerState<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends ConsumerState<LineupScreen> {
  // Local state for assignments: positionKey -> playerId
  final Map<String, String> _positions = {};
  bool _isSaving = false;
  String? _selectedCategory;

  final List<Map<String, dynamic>> _fieldPositions = [
    {
      'key': 'GK',
      'label': 'ARQ',
      'fullName': 'Arquero',
      'align': const Alignment(0, 0.83),
    },
    {
      'key': 'LDF',
      'label': '3',
      'fullName': 'Defensa Izquierdo',
      'align': const Alignment(-0.72, 0.50),
    },
    {
      'key': 'CDF1',
      'label': '6',
      'fullName': 'Central Izquierdo',
      'align': const Alignment(-0.25, 0.55),
    },
    {
      'key': 'CDF2',
      'label': '2',
      'fullName': 'Central Derecho',
      'align': const Alignment(0.25, 0.55),
    },
    {
      'key': 'RDF',
      'label': '4',
      'fullName': 'Defensa Derecho',
      'align': const Alignment(0.72, 0.50),
    },
    {
      'key': 'LMF',
      'label': '11',
      'fullName': 'Mediocampista Izquierdo',
      'align': const Alignment(-0.72, 0.08),
    },
    {
      'key': 'CMF1',
      'label': '5',
      'fullName': 'Mediocampista Central L',
      'align': const Alignment(-0.25, 0.12),
    },
    {
      'key': 'CMF2',
      'label': '8',
      'fullName': 'Mediocampista Central R',
      'align': const Alignment(0.25, 0.12),
    },
    {
      'key': 'RMF',
      'label': '7',
      'fullName': 'Mediocampista Derecho',
      'align': const Alignment(0.72, 0.08),
    },
    {
      'key': 'LFW',
      'label': '9',
      'fullName': 'Delantero Izquierdo',
      'align': const Alignment(-0.35, -0.52),
    },
    {
      'key': 'RFW',
      'label': '10',
      'fullName': 'Delantero Derecho',
      'align': const Alignment(0.35, -0.52),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultMockLineup();
  }

  // Pre-populate with typical setup so field is never empty initially
  void _loadDefaultMockLineup() {
    // Left empty for production, will fetch from Firestore
  }

  Future<void> _saveLineup(Map<String, dynamic>? nextMatch) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('match_lineups')
          .doc(nextMatch?['id'] ?? 'next_match')
          .set({
            'matchId': nextMatch?['id'] ?? 'next_match',
            'updatedAt': FieldValue.serverTimestamp(),
            'positions': _positions,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alineación guardada correctamente en Firestore.'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar alineación: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showPlayerSelector(
    BuildContext context,
    String posKey,
    String posName,
    List<Map<String, dynamic>> allConvocadosList,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Asignar Posición: $posName',
                    style: context.typography.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.textTertiary),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.remove,
                    size: 18,
                    color: context.colors.textTertiary,
                  ),
                ),
                title: const Text(
                  'Vacante / Sin Asignar',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  setState(() {
                    _positions.remove(posKey);
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: allConvocadosList.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: context.colors.divider),
                  itemBuilder: (context, idx) {
                    final player = allConvocadosList[idx];
                    final playerId = player['playerId'] as String;

                    // Check if player is already assigned somewhere else
                    String? assignedPos;
                    _positions.forEach((k, v) {
                      if (v == playerId) assignedPos = k;
                    });

                    final isAlreadyAssigned = assignedPos != null;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JNAvatar(
                        name: player['name'] as String,
                        size: 38,
                      ),
                      title: Text(
                        player['name'] as String,
                        style: context.typography.titleMedium,
                      ),
                      subtitle: Text(
                        '#${player['number']} · ${player['position']}',
                        style: context.typography.bodySmall,
                      ),
                      trailing: isAlreadyAssigned
                          ? Text(
                              'Asignado en $assignedPos',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                      enabled: !isAlreadyAssigned || assignedPos == posKey,
                      onTap: () {
                        setState(() {
                          _positions[posKey] = playerId;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: const Text('Formación del Equipo'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isAdmin = currentUser.isAdmin;
    final bool isCoach = currentUser.isCoach;

    final matchesAsync = ref.watch(matchesStreamProvider);
    final allMatches = matchesAsync.valueOrNull ?? [];

    List<String> categories = ref.watch(appCategoriesProvider);
    if (isCoach) {
      final dtCats = currentUser.assignedCategories ?? [];
      categories = dtCats.isNotEmpty ? dtCats : (currentUser.category != null ? [currentUser.category!] : []);
    }

    if (_selectedCategory == null || (isCoach && !categories.contains(_selectedCategory))) {
      if (isAdmin && categories.isNotEmpty) {
        _selectedCategory = categories.first;
      } else if (isCoach && categories.isNotEmpty) {
        _selectedCategory = categories.first;
      } else if (currentUser.category != null) {
        _selectedCategory = currentUser.category;
      } else if (categories.isNotEmpty) {
        _selectedCategory = categories.first;
      }
    }

    final nextMatch = allMatches.where((m) => m['category'] == _selectedCategory).firstOrNull;
    
    final playersAsync = ref.watch(playersStreamProvider);
    final allCategoryPlayers = (playersAsync.valueOrNull ?? [])
        .where((p) => p['category'] == _selectedCategory)
        .map((p) => <String, dynamic>{
          'playerId': p['id'],
          'name': '${p['name']} ${p['lastName']}',
          'number': p['number'] ?? p['jerseyNumber'] ?? '',
          'position': p['position'] ?? 'Jugador',
        })
        .toList();

    final convocatoriaAsync = nextMatch != null 
        ? ref.watch(convocatoriaStreamProvider(nextMatch['id']))
        : const AsyncValue.data(<Map<String, dynamic>>[]);
        
    final rawConvocados = convocatoriaAsync.valueOrNull ?? [];
    final allConvocadosList = rawConvocados.isNotEmpty ? rawConvocados : allCategoryPlayers;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Formación del Equipo'), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('match_lineups')
            .doc(nextMatch?['id'] ?? 'next_match')
            .snapshots(),
        builder: (context, snapshot) {
          // If we received data from Firestore, sync our local positions state
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null && data['positions'] != null && !_isSaving) {
              final rawPositions = data['positions'] as Map<String, dynamic>;
              _positions.clear();
              rawPositions.forEach((k, v) {
                _positions[k] = v.toString();
              });
            }
          }

          // Build lists for starting XI and bench
          final List<Map<String, dynamic>> starters = [];
          final List<Map<String, dynamic>> bench = [];

          for (final player in allConvocadosList) {
            final playerId = player['playerId'] as String;
            final isAssigned = _positions.values.contains(playerId);
            if (isAssigned) {
              starters.add(player);
            } else {
              bench.add(player);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              if (categories.isNotEmpty && (isAdmin || (isCoach && (currentUser.assignedCategories?.length ?? 0) > 1)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedCategory) {
                        setState(() {
                          _selectedCategory = val;
                          _positions.clear();
                        });
                      }
                    },
                  ),
                ),
              // Next Match Info Banner
              if (nextMatch != null)
                JNCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        color: context.colors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${nextMatch['awayTeam']} vs ${nextMatch['homeTeam']}',
                              style: context.typography.titleMedium,
                            ),
                            Text(
                              'Fecha 6 · Cancha: ${nextMatch['venue']}',
                              style: context.typography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const JNBadge(
                        label: 'CONVOCATORIA',
                        type: JNBadgeType.accent,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

              if (nextMatch != null) const SizedBox(height: 16),

              if (nextMatch == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 48,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay próximo partido',
                          style: context.typography.titleMedium.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Tactical Field as Background Graphic
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF153d2f), // Pitch upper green
                        Color(0xFF235c47), // Pitch middle green
                        Color(0xFF1c4a39), // Pitch lower green
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Soccer pitch lines painter
                      Positioned.fill(
                        child: CustomPaint(painter: _SoccerPitchPainter()),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Formación de Equipo',
                              style: context.typography.headlineMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Categoría: ${_selectedCategory ?? ''}',
                              style: TextStyle(
                                color: context.colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 100.ms).fadeIn().scale(begin: const Offset(0.98, 0.98)),

              const SizedBox(height: 20),

              // Save alignment button for DT
              if (isCoach) ...[
                JNButton(
                  label: 'Guardar Alineación',
                  icon: Icons.save,
                  onPressed: () => _saveLineup(nextMatch),
                  isLoading: _isSaving,
                  fullWidth: true,
                ).animate(delay: 200.ms).fadeIn(),
                const SizedBox(height: 24),
              ],

              // DYNAMIC DISPLAY: IF NO STARTERS -> Show ONLY "Jugadores Convocados"
              if (starters.isEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jugadores Convocados (${allConvocadosList.length})',
                      style: context.typography.headlineSmall,
                    ),
                    const JNBadge(label: 'CONVOCATORIA', type: JNBadgeType.accent),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca en ⭐ Titular para asignar los titulares del partido.',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 12),
                if (allConvocadosList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No hay jugadores convocados registrados.',
                        style: context.typography.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...allConvocadosList.map((p) => _buildPlayerTile(p, false, isCoach)),
              ] else ...[
                // IF STARTERS ARE SELECTED -> Show TWO SEPARATE SECTIONS ("Titulares ⭐" and "Convocados / Suplentes")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Titulares ⭐ (${starters.length})',
                      style: context.typography.headlineSmall.copyWith(
                        color: context.colors.accent,
                      ),
                    ),
                    const JNBadge(label: 'CONFIRMADOS', type: JNBadgeType.accent),
                  ],
                ),
                const SizedBox(height: 12),
                ...starters.map((p) => _buildPlayerTile(p, true, isCoach)),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Convocados / Suplentes (${bench.length})',
                      style: context.typography.headlineSmall,
                    ),
                    const JNBadge(label: 'SUPLENTES'),
                  ],
                ),
                const SizedBox(height: 12),
                if (bench.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Todos los convocados son titulares.',
                      style: context.typography.bodySmall,
                    ),
                  )
                else
                  ...bench.map((p) => _buildPlayerTile(p, false, isCoach)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerTile(Map<String, dynamic> player, bool isStarter, bool isCoach) {
    final playerId = player['playerId'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: JNCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            JNAvatar(
              name: player['name'] as String,
              size: 36,
              borderColor: isStarter
                  ? context.colors.accent
                  : context.colors.textTertiary,
              borderWidth: 1.5,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isStarter ? '⭐ ' : ''}${player['name']}',
                    style: context.typography.titleMedium.copyWith(
                      color: isStarter ? context.colors.accent : context.colors.textPrimary,
                      fontWeight: isStarter ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    '#${player['number']} · ${player['position']}',
                    style: context.typography.bodySmall,
                  ),
                ],
              ),
            ),
            if (isCoach) ...[
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (isStarter) {
                      _positions.removeWhere((k, v) => v == playerId);
                    } else {
                      // Assign to next unassigned position or generic starter key
                      final unassignedKey = _fieldPositions.firstWhere(
                        (p) => !_positions.containsKey(p['key']),
                        orElse: () => {'key': 'STARTER_$playerId'},
                      )['key'] as String;
                      _positions[unassignedKey] = playerId;
                    }
                  });
                },
                icon: Icon(
                  Icons.star,
                  size: 16,
                  color: isStarter ? context.colors.accent : context.colors.textTertiary,
                ),
                label: Text(
                  isStarter ? 'Quitar' : '⭐ Titular',
                  style: TextStyle(
                    fontSize: 12,
                    color: isStarter ? context.colors.accent : context.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            JNBadge(
              label: isStarter ? 'TITULAR' : 'SUPLENTE',
              type: isStarter ? JNBadgeType.accent : JNBadgeType.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoccerPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Pitch borders
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(rect, paint);

    // Center line
    final midY = size.height / 2;
    canvas.drawLine(Offset(8, midY), Offset(size.width - 8, midY), paint);

    // Center Circle
    canvas.drawCircle(Offset(size.width / 2, midY), 45, paint);
    canvas.drawCircle(
      Offset(size.width / 2, midY),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // Penalty box - top side (away)
    final topPenalty = Rect.fromLTWH(
      size.width * 0.18,
      8,
      size.width * 0.64,
      size.height * 0.18,
    );
    canvas.drawRect(topPenalty, paint);
    // top penalty arc
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.18 + 8),
        width: 60,
        height: 26,
      ),
      0,
      3.14159,
      false,
      paint,
    );

    // Penalty box - bottom side (home)
    final bottomPenalty = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.82 - 8,
      size.width * 0.64,
      size.height * 0.18,
    );
    canvas.drawRect(bottomPenalty, paint);
    // bottom penalty arc
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.82 - 8),
        width: 60,
        height: 26,
      ),
      3.14159,
      3.14159,
      false,
      paint,
    );

    // Goal boxes
    final topGoal = Rect.fromLTWH(
      size.width * 0.35,
      8,
      size.width * 0.3,
      size.height * 0.06,
    );
    canvas.drawRect(topGoal, paint);
    final bottomGoal = Rect.fromLTWH(
      size.width * 0.35,
      size.height * 0.94 - 8,
      size.width * 0.3,
      size.height * 0.06,
    );
    canvas.drawRect(bottomGoal, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}