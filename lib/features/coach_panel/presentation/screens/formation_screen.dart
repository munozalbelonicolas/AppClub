import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_logger.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../widgets/soccer_pitch_view.dart';

// Predefined tactics with normalized coordinates (x, y) where 0,0 is top-left
final _tactics = {
  '5v5': {
    '1-2-1': {
      'GK': const Offset(0.5, 0.95),
      'DEF': const Offset(0.5, 0.75),
      'MID_L': const Offset(0.25, 0.5),
      'MID_R': const Offset(0.75, 0.5),
      'FWD': const Offset(0.5, 0.25),
    },
    '2-1-1': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.3, 0.75),
      'DEF_R': const Offset(0.7, 0.75),
      'MID': const Offset(0.5, 0.5),
      'FWD': const Offset(0.5, 0.25),
    },
    '1-1-2': {
      'GK': const Offset(0.5, 0.95),
      'DEF': const Offset(0.5, 0.75),
      'MID': const Offset(0.5, 0.5),
      'FWD_L': const Offset(0.3, 0.25),
      'FWD_R': const Offset(0.7, 0.25),
    },
  },
  '7v7': {
    '2-3-1': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.3, 0.8),
      'DEF_R': const Offset(0.7, 0.8),
      'MID_L': const Offset(0.2, 0.5),
      'MID_C': const Offset(0.5, 0.5),
      'MID_R': const Offset(0.8, 0.5),
      'FWD': const Offset(0.5, 0.2),
    },
    '3-2-1': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.2, 0.8),
      'DEF_C': const Offset(0.5, 0.8),
      'DEF_R': const Offset(0.8, 0.8),
      'MID_L': const Offset(0.35, 0.5),
      'MID_R': const Offset(0.65, 0.5),
      'FWD': const Offset(0.5, 0.2),
    },
    '2-2-2': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.3, 0.8),
      'DEF_R': const Offset(0.7, 0.8),
      'MID_L': const Offset(0.3, 0.5),
      'MID_R': const Offset(0.7, 0.5),
      'FWD_L': const Offset(0.3, 0.2),
      'FWD_R': const Offset(0.7, 0.2),
    },
  },
  '8v8': {
    '3-3-1': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.2, 0.8),
      'DEF_C': const Offset(0.5, 0.8),
      'DEF_R': const Offset(0.8, 0.8),
      'MID_L': const Offset(0.2, 0.5),
      'MID_C': const Offset(0.5, 0.5),
      'MID_R': const Offset(0.8, 0.5),
      'FWD': const Offset(0.5, 0.2),
    },
    '2-4-1': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.3, 0.8),
      'DEF_R': const Offset(0.7, 0.8),
      'MID_LL': const Offset(0.15, 0.5),
      'MID_LC': const Offset(0.4, 0.5),
      'MID_RC': const Offset(0.6, 0.5),
      'MID_RR': const Offset(0.85, 0.5),
      'FWD': const Offset(0.5, 0.2),
    },
    '3-2-2': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.2, 0.8),
      'DEF_C': const Offset(0.5, 0.8),
      'DEF_R': const Offset(0.8, 0.8),
      'MID_L': const Offset(0.35, 0.5),
      'MID_R': const Offset(0.65, 0.5),
      'FWD_L': const Offset(0.35, 0.2),
      'FWD_R': const Offset(0.65, 0.2),
    },
  },
  '11v11': {
    '4-3-3': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.15, 0.8),
      'DEF_LC': const Offset(0.38, 0.8),
      'DEF_RC': const Offset(0.62, 0.8),
      'DEF_R': const Offset(0.85, 0.8),
      'MID_L': const Offset(0.2, 0.5),
      'MID_C': const Offset(0.5, 0.5),
      'MID_R': const Offset(0.8, 0.5),
      'FWD_L': const Offset(0.25, 0.2),
      'FWD_C': const Offset(0.5, 0.2),
      'FWD_R': const Offset(0.75, 0.2),
    },
    '4-4-2': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.15, 0.8),
      'DEF_LC': const Offset(0.38, 0.8),
      'DEF_RC': const Offset(0.62, 0.8),
      'DEF_R': const Offset(0.85, 0.8),
      'MID_L': const Offset(0.15, 0.5),
      'MID_LC': const Offset(0.38, 0.5),
      'MID_RC': const Offset(0.62, 0.5),
      'MID_R': const Offset(0.85, 0.5),
      'FWD_L': const Offset(0.35, 0.2),
      'FWD_R': const Offset(0.65, 0.2),
    },
    '3-5-2': {
      'GK': const Offset(0.5, 0.95),
      'DEF_L': const Offset(0.2, 0.8),
      'DEF_C': const Offset(0.5, 0.8),
      'DEF_R': const Offset(0.8, 0.8),
      'MID_LL': const Offset(0.1, 0.5),
      'MID_LC': const Offset(0.3, 0.6),
      'MID_C': const Offset(0.5, 0.4),
      'MID_RC': const Offset(0.7, 0.6),
      'MID_RR': const Offset(0.9, 0.5),
      'FWD_L': const Offset(0.35, 0.2),
      'FWD_R': const Offset(0.65, 0.2),
    },
  },
};

