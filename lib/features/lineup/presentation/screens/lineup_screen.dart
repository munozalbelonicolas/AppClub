import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/convocatoria_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';

class LineupScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final String? initialMatchId;

  const LineupScreen({
    super.key,
    this.initialCategory,
    this.initialMatchId,
  });

  @override
  ConsumerState<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends ConsumerState<LineupScreen> {
  // Local state for starter assignments: positionKey -> playerId
  final Map<String, String> _positions = {};
  // Set of playerIds marked as convocado for this match
  final Set<String> _convocadosIds = {};

  String? _selectedCategory;
  String? _selectedMatchId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedMatchId = widget.initialMatchId;
  }

  Future<void> _saveLineup(Map<String, dynamic>? nextMatch) async {
    setState(() {
      _isSaving = true;
    });

    final docId = nextMatch?['id'] ?? 'next_match_${_selectedCategory ?? 'all'}';
    final currentUser = ref.read(currentUserProvider);

    try {
      final matchRef = FirebaseFirestore.instance.collection('match_lineups').doc(docId);
      await matchRef.set({
        'matchId': docId,
        'category': _selectedCategory,
        'updatedAt': FieldValue.serverTimestamp(),
        'positions': _positions,
        'convocadosIds': _convocadosIds.toList(),
      }, SetOptions(merge: true));

      final effectiveMatchId = nextMatch?['id'] ?? docId;
      final convocatoriaRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(effectiveMatchId)
          .collection('convocatoria');

      // Read existing convocatoria to detect NEWLY added players
      final existingSnap = await convocatoriaRef.get();
      final previouslyConvocadoIds = existingSnap.docs.map((d) => d.id).toSet();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in existingSnap.docs) {
        batch.delete(doc.reference);
      }

      // Delete tutor_convocatorias for unconvoked players
      try {
        final existingTutorConvs = await FirebaseFirestore.instance
            .collection('tutor_convocatorias')
            .where('matchId', isEqualTo: effectiveMatchId)
            .get();

        for (final doc in existingTutorConvs.docs) {
          final pid = doc.data()['playerId'] as String?;
          if (pid != null && !_convocadosIds.contains(pid)) {
            batch.delete(doc.reference);
          }
        }
      } catch (_) {}

      final playersAsync = ref.read(playersStreamProvider);
      final categoryPlayers = (playersAsync.valueOrNull ?? [])
          .where((p) => p['category'] == _selectedCategory)
          .toList();

      final List<Future<void>> notificationFutures = [];

      final matchDate = nextMatch?['date'];
      String dateStr = '';
      if (matchDate is Timestamp) {
        final d = matchDate.toDate();
        dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      } else if (matchDate != null) {
        dateStr = matchDate.toString();
      }
      final rival = nextMatch?['awayTeam'] ?? nextMatch?['homeTeam'] ?? 'Próximo Partido';
      final venue = nextMatch?['venue'] ?? nextMatch?['location'] ?? 'Cancha Principal JN';
      final timeStr = nextMatch?['time']?.toString() ?? '';

      for (var p in categoryPlayers) {
        if (_convocadosIds.contains(p['id'])) {
          final isStarter = _positions.values.contains(p['id']);
          final playerId = p['id'] as String;

          // Look up ALL tutors for this player
          final List<String> tutorIds = [];
          try {
            final tutorLinksSnap = await FirebaseFirestore.instance
                .collection('player_tutor_links')
                .where('playerId', isEqualTo: playerId)
                .get();
            for (final tdoc in tutorLinksSnap.docs) {
              final tid = tdoc.data()['tutorId'] as String?;
              if (tid != null && tid.isNotEmpty && !tutorIds.contains(tid)) {
                tutorIds.add(tid);
              }
            }
          } catch (_) {}

          // Fallbacks from player doc
          if (tutorIds.isEmpty) {
            if (p['tutorId'] != null) tutorIds.add(p['tutorId'] as String);
            if (p['parentId'] != null) tutorIds.add(p['parentId'] as String);
            if (p['fatherId'] != null) tutorIds.add(p['fatherId'] as String);
          }

          final cDoc = convocatoriaRef.doc(playerId);
          batch.set(cDoc, {
            'playerId': playerId,
            'name': '${p['name']} ${p['lastName']}',
            'number': p['number'] ?? p['jerseyNumber'] ?? '',
            'position': p['position'] ?? 'Jugador',
            'category': p['category'],
            'role': p['role'] ?? 'jugador',
            'isStarter': isStarter,
            'status': 'pending',
            'tutorId': tutorIds.isNotEmpty ? tutorIds.first : null,
            'tutorIds': tutorIds,
            'matchId': effectiveMatchId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Write to tutor_convocatorias collection for real-time tutor dashboard
          for (final tId in tutorIds) {
            final tDoc = FirebaseFirestore.instance
                .collection('tutor_convocatorias')
                .doc('${effectiveMatchId}_${tId}_$playerId');

            batch.set(tDoc, {
              'tutorId': tId,
              'playerId': playerId,
              'playerName': '${p['name']} ${p['lastName']}',
              'number': p['number'] ?? p['jerseyNumber'] ?? '',
              'position': p['position'] ?? 'Jugador',
              'category': p['category'] ?? _selectedCategory ?? '',
              'matchId': effectiveMatchId,
              'homeTeam': nextMatch?['homeTeam'] ?? 'Jorge Newbery',
              'awayTeam': rival,
              'venue': venue,
              'date': dateStr,
              'time': timeStr,
              'status': 'pending',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // Send push notification ONLY to newly added players' tutors
          final isNew = !previouslyConvocadoIds.contains(playerId);
          if (isNew && tutorIds.isNotEmpty) {
            final playerName = '${p['name']} ${p['lastName']}';
            for (final tId in tutorIds) {
              notificationFutures.add(
                NotificationService().sendNotification(
                  title: '⚽ ¡Convocatoria!',
                  body: '$playerName fue convocado/a para el partido vs $rival${dateStr.isNotEmpty ? " ($dateStr)" : ""}. Confirmá su asistencia en la app.',
                  authorId: currentUser?.id ?? '',
                  targetUserId: tId,
                ),
              );
            }
          }
        }
      }

      await batch.commit();
      await Future.wait(notificationFutures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Convocatoria guardada correctamente.'),
            backgroundColor: context.colors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
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

  void _toggleConvocado(String playerId, Map<String, dynamic>? nextMatch) {
    setState(() {
      if (_convocadosIds.contains(playerId)) {
        _convocadosIds.remove(playerId);
        _positions.removeWhere((k, v) => v == playerId);
      } else {
        _convocadosIds.add(playerId);
      }
    });
    _saveLineup(nextMatch);
  }

  void _toggleTitular(String playerId, Map<String, dynamic>? nextMatch) {
    setState(() {
      final isAlreadyStarter = _positions.values.contains(playerId);
      if (isAlreadyStarter) {
        _positions.removeWhere((k, v) => v == playerId);
      } else {
        if (!_convocadosIds.contains(playerId)) {
          _convocadosIds.add(playerId);
        }
        final starterKey = 'STARTER_$playerId';
        _positions[starterKey] = playerId;
      }
    });
    _saveLineup(nextMatch);
  }

  void _showConvocatoriaManager(
    BuildContext context,
    List<Map<String, dynamic>> allCategoryPlayers,
    Map<String, dynamic>? nextMatch,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int countConvocados = allCategoryPlayers.where((p) => _convocadosIds.contains(p['playerId'])).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gestionar Convocados', style: context.typography.headlineSmall),
                          Text('$countConvocados de ${allCategoryPlayers.length} jugadores convocados', style: context.typography.bodySmall),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _convocadosIds.clear();
                              _convocadosIds.addAll(allCategoryPlayers.map((p) => p['playerId'] as String));
                            });
                            setModalState(() {});
                            _saveLineup(nextMatch);
                          },
                          icon: const Icon(Icons.select_all, size: 16),
                          label: const Text('Convocar Todos', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _convocadosIds.clear();
                              _positions.clear();
                            });
                            setModalState(() {});
                            _saveLineup(nextMatch);
                          },
                          icon: const Icon(Icons.deselect, size: 16),
                          label: const Text('Desconvocar Todos', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: allCategoryPlayers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final player = allCategoryPlayers[idx];
                        final playerId = player['playerId'] as String;
                        final isConvocado = _convocadosIds.contains(playerId);

                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: JNAvatar(name: player['name'] as String, size: 36),
                          title: Text(player['name'] as String, style: context.typography.titleMedium),
                          subtitle: Text('#${player['number']} · ${player['position']}', style: context.typography.bodySmall),
                          value: isConvocado,
                          activeThumbColor: context.colors.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val) {
                                _convocadosIds.add(playerId);
                              } else {
                                _convocadosIds.remove(playerId);
                                _positions.removeWhere((k, v) => v == playerId);
                              }
                            });
                            setModalState(() {});
                            _saveLineup(nextMatch);
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final isCoach = currentUser.role == 'dt';
    final isAdmin = currentUser.isAdmin;

    final appCategories = ref.watch(appCategoriesProvider);

    final categories = isCoach
        ? (currentUser.assignedCategories ?? (currentUser.category != null ? [currentUser.category!] : <String>[]))
        : (isAdmin ? appCategories : (currentUser.category != null ? [currentUser.category!] : <String>[]));

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    } else if (_selectedCategory != null && !categories.contains(_selectedCategory) && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    final allMatches = ref.watch(allUpcomingMatchesProvider(_selectedCategory ?? ''));

    // Deduplicate matches to prevent any Dropdown duplicate value assertion error
    final uniqueMatches = <String, Map<String, dynamic>>{};
    for (final m in allMatches) {
      final id = m['id']?.toString();
      if (id != null && id.isNotEmpty && !uniqueMatches.containsKey(id)) {
        uniqueMatches[id] = m;
      }
    }
    final matchItems = uniqueMatches.values.toList();

    final nextMatch = matchItems.where((m) => m['id'] == _selectedMatchId).firstOrNull ??
        (matchItems.isNotEmpty ? matchItems.first : null);

    if (_selectedMatchId == null && nextMatch != null) {
      _selectedMatchId = nextMatch['id'] as String?;
    } else if (_selectedMatchId != null && !matchItems.any((m) => m['id'] == _selectedMatchId)) {
      _selectedMatchId = matchItems.isNotEmpty ? matchItems.first['id'] as String? : null;
    }

    final playersAsync = ref.watch(playersStreamProvider);
    final allCategoryPlayers = (playersAsync.valueOrNull ?? [])
        .where((p) => p['category'] == _selectedCategory)
        .where((p) => p['role'] == null || p['role'] == 'jugador')
        .where((p) => p['role'] != 'directivo' && p['role'] != 'secretario' && p['role'] != 'dt' && p['role'] != 'tutor' && p['role'] != 'socio')
        .map((p) => <String, dynamic>{
          'playerId': p['id'],
          'name': '${p['name']} ${p['lastName']}',
          'number': p['number'] ?? p['jerseyNumber'] ?? '',
          'position': p['position'] ?? 'Jugador',
          'role': p['role'] ?? 'jugador',
        })
        .toList();

    final docId = nextMatch?['id'] ?? 'next_match_${_selectedCategory ?? 'all'}';

    final convocatoriaAsync = ref.watch(convocatoriaStreamProvider(docId));
    final tutorConvsStatusAsync = ref.watch(coachConvocatoriaStatusProvider(docId));

    final Map<String, String> convocatoriaStatusMap = {};
    if (convocatoriaAsync.valueOrNull != null) {
      for (final doc in convocatoriaAsync.valueOrNull!) {
        final pid = (doc['playerId'] ?? doc['id']) as String?;
        final st = doc['status'] as String? ?? 'pending';
        if (pid != null) {
          convocatoriaStatusMap[pid] = st;
        }
      }
    }
    if (tutorConvsStatusAsync.valueOrNull != null) {
      tutorConvsStatusAsync.valueOrNull!.forEach((pid, st) {
        if (st != 'pending' || !convocatoriaStatusMap.containsKey(pid)) {
          convocatoriaStatusMap[pid] = st;
        }
      });
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Formación del Equipo'), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('match_lineups')
            .doc(docId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null && !_isSaving) {
              if (data['convocadosIds'] != null) {
                final List<dynamic> rawIds = data['convocadosIds'];
                _convocadosIds.clear();
                _convocadosIds.addAll(rawIds.map((e) => e.toString()));
              } else {
                _convocadosIds.clear();
              }
              if (data['positions'] != null) {
                final rawPositions = data['positions'] as Map<String, dynamic>;
                _positions.clear();
                rawPositions.forEach((k, v) {
                  _positions[k] = v.toString();
                });
              } else {
                _positions.clear();
              }
            }
          } else if (snapshot.hasData && !snapshot.data!.exists && !_isSaving) {
            _convocadosIds.clear();
            _positions.clear();
          }

          // Convocados vs No Convocados
          final List<Map<String, dynamic>> convocados = allCategoryPlayers
              .where((p) => _convocadosIds.contains(p['playerId']))
              .toList();

          final List<Map<String, dynamic>> noConvocados = allCategoryPlayers
              .where((p) => !_convocadosIds.contains(p['playerId']))
              .toList();

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
                          _selectedMatchId = null;
                          _positions.clear();
                          _convocadosIds.clear();
                        });
                      }
                    },
                  ),
                ),

              // Match / Event Selector Dropdown
              if (matchItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: matchItems.any((m) => m['id'] == _selectedMatchId)
                        ? _selectedMatchId
                        : matchItems.first['id'] as String?,
                    decoration: InputDecoration(
                      labelText: 'Partido / Evento para Convocatoria',
                      prefixIcon: const Icon(Icons.emoji_events_outlined, color: Colors.blueAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    isExpanded: true,
                    items: matchItems.map((m) {
                      final isFriendly = m['source'] == 'novedad';
                      final typeLabel = isFriendly ? 'Amistoso' : 'Oficial';
                      final dateLabel = (m['date']?.toString().isNotEmpty == true) ? m['date'] : 'A confirmar';
                      final titleText = '${m['homeTeam']} vs ${m['awayTeam']} · $dateLabel ($typeLabel)';
                      return DropdownMenuItem<String>(
                        value: m['id'] as String,
                        child: Text(
                          titleText,
                          style: context.typography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedMatchId) {
                        setState(() {
                          _selectedMatchId = val;
                          _positions.clear();
                          _convocadosIds.clear();
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
                              '${nextMatch['homeTeam']} vs ${nextMatch['awayTeam']}',
                              style: context.typography.titleMedium,
                            ),
                            Text(
                              'Fecha 6 · Cancha: ${nextMatch['venue']}',
                              style: context.typography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (isCoach)
                        TextButton.icon(
                          onPressed: () => _showConvocatoriaManager(context, allCategoryPlayers, nextMatch),
                          icon: const Icon(Icons.playlist_add_check, size: 18),
                          label: const Text('Convocatoria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      else
                        const JNBadge(
                          label: 'CONVOCATORIA',
                          type: JNBadgeType.accent,
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms)
              else
                JNCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_soccer, size: 20, color: context.colors.textTertiary),
                          const SizedBox(width: 10),
                          Text('Sin próximo partido agendado', style: context.typography.bodyMedium),
                        ],
                      ),
                      if (isCoach)
                        TextButton.icon(
                          onPressed: () => _showConvocatoriaManager(context, allCategoryPlayers, nextMatch),
                          icon: const Icon(Icons.playlist_add_check, size: 16),
                          label: const Text('Convocar', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plantel Convocado (${convocados.length}/${allCategoryPlayers.length})',
                        style: context.typography.headlineSmall,
                      ),
                      Text(
                        convocados.isEmpty
                            ? 'No hay jugadores convocados aún.'
                            : '${convocados.length} jugadores convocados para el partido.',
                        style: context.typography.bodySmall,
                      ),
                    ],
                  ),
                  if (isCoach)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showConvocatoriaManager(context, allCategoryPlayers, nextMatch),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Gestionar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ─── GREEN PITCH DISPLAYING ONLY CONVOCADOS (NO-CONVOCADOS NEVER APPEAR HERE) ───
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 200),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF153d2f),
                        Color(0xFF235c47),
                        Color(0xFF1c4a39),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Soccer pitch lines painter
                      Positioned.fill(
                        child: CustomPaint(painter: _SoccerPitchPainter()),
                      ),

                      // Player Names OVER the Pitch (ONLY CONVOCADOS)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Convocatoria Categoría ${_selectedCategory ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.colors.accent.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.colors.accent),
                                  ),
                                  child: Text(
                                    '${convocados.length} CONVOCADOS',
                                    style: TextStyle(
                                      color: context.colors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (convocados.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.person_add_disabled, color: Colors.white54, size: 28),
                                      SizedBox(height: 8),
                                      Text(
                                        'No hay jugadores convocados aún.',
                                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Toca "+ Convocar" en la lista de abajo para sumar jugadores.',
                                        style: TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: convocados.map((player) {
                                  final playerId = player['playerId'] as String;
                                  final isStarter = _positions.values.contains(playerId);
                                  final number = player['number']?.toString() ?? '';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isStarter
                                          ? context.colors.accent
                                          : Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isStarter ? Colors.white : Colors.white38,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 3,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isStarter) ...[
                                          const Icon(Icons.star, size: 14, color: Colors.black),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          player['name'] as String,
                                          style: TextStyle(
                                            color: isStarter ? Colors.black : Colors.white,
                                            fontWeight: isStarter ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (number.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '#$number',
                                            style: TextStyle(
                                              color: isStarter ? Colors.black87 : Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 100.ms).fadeIn().scale(begin: const Offset(0.98, 0.98)),

              const SizedBox(height: 24),

              // ─── ROSTER SELECTION LIST (CONVOCADOS / NO CONVOCADOS) ───
              Text('Plantel de la Categoría (${allCategoryPlayers.length})', style: context.typography.headlineSmall),
              Text('Toca "+ Convocar" para convocar jugadores al partido:', style: context.typography.bodySmall),
              const SizedBox(height: 12),

              if (convocados.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jugadores Convocados (${convocados.length})',
                      style: context.typography.titleMedium.copyWith(color: context.colors.primary),
                    ),
                    const JNBadge(label: 'CONVOCADO', type: JNBadgeType.success),
                  ],
                ),
                const SizedBox(height: 8),
                ...convocados.map((p) => _buildPlayerCard(
                  player: p,
                  isConvocado: true,
                  isStarter: _positions.values.contains(p['playerId']),
                  isCoach: isCoach,
                  nextMatch: nextMatch,
                  convocatoriaStatus: convocatoriaStatusMap[p['playerId']],
                )),
                const SizedBox(height: 16),
              ],

              if (noConvocados.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sin Convocar (${noConvocados.length})',
                      style: context.typography.titleMedium.copyWith(color: context.colors.textSecondary),
                    ),
                    const JNBadge(label: 'NO CONVOCADO'),
                  ],
                ),
                const SizedBox(height: 8),
                ...noConvocados.map((p) => _buildPlayerCard(
                  player: p,
                  isConvocado: false,
                  isStarter: false,
                  isCoach: isCoach,
                  nextMatch: nextMatch,
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerCard({
    required Map<String, dynamic> player,
    required bool isConvocado,
    required bool isStarter,
    required bool isCoach,
    required Map<String, dynamic>? nextMatch,
    String? convocatoriaStatus,
  }) {
    final playerId = player['playerId'] as String;

    // Status chip widget shown next to convocado players
    Widget? statusChip;
    if (isCoach && isConvocado) {
      switch (convocatoriaStatus) {
        case 'confirmed':
          statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade400),
            ),
            child: const Text('✅ Confirmó', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
          );
          break;
        case 'rejected':
          statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade400),
            ),
            child: const Text('❌ No puede', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
          );
          break;
        default:
          statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade400),
            ),
            child: const Text('🟡 Pendiente', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
          );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: JNCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            JNAvatar(
              name: player['name'] as String,
              size: 40,
              borderColor: isStarter
                  ? context.colors.accent
                  : (isConvocado ? context.colors.primary : context.colors.textTertiary),
              borderWidth: 1.5,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isStarter ? '⭐ ' : ''}${player['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleMedium.copyWith(
                      color: isStarter ? context.colors.accent : context.colors.textPrimary,
                      fontWeight: isStarter ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${player['number']} · ${player['position']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySmall,
                  ),
                  if (statusChip != null) ...[
                    const SizedBox(height: 4),
                    statusChip,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isCoach) ...[
              // Button to Convocar / Desconvocar
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConvocado
                      ? context.colors.primary.withValues(alpha: 0.15)
                      : context.colors.surface,
                  foregroundColor: isConvocado
                      ? context.colors.primary
                      : context.colors.textSecondary,
                  elevation: 0,
                  side: BorderSide(
                    color: isConvocado ? context.colors.primary : context.colors.divider,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _toggleConvocado(playerId, nextMatch),
                icon: Icon(
                  isConvocado ? Icons.check_circle : Icons.add_circle_outline,
                  size: 14,
                  color: isConvocado ? context.colors.primary : context.colors.textSecondary,
                ),
                label: Text(
                  isConvocado ? 'Convocado' : '+ Convocar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isConvocado ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),

              // Optional Starter Toggle Button (only when convocado)
              if (isConvocado) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: isStarter ? 'Quitar Titular' : 'Marcar Titular ⭐',
                  icon: Icon(
                    Icons.star,
                    color: isStarter ? context.colors.accent : context.colors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () => _toggleTitular(playerId, nextMatch),
                ),
              ],
            ],
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

    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(rect, paint);

    final midY = size.height / 2;
    canvas.drawLine(Offset(8, midY), Offset(size.width - 8, midY), paint);

    canvas.drawCircle(Offset(size.width / 2, midY), 45, paint);
    canvas.drawCircle(
      Offset(size.width / 2, midY),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    final topPenalty = Rect.fromLTWH(
      size.width * 0.18,
      8,
      size.width * 0.64,
      size.height * 0.18,
    );
    canvas.drawRect(topPenalty, paint);
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

    final bottomPenalty = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.82 - 8,
      size.width * 0.64,
      size.height * 0.18,
    );
    canvas.drawRect(bottomPenalty, paint);
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