import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../core/providers/session_provider.dart';

class LineupScreen extends ConsumerStatefulWidget {
  const LineupScreen({super.key});

  @override
  ConsumerState<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends ConsumerState<LineupScreen> {
  final nextMatch = MockData.nextMatch;
  final List<Map<String, dynamic>> _allConvocados = List.from(MockData.convocatoria);
  
  // Local state for assignments: positionKey -> playerId
  final Map<String, String> _positions = {};
  bool _isSaving = false;

  final List<Map<String, dynamic>> _fieldPositions = [
    {'key': 'GK', 'label': 'ARQ', 'fullName': 'Arquero', 'align': const Alignment(0, 0.83)},
    {'key': 'LDF', 'label': '3', 'fullName': 'Defensa Izquierdo', 'align': const Alignment(-0.72, 0.50)},
    {'key': 'CDF1', 'label': '6', 'fullName': 'Central Izquierdo', 'align': const Alignment(-0.25, 0.55)},
    {'key': 'CDF2', 'label': '2', 'fullName': 'Central Derecho', 'align': const Alignment(0.25, 0.55)},
    {'key': 'RDF', 'label': '4', 'fullName': 'Defensa Derecho', 'align': const Alignment(0.72, 0.50)},
    {'key': 'LMF', 'label': '11', 'fullName': 'Mediocampista Izquierdo', 'align': const Alignment(-0.72, 0.08)},
    {'key': 'CMF1', 'label': '5', 'fullName': 'Mediocampista Central L', 'align': const Alignment(-0.25, 0.12)},
    {'key': 'CMF2', 'label': '8', 'fullName': 'Mediocampista Central R', 'align': const Alignment(0.25, 0.12)},
    {'key': 'RMF', 'label': '7', 'fullName': 'Mediocampista Derecho', 'align': const Alignment(0.72, 0.08)},
    {'key': 'LFW', 'label': '9', 'fullName': 'Delantero Izquierdo', 'align': const Alignment(-0.35, -0.52)},
    {'key': 'RFW', 'label': '10', 'fullName': 'Delantero Derecho', 'align': const Alignment(0.35, -0.52)},
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultMockLineup();
  }

  // Pre-populate with typical setup so field is never empty initially
  void _loadDefaultMockLineup() {
    _positions['GK'] = 'ply_003'; // Valentín Fernández
    _positions['CDF1'] = 'ply_006_d'; // Joaquín Sánchez
    _positions['CDF2'] = 'ply_006_e'; // Luciano Castro
    _positions['LDF'] = 'ply_006_a'; // Agustín Torres
    _positions['RDF'] = 'ply_004'; // Thiago López
    _positions['CMF1'] = 'ply_001'; // Mateo Gutiérrez
    _positions['CMF2'] = 'ply_005'; // Benjamín Rodríguez
    _positions['LMF'] = 'ply_006_c'; // Ignacio Díaz
    _positions['RMF'] = 'ply_006_f'; // Máximo Rivero
    _positions['LFW'] = 'ply_002'; // Santiago Morales
  }

  Future<void> _saveLineup() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('match_lineups').doc('next_match').set({
        'matchId': nextMatch['id'],
        'updatedAt': FieldValue.serverTimestamp(),
        'positions': _positions,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alineación guardada correctamente en Firestore.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar alineación: $e'),
            backgroundColor: AppColors.error,
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

  void _showPlayerSelector(BuildContext context, String posKey, String posName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
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
                  Text('Asignar Posición: $posName', style: AppTypography.headlineSmall),
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
                    border: Border.all(color: AppColors.textTertiary),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 18, color: AppColors.textTertiary),
                ),
                title: const Text('Vacante / Sin Asignar', style: TextStyle(fontWeight: FontWeight.w500)),
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
                  itemCount: _allConvocados.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, idx) {
                    final player = _allConvocados[idx];
                    final playerId = player['playerId'] as String;
                    
                    // Check if player is already assigned somewhere else
                    String? assignedPos;
                    _positions.forEach((k, v) {
                      if (v == playerId) assignedPos = k;
                    });

                    final isAlreadyAssigned = assignedPos != null;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JNAvatar(name: player['name'] as String, size: 38),
                      title: Text(player['name'] as String, style: AppTypography.titleMedium),
                      subtitle: Text('#${player['number']} · ${player['position']}', style: AppTypography.bodySmall),
                      trailing: isAlreadyAssigned
                          ? Text(
                              'Asignado en $assignedPos',
                              style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold),
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
    final currentUser = ref.watch(currentUserProvider) ?? SessionMocks.users['padre']!;
    final bool isCoach = currentUser.isCoach;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Formación del Equipo'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('match_lineups').doc('next_match').snapshots(),
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

          for (final player in _allConvocados) {
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
              // Next Match Info Banner
              JNCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.sports_soccer, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${nextMatch['awayTeam']} vs ${nextMatch['homeTeam']}', style: AppTypography.titleMedium),
                          Text(
                            'Fecha 6 · Cancha: ${nextMatch['venue']}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const JNBadge(label: 'CONVOCATORIA', type: JNBadgeType.accent),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // Tactical Field
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 400,
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
                        child: CustomPaint(
                          painter: _SoccerPitchPainter(),
                        ),
                      ),
                      
                      // Player circular positions
                      ..._fieldPositions.map((pos) {
                        final String key = pos['key'];
                        final Alignment align = pos['align'];
                        
                        final String? assignedPlayerId = _positions[key];
                        Map<String, dynamic>? playerDetails;
                        if (assignedPlayerId != null) {
                          playerDetails = _allConvocados.firstWhere(
                            (c) => c['playerId'] == assignedPlayerId,
                            orElse: () => <String, dynamic>{},
                          );
                        }

                        final bool hasPlayer = playerDetails != null && playerDetails.isNotEmpty;

                        return Align(
                          alignment: align,
                          child: GestureDetector(
                            onTap: isCoach
                                ? () => _showPlayerSelector(context, key, pos['fullName'])
                                : null,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Token
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: hasPlayer
                                        ? AppColors.primary
                                        : Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: hasPlayer ? Colors.white : AppColors.primary.withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: hasPlayer
                                        ? Text(
                                            '${playerDetails['number']}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : Icon(
                                            isCoach ? Icons.add : Icons.remove,
                                            size: 14,
                                            color: AppColors.primary.withValues(alpha: 0.8),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Label / Name
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 85),
                                  child: Text(
                                    hasPlayer
                                        ? (playerDetails['name'] as String).split(' ').last
                                        : key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ).animate(delay: 100.ms).fadeIn().scale(begin: const Offset(0.98, 0.98)),

              const SizedBox(height: 20),

              // Save alignment button for DT
              if (isCoach) ...[
                JNButton(
                  label: 'Guardar Formación Oficial',
                  icon: Icons.save,
                  onPressed: _saveLineup,
                  isLoading: _isSaving,
                  fullWidth: true,
                ).animate(delay: 200.ms).fadeIn(),
                const SizedBox(height: 24),
              ],

              // Starting List (Titulares)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Titulares (${starters.length})', style: AppTypography.headlineSmall),
                  const JNBadge(label: '11 TITULARES', type: JNBadgeType.info),
                ],
              ),
              const SizedBox(height: 8),
              if (starters.isEmpty)
                Text(
                  'El técnico aún no ha colocado jugadores en la cancha.',
                  style: AppTypography.bodySmall,
                )
              else
                ...starters.map((p) => _buildPlayerTile(p, true)),

              const SizedBox(height: 24),

              // Substitutes List (Suplentes)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Suplentes / Banquillo (${bench.length})', style: AppTypography.headlineSmall),
                  const JNBadge(label: 'BANCO', type: JNBadgeType.neutral),
                ],
              ),
              const SizedBox(height: 8),
              if (bench.isEmpty)
                Text(
                  'Todos los convocados están en la alineación titular.',
                  style: AppTypography.bodySmall,
                )
              else
                ...bench.map((p) => _buildPlayerTile(p, false)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerTile(Map<String, dynamic> player, bool isStarter) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: JNCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            JNAvatar(
              name: player['name'] as String,
              size: 36,
              borderColor: isStarter ? AppColors.success : AppColors.textTertiary,
              borderWidth: 1.5,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player['name'] as String, style: AppTypography.titleMedium),
                  Text('#${player['number']} · ${player['position']}', style: AppTypography.bodySmall),
                ],
              ),
            ),
            JNBadge(
              label: isStarter ? 'TITULAR' : 'SUPLENTE',
              type: isStarter ? JNBadgeType.success : JNBadgeType.neutral,
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
    canvas.drawCircle(Offset(size.width / 2, midY), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.22));

    // Penalty box - top side (away)
    final topPenalty = Rect.fromLTWH(size.width * 0.18, 8, size.width * 0.64, size.height * 0.18);
    canvas.drawRect(topPenalty, paint);
    // top penalty arc
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.18 + 8), width: 60, height: 26),
      0,
      3.14159,
      false,
      paint,
    );

    // Penalty box - bottom side (home)
    final bottomPenalty = Rect.fromLTWH(size.width * 0.18, size.height * 0.82 - 8, size.width * 0.64, size.height * 0.18);
    canvas.drawRect(bottomPenalty, paint);
    // bottom penalty arc
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.82 - 8), width: 60, height: 26),
      3.14159,
      3.14159,
      false,
      paint,
    );

    // Goal boxes
    final topGoal = Rect.fromLTWH(size.width * 0.35, 8, size.width * 0.3, size.height * 0.06);
    canvas.drawRect(topGoal, paint);
    final bottomGoal = Rect.fromLTWH(size.width * 0.35, size.height * 0.94 - 8, size.width * 0.3, size.height * 0.06);
    canvas.drawRect(bottomGoal, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