final _formats = ['5v5', '7v7', '8v8', '11v11', 'Solo lista'];

class FormationScreen extends ConsumerStatefulWidget {
  final String matchId;

  const FormationScreen({super.key, required this.matchId});

  @override
  ConsumerState<FormationScreen> createState() => _FormationScreenState();
}

class _FormationScreenState extends ConsumerState<FormationScreen> {
  String _selectedFormat = '11v11';
  String _selectedTactic = '4-3-3';
  
  // slotId -> playerId
  final Map<String, String> _assignments = {};
  
  // For 'Solo lista' mode: list of playerIds
  final List<String> _calledUpPlayers = [];
  
  String _selectedCategoryFilter = 'Todas';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFormation();
  }

  Future<void> _loadFormation() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      // Try to load existing formation for this match
      final stream = firestoreService.getFormation(widget.matchId);
      final doc = await stream.first;
      
      if (doc != null) {
        setState(() {
          _selectedFormat = doc['format'] ?? '11v11';
          if (_selectedFormat != 'Solo lista') {
            _selectedTactic = doc['tactic'] ?? _tactics[_selectedFormat]!.keys.first;
            final assignments = doc['assignments'] as Map<String, dynamic>? ?? {};
            _assignments.clear();
            assignments.forEach((key, value) {
              _assignments[key] = value.toString();
            });
          } else {
            final calledUp = doc['calledUpPlayers'] as List<dynamic>? ?? [];
            _calledUpPlayers.clear();
            _calledUpPlayers.addAll(calledUp.map((e) => e.toString()));
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error loading formation', error: e, tag: 'FormationScreen');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFormation() async {
    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final data = {
        'format': _selectedFormat,
        if (_selectedFormat != 'Solo lista') 'tactic': _selectedTactic,
        if (_selectedFormat != 'Solo lista') 'assignments': _assignments,
        if (_selectedFormat == 'Solo lista') 'calledUpPlayers': _calledUpPlayers,
      };
      await firestoreService.saveFormation(widget.matchId, data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Formación guardada correctamente'),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPlayerSelectionSheet(String slotId, List<Map<String, dynamic>> players) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Filter out already assigned players
        final assignedIds = _assignments.values.toList();
        final availablePlayers = players.where((p) => !assignedIds.contains(p['id']) || _assignments[slotId] == p['id']).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Asignar jugador', style: context.typography.titleMedium),
              const SizedBox(height: 16),
              if (_assignments.containsKey(slotId))
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.colors.error.withValues(alpha: 0.1),
                    child: Icon(Icons.close, color: context.colors.error),
                  ),
                  title: Text('Quitar jugador', style: TextStyle(color: context.colors.error)),
                  onTap: () {
                    setState(() => _assignments.remove(slotId));
                    Navigator.pop(context);
                  },
                ),
              const Divider(),
              Expanded(
                child: availablePlayers.isEmpty
                    ? Center(child: Text('No hay jugadores disponibles', style: context.typography.bodyMedium))
                    : ListView.builder(
                        itemCount: availablePlayers.length,
                        itemBuilder: (context, index) {
                          final player = availablePlayers[index];
                          final isCurrent = _assignments[slotId] == player['id'];
                          
                          return ListTile(
                            leading: JNAvatar(
                              name: '${player['name']} ${player['lastName']}',
                              size: 40,
                              number: player['number'] as int?,
                            ),
                            title: Text('${player['name']} ${player['lastName']}'),
                            subtitle: Text('${player['position']}'),
                            trailing: isCurrent ? Icon(Icons.check, color: context.colors.primary) : null,
                            onTap: () {
                              setState(() => _assignments[slotId] = player['id']);
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
    final playersAsync = ref.watch(playersStreamProvider);
    final allPlayers = playersAsync.valueOrNull ?? [];

    final appCategories = ref.watch(appCategoriesProvider);
    final categories = ['Todas', ...appCategories];

    if (!categories.contains(_selectedCategoryFilter)) {
      _selectedCategoryFilter = 'Todas';
    }

    final players = _selectedCategoryFilter == 'Todas'
        ? allPlayers
        : allPlayers.where((p) => p['category'] == _selectedCategoryFilter).toList();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Formación', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveFormation,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Guardar', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Config Header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  color: context.colors.surface,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar Jugadores por Categoría',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null && val != _selectedCategoryFilter) {
                            setState(() {
                              _selectedCategoryFilter = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFormat,
                          decoration: const InputDecoration(
                            labelText: 'Formato',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (val) {
                            if (val != null && val != _selectedFormat) {
                              setState(() {
                                _selectedFormat = val;
                                if (val != 'Solo lista') {
                                  _selectedTactic = _tactics[val]!.keys.first;
                                  _assignments.clear();
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selectedFormat == 'Solo lista'
                            ? const SizedBox.shrink()
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedTactic,
                                decoration: const InputDecoration(
                                  labelText: 'Táctica',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: _tactics[_selectedFormat]!
                                    .keys
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null && val != _selectedTactic) {
                                    setState(() {
                                      _selectedTactic = val;
                                      _assignments.clear();
                                    });
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
                // Main Content
                Expanded(
                  child: _selectedFormat == 'Solo lista'
                      ? _buildListaMode(players)
                      : _buildPitchMode(players),
                ),
              ],
            ),
    );
  }

  Widget _buildPitchMode(List<Map<String, dynamic>> players) {
    final positions = _tactics[_selectedFormat]![_selectedTactic]!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SoccerPitchView(
            playerPositions: positions,
            slotBuilder: (slotId, position) {
              final assignedPlayerId = _assignments[slotId];
              final player = assignedPlayerId != null
                  ? players.firstWhere((p) => p['id'] == assignedPlayerId, orElse: () => {})
                  : null;
              
              final isAssigned = player != null && player.isNotEmpty;

              return GestureDetector(
                onTap: () => _showPlayerSelectionSheet(slotId, players),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isAssigned ? context.colors.primary : Colors.white.withValues(alpha: 0.5),
                      child: isAssigned
                          ? (player['number'] != null
                              ? Text('${player['number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              : Text(player['name'].toString().substring(0, 1), style: const TextStyle(color: Colors.white)))
                          : const Icon(Icons.add, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAssigned ? '${player['name']}' : slotId.replaceAll('_', ' '),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListaMode(List<Map<String, dynamic>> players) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final isSelected = _calledUpPlayers.contains(player['id']);

        return CheckboxListTile(
          value: isSelected,
          activeColor: context.colors.primary,
          title: Text('${player['name']} ${player['lastName']}'),
          subtitle: Text('${player['position']}'),
          secondary: JNAvatar(
            name: '${player['name']} ${player['lastName']}',
            size: 40,
            number: player['number'] as int?,
          ),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _calledUpPlayers.add(player['id']);
              } else {
                _calledUpPlayers.remove(player['id']);
              }
            });
          },
        );
      },
    );
  }
}
