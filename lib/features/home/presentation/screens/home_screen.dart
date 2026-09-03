import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/user_session.dart';
import '../../../../core/providers/convocatoria_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/birthday_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_match_card.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../attendance/presentation/screens/player_attendance_screen.dart';
import '../../../communications/presentation/screens/story_export_screen.dart';
import '../../../inbox/presentation/screens/inbox_screen.dart';
import '../../../lineup/presentation/screens/lineup_screen.dart';
import '../../../payments/presentation/screens/payments_screen.dart';
import '../../../results/presentation/screens/results_screen.dart';
import '../../../settings/presentation/widgets/admin_notifications_dialog.dart';
import '../widgets/club_social_banner.dart';
import '../widgets/sponsor_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _expandedPostIds = {};
  final Set<String> _markedSeenPostIds = {};
  final Map<String, TextEditingController> _commentControllers = {};

  void _confirmAttendance(
    String matchId,
    String playerId,
    String playerName,
  ) async {
    try {
      await updateConvocatoriaStatus(
        matchId: matchId,
        playerId: playerId,
        status: 'confirmed',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ¡Asistencia de $playerName confirmada!'),
            backgroundColor: context.colors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar asistencia: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  void _rejectAttendance(String matchId, String playerId, String playerName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: context.colors.border, width: 0.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('No puede asistir', style: context.typography.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmas que $playerName no podrá asistir al partido?',
              style: context.typography.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: context.typography.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej: Viaje familiar / Lesión / Compromiso',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await updateConvocatoriaStatus(
                  matchId: matchId,
                  playerId: playerId,
                  status: 'rejected',
                  rejectionReason: reasonController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Aviso enviado al DT: $playerName no asistirá.',
                      ),
                      backgroundColor: context.colors.error,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al responder: $e'),
                      backgroundColor: context.colors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirmar Ausencia'),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorConvocatoriaCard(Map<String, dynamic> item) {
    final match = item['match'] as Map<String, dynamic>? ?? {};
    final conv = item['convocatoria'] as Map<String, dynamic>? ?? {};
    final matchId =
        item['matchId'] as String? ??
        match['id'] as String? ??
        item['id'] as String? ??
        '';
    final playerId =
        item['playerId'] as String? ??
        conv['playerId'] as String? ??
        conv['id'] as String? ??
        '';
    final playerName =
        item['playerName'] ?? conv['name'] ?? item['name'] ?? 'Jugador';
    final category =
        item['category'] as String? ?? conv['category'] as String? ?? '';

    // Match candidate lookup for this category as fallback for rival/date/venue
    final nextMatch = category.isNotEmpty ? ref.watch(nextMatchProvider(category)) : null;

    // 1. Resolve Rival Name
    String resolvedRival = '';
    final itemRival = item['awayTeam'] ?? item['displayRival'] ?? item['rival'] ?? item['opponentName'] ?? match['awayTeam'];
    if (itemRival != null &&
        itemRival.toString().trim().isNotEmpty &&
        itemRival.toString().toLowerCase() != 'rival' &&
        itemRival.toString().toLowerCase() != 'partido') {
      resolvedRival = itemRival.toString().trim();
    } else if (item['homeTeam'] != null &&
        !item['homeTeam'].toString().toLowerCase().contains('newbery') &&
        item['homeTeam'].toString().toLowerCase() != 'partido') {
      resolvedRival = item['homeTeam'].toString().trim();
    } else if (nextMatch != null) {
      final nmAway = nextMatch['awayTeam']?.toString() ?? '';
      final nmHome = nextMatch['homeTeam']?.toString() ?? '';
      if (nmAway.isNotEmpty && !nmAway.toLowerCase().contains('newbery') && nmAway.toLowerCase() != 'rival') {
        resolvedRival = nmAway;
      } else if (nmHome.isNotEmpty && !nmHome.toLowerCase().contains('newbery') && nmHome.toLowerCase() != 'rival') {
        resolvedRival = nmHome;
      }
    }
    if (resolvedRival.isEmpty || resolvedRival.toLowerCase() == 'rival') {
      resolvedRival = 'Rival a confirmar';
    }

    // 2. Resolve Local vs Visitante Condition & Venue
    final bool isHomeGame = item['isHome'] == true ||
        (item['homeTeam'] != null && item['homeTeam'].toString().toLowerCase().contains('newbery')) ||
        (nextMatch != null && nextMatch['homeTeam']?.toString().toLowerCase().contains('newbery') == true);

    final String conditionLabel = isHomeGame ? 'Cancha Local' : 'Cancha Visitante';
    String resolvedVenue = item['venue']?.toString() ?? match['venue']?.toString() ?? nextMatch?['venue']?.toString() ?? '';
    if (resolvedVenue.isEmpty || resolvedVenue.toLowerCase() == 'cancha principal' || resolvedVenue.toLowerCase() == 'cancha principal jn') {
      resolvedVenue = isHomeGame ? 'Cancha Local (Jorge Newbery)' : 'Cancha Visitante';
    } else {
      if (!resolvedVenue.toLowerCase().contains('local') && !resolvedVenue.toLowerCase().contains('visitante')) {
        resolvedVenue = '$conditionLabel · $resolvedVenue';
      }
    }

    // 3. Resolve Date & Time
    String dateStr = '';
    final rawDate = item['date'] ??
        item['matchDate'] ??
        item['eventDate'] ??
        item['dateYMD'] ??
        match['date'] ??
        match['matchDate'] ??
        match['eventDate'] ??
        match['dateYMD'] ??
        nextMatch?['date'] ??
        nextMatch?['matchDate'] ??
        nextMatch?['eventDate'];

    if (rawDate is Timestamp) {
      final d = rawDate.toDate();
      dateStr =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } else if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      final s = rawDate.toString().trim();
      if (s.contains('T')) {
        final datePart = s.split('T')[0];
        final parts = datePart.split('-');
        if (parts.length == 3) {
          dateStr = '${parts[2]}/${parts[1]}/${parts[0]}';
        } else {
          dateStr = datePart;
        }
      } else if (s.contains('-')) {
        final parts = s.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            dateStr = '${parts[2]}/${parts[1]}/${parts[0]}';
          } else {
            dateStr = '${parts[0]}/${parts[1]}/${parts[2]}';
          }
        } else {
          dateStr = s;
        }
      } else {
        dateStr = s;
      }
    }

    final rawTime = item['time'] ??
        item['eventTime'] ??
        item['matchTime'] ??
        match['time'] ??
        match['eventTime'] ??
        match['matchTime'] ??
        nextMatch?['time'] ??
        nextMatch?['eventTime'];

    final cleanTime = rawTime?.toString().trim() ?? '';
    final timeStr = (cleanTime.isNotEmpty &&
            cleanTime.toLowerCase() != 'null' &&
            cleanTime.toLowerCase() != 'a confirmar')
        ? cleanTime
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163D2D), Color(0xFF0D241A)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF34D399)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        size: 14,
                        color: Color(0xFF34D399),
                      ),
                      SizedBox(width: 5),
                      Text(
                        '¡CONVOCATORIA AL PARTIDO!',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (category.isNotEmpty)
                  Text(
                    'Cat. $category',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$playerName fue convocado/a',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Color(0xFF34D399),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'vs $resolvedRival',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Colors.white60,
                ),
                const SizedBox(width: 6),
                Text(
                  dateStr.isNotEmpty
                      ? '$dateStr${timeStr.isNotEmpty ? " · $timeStr hs" : ""}'
                      : (timeStr.isNotEmpty ? '$timeStr hs' : 'Fecha a confirmar'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(
                  isHomeGame ? Icons.home_outlined : Icons.directions_bus_outlined,
                  size: 14,
                  color: Colors.white60,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    resolvedVenue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () =>
                        _confirmAttendance(matchId, playerId, playerName),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Confirmar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                      side: const BorderSide(color: Color(0xFFF87171)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () =>
                        _rejectAttendance(matchId, playerId, playerName),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text(
                      'No puede ir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final sessionUser = ref.read(currentUserProvider);
        if (sessionUser != null &&
            (sessionUser.role == 'directivo' ||
                sessionUser.role == 'secretario')) {
          ref.read(birthdayServiceProvider).checkAndTriggerBirthdays();
        }
      }
    });
  }

  Stream<int> _unreadMessagesCountStream(dynamic sessionUser) {
    final db = FirebaseFirestore.instance;
    if (sessionUser.isNormalUser) {
      return db
          .collection('inbox_threads')
          .where('participants', arrayContains: sessionUser.id)
          .snapshots()
          .map(
            (snap) => snap.docs.where((doc) {
              final data = doc.data();
              if (data.containsKey('unreadBy')) {
                return (data['unreadBy'] as List?)?.contains(sessionUser.id) ??
                    false;
              }
              return (data['unreadByUser'] ?? false) == true;
            }).length,
          );
    } else {
      return db.collection('inbox_threads').snapshots().map((snap) {
        var docs = snap.docs;
        if (sessionUser.role == 'dt') {
          final assignedCats =
              sessionUser.assignedCategories
                  ?.map((c) => c.toLowerCase())
                  .toList() ??
              [];
          if (assignedCats.isEmpty && sessionUser.category != null) {
            assignedCats.add(sessionUser.category!.toLowerCase());
          }
          docs = docs.where((doc) {
            final data = doc.data();
            final categoriesMap =
                data['userCategories'] as Map<String, dynamic>? ?? {};
            String otherUserId = '';
            for (final pId in data['participants'] ?? []) {
              if (pId != sessionUser.id) {
                otherUserId = pId;
                break;
              }
            }
            final otherCategory = (categoriesMap[otherUserId] ?? '')
                .toString()
                .toLowerCase();
            final isParticipant =
                (data['participants'] as List?)?.contains(sessionUser.id) ??
                false;
            return assignedCats.contains(otherCategory) || isParticipant;
          }).toList();
        }
        return docs.where((doc) {
          final data = doc.data();
          bool isUnread =
              (data['unreadBy'] as List?)?.contains(sessionUser.id) ?? false;
          if (!isUnread) {
            isUnread = (data['unreadByAdmin'] == true);
          }
          return isUnread;
        }).length;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleComments(String postId) {
    setState(() {
      if (_expandedPostIds.contains(postId)) {
        _expandedPostIds.remove(postId);
      } else {
        _expandedPostIds.add(postId);
        _commentControllers.putIfAbsent(postId, () => TextEditingController());
      }
    });
  }

  void _showCreatePostDialog(
    BuildContext context,
    dynamic sessionUser,
    List<Map<String, dynamic>> clubs,
  ) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedImagePath;
    DateTime? eventDate;
    TimeOfDay? eventTime;
    final venueController = TextEditingController(text: 'Cancha Principal JN');

    // Default category configuration
    String selectedCategory = 'all';
    final bool isDT = sessionUser.role == 'dt';
    if (isDT) {
      if (sessionUser.assignedCategories != null &&
          sessionUser.assignedCategories!.isNotEmpty) {
        selectedCategory = sessionUser.assignedCategories!.first;
      } else if (sessionUser.category != null) {
        selectedCategory = sessionUser.category!;
      }
    }

    String eventType = isDT ? 'partido' : 'ninguno';
    bool hasTransport = false;
    bool isHome = true;
    String? selectedOpponentId;
    bool isPublishing = false;

    final appCategories = ref.read(appCategoriesProvider);
    final List<String> categories = ['all', ...appCategories];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: context.colors.border, width: 0.5),
              ),
              title: Text(
                'Nueva Publicación',
                style: context.typography.titleLarge,
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleController,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Título de la novedad',
                          labelText: 'Título',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa un título'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bodyController,
                        maxLines: 3,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Escribe aquí la novedad...',
                          labelText: 'Contenido',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa el contenido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Foto de la publicación (opcional)',
                        style: context.typography.labelSmall.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (file != null) {
                            setDialogState(() {
                              selectedImagePath = file.path;
                            });
                          }
                        },
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceLight,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            border: Border.all(
                              color: selectedImagePath == null
                                  ? context.colors.border
                                  : context.colors.primary,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildImagePreview(
                            selectedImagePath,
                            context,
                            onRemove: selectedImagePath != null
                                ? () {
                                    setDialogState(() {
                                      selectedImagePath = null;
                                    });
                                  }
                                : null,
                          ),
                        ),
                      ),
                      // Category selection
                      if (isDT) ...[
                        if ((sessionUser.assignedCategories?.length ?? 0) > 1) ...[
                          DropdownButtonFormField<String>(
                            dropdownColor: context.colors.surface,
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                            ),
                            items: List<String>.from(sessionUser.assignedCategories!).map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat,
                                child: Text('Categoría $cat', style: context.typography.bodyLarge),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedCategory = val);
                              }
                            },
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              'Categoría: ${sessionUser.displayCategory}',
                              style: context.typography.bodyMedium.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        DropdownButtonFormField<String>(
                          dropdownColor: context.colors.surface,
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría de destino',
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(
                                cat == 'all' ? 'Global (Todos)' : 'Categoría $cat',
                                style: context.typography.bodyLarge,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedCategory = val;
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        dropdownColor: context.colors.surface,
                        initialValue: eventType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Publicación / Evento',
                        ),
                        items: isDT
                            ? const [
                                DropdownMenuItem(
                                  value: 'partido',
                                  child: Text('⚽ Partido Amistoso'),
                                ),
                                DropdownMenuItem(
                                  value: 'comunicado',
                                  child: Text('📢 Comunicado / Novedad'),
                                ),
                                DropdownMenuItem(
                                  value: 'entrenamiento',
                                  child: Text('🏃 Entrenamiento Especial'),
                                ),
                              ]
                            : const [
                                DropdownMenuItem(
                                  value: 'ninguno',
                                  child: Text('Publicación normal'),
                                ),
                                DropdownMenuItem(
                                  value: 'comunicado',
                                  child: Text('📢 Comunicado Oficial'),
                                ),
                                DropdownMenuItem(
                                  value: 'partido',
                                  child: Text('⚽ Partido Amistoso / Oficial'),
                                ),
                                DropdownMenuItem(
                                  value: 'evento',
                                  child: Text('🎉 Evento Especial'),
                                ),
                                DropdownMenuItem(
                                  value: 'jornada',
                                  child: Text('🏆 Jornada'),
                                ),
                                DropdownMenuItem(
                                  value: 'cuadrangular',
                                  child: Text('Cuadrangular'),
                                ),
                                DropdownMenuItem(
                                  value: 'torneo',
                                  child: Text('🥇 Torneo'),
                                ),
                              ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              eventType = val;
                              if (eventType == 'ninguno' ||
                                  eventType == 'comunicado') {
                                hasTransport = false;
                                selectedOpponentId = null;
                              }
                            });
                          }
                        },
                      ),
                      if (eventType != 'ninguno' &&
                          eventType != 'comunicado') ...[
                        if (eventType == 'partido') ...[
                          const SizedBox(height: 12),
                          // Condición: Local / Visitante
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      isHome = true;
                                      if (venueController.text.isEmpty || venueController.text == 'Cancha Visitante' || venueController.text.startsWith('Cancha de ')) {
                                        venueController.text = 'Cancha Principal JN';
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isHome ? context.colors.primary.withValues(alpha: 0.15) : context.colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isHome ? context.colors.primary : context.colors.border,
                                        width: isHome ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.home_outlined, size: 18, color: isHome ? context.colors.primary : context.colors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Local (JN)',
                                          style: TextStyle(
                                            fontWeight: isHome ? FontWeight.bold : FontWeight.normal,
                                            color: isHome ? context.colors.primary : context.colors.textSecondary,
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
                                  onTap: () {
                                    setDialogState(() {
                                      isHome = false;
                                      hasTransport = true;
                                      final oppClub = clubs.where((c) => c['id'] == selectedOpponentId).firstOrNull;
                                      if (oppClub != null) {
                                        venueController.text = 'Cancha de ${oppClub['name']}';
                                      } else {
                                        venueController.text = 'Cancha Visitante';
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !isHome ? context.colors.primary.withValues(alpha: 0.15) : context.colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: !isHome ? context.colors.primary : context.colors.border,
                                        width: !isHome ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.directions_bus_outlined, size: 18, color: !isHome ? context.colors.primary : context.colors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Visitante',
                                          style: TextStyle(
                                            fontWeight: !isHome ? FontWeight.bold : FontWeight.normal,
                                            color: !isHome ? context.colors.primary : context.colors.textSecondary,
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
                        const SizedBox(height: 12),
                        // Fecha del Partido / Evento
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: eventDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                eventDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha del Partido / Evento *',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              eventDate != null
                                  ? '${eventDate!.day.toString().padLeft(2, '0')}/${eventDate!.month.toString().padLeft(2, '0')}/${eventDate!.year}'
                                  : 'Seleccionar Fecha',
                              style: context.typography.bodyLarge.copyWith(
                                color: eventDate != null
                                    ? null
                                    : context.colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Hora del Partido / Evento
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: eventTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                eventTime = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora del Partido / Evento',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              eventTime != null
                                  ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')} hs'
                                  : 'Seleccionar Hora',
                              style: context.typography.bodyLarge.copyWith(
                                color: eventTime != null
                                    ? null
                                    : context.colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Lugar / Cancha
                        TextFormField(
                          controller: venueController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(
                            labelText: 'Lugar / Cancha',
                            hintText: 'Cancha Principal JN',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.directions_bus, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Traslado Incluido'),
                            ],
                          ),
                          value: hasTransport,
                          activeThumbColor: Colors.orange,
                          activeTrackColor: Colors.orange.withValues(
                            alpha: 0.3,
                          ),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setDialogState(() {
                              hasTransport = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          dropdownColor: context.colors.surface,
                          initialValue: selectedOpponentId,
                          decoration: const InputDecoration(
                            labelText: 'Club Rival (Opcional)',
                          ),
                          items: clubs.where((c) => c['isLocal'] != true).map((
                            club,
                          ) {
                            return DropdownMenuItem<String>(
                              value: club['id'],
                              child: Text(
                                club['name'],
                                style: context.typography.bodyLarge,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedOpponentId = val;
                              if (!isHome && val != null) {
                                final oppClub = clubs.where((c) => c['id'] == val).firstOrNull;
                                if (oppClub != null && (venueController.text.isEmpty || venueController.text == 'Cancha Principal JN' || venueController.text == 'Cancha Visitante')) {
                                  venueController.text = 'Cancha de ${oppClub['name']}';
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: isPublishing
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isPublishing = true);
                            try {
                              final firestoreService = ref.read(
                                firestoreServiceProvider,
                              );
                              final dateStr = eventDate != null
                                  ? '${eventDate!.year}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}'
                                  : null;
                              final timeStr = eventTime != null
                                  ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')} hs'
                                  : 'A confirmar';
                              final venueStr =
                                  venueController.text.trim().isNotEmpty
                                  ? venueController.text.trim()
                                  : (isHome ? 'Cancha Principal JN' : 'Cancha Visitante');

                              String? finalImageUrl;
                              if (selectedImagePath != null &&
                                  selectedImagePath!.trim().isNotEmpty) {
                                if (selectedImagePath!.startsWith('http://') ||
                                    selectedImagePath!.startsWith('https://')) {
                                  finalImageUrl = selectedImagePath!.trim();
                                } else {
                                  final localFile = File(selectedImagePath!);
                                  if (await localFile.exists()) {
                                    finalImageUrl =
                                        await ImageUploadService.uploadPostImage(
                                          localFile,
                                        );
                                  }
                                }
                              }

                              final opponentClub = selectedOpponentId != null
                                  ? clubs.where((c) => c['id'] == selectedOpponentId).firstOrNull
                                  : null;
                              final localClub = clubs.where((c) => c['isLocal'] == true).firstOrNull;

                              final String localName = localClub?['name'] ?? 'Jorge Newbery';
                              final String? localLogo = localClub?['logoUrl'] ?? 'assets/images/app_logo.jpg';
                              final String opponentName = opponentClub?['name'] ?? 'Rival';
                              final String? opponentLogo = opponentClub?['logoUrl'];

                              final homeTeam = isHome ? localName : opponentName;
                              final homeLogoUrl = isHome ? localLogo : opponentLogo;
                              final awayTeam = isHome ? opponentName : localName;
                              final awayLogoUrl = isHome ? opponentLogo : localLogo;

                              await firestoreService.addNovedad({
                                'title': titleController.text.trim(),
                                'body': bodyController.text.trim(),
                                'imageUrl': finalImageUrl,
                                'category': selectedCategory,
                                'authorId': sessionUser.id,
                                'authorName': sessionUser.fullName,
                                'authorRole':
                                    (sessionUser.role ?? '')
                                        .toString()
                                        .isNotEmpty
                                    ? sessionUser.role
                                    : 'directivo',
                                'type': eventType == 'comunicado'
                                    ? 'comunicado'
                                    : (eventType == 'partido'
                                          ? 'partido'
                                          : 'novedad'),
                                'isMatch':
                                    eventType ==
                                    'partido', // Kept for backwards compatibility
                                'eventType': eventType,
                                'hasTransport': hasTransport,
                                'isHome': isHome,
                                'condition': isHome ? 'local' : 'visitante',
                                'opponentClubId':
                                    (eventType != 'ninguno' &&
                                        eventType != 'comunicado')
                                    ? selectedOpponentId
                                    : null,
                                'awayTeam': awayTeam,
                                'opponentName': opponentName,
                                'awayLogoUrl': awayLogoUrl,
                                'homeTeam': homeTeam,
                                'homeLogoUrl': homeLogoUrl,
                                'eventDate': dateStr,
                                'date': dateStr,
                                'read': false,
                                'eventTime': timeStr,
                                'time': timeStr,
                                'location': venueStr,
                                'venue': venueStr,
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      eventType == 'partido'
                                          ? '¡Partido Amistoso publicado! ¿Deseas armar la convocatoria?'
                                          : 'Publicación realizada con éxito!',
                                    ),
                                    backgroundColor: context.colors.success,
                                    duration: const Duration(seconds: 5),
                                    action: eventType == 'partido'
                                        ? SnackBarAction(
                                            label: 'Convocar',
                                            textColor: Colors.white,
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => LineupScreen(
                                                    initialCategory: selectedCategory,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : null,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isPublishing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al publicar: $e'),
                                    backgroundColor: context.colors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Publicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isNormalUser = sessionUser.isNormalUser;
    final clubs = ref.watch(clubsStreamProvider).value ?? [];
    final hasPlayer =
        sessionUser.role == 'tutor' || sessionUser.role == 'jugador';

    final selectedChild = ref.watch(selectedChildProvider);
    final selectedCoachCat = ref.watch(selectedCoachCategoryProvider);
    final List<String> coachCategories =
        (sessionUser.assignedCategories != null &&
            sessionUser.assignedCategories!.isNotEmpty)
        ? List<String>.from(sessionUser.assignedCategories!)
        : (sessionUser.category != null && sessionUser.category!.isNotEmpty
              ? [sessionUser.category!]
              : <String>[]);

    if (sessionUser.role == 'dt' && coachCategories.isNotEmpty) {
      if (selectedCoachCat == null ||
          !coachCategories.contains(selectedCoachCat)) {
        Future.microtask(() {
          if (mounted) {
            ref.read(selectedCoachCategoryProvider.notifier).state =
                coachCategories.first;
          }
        });
      }
    }

    int unpaidQuotasCount = 0;
    if (sessionUser.role == 'tutor') {
      final players =
          ref.watch(tutorPlayersStreamProvider(sessionUser.id)).valueOrNull ??
          [];
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;

      for (final p in players) {
        final paidQuotas = List<String>.from(p['paidQuotas'] ?? []);
        for (int i = 1; i <= currentMonth; i++) {
          final quotaStr = '${'$i'.padLeft(2, '0')}/$currentYear';
          if (!paidQuotas.contains(quotaStr)) {
            unpaidQuotasCount++;
          }
        }
      }
    } else if (sessionUser.role == 'jugador') {
      final myProfile =
          ref.watch(playerProfileStreamProvider(sessionUser.id)).valueOrNull;
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      final paidQuotas = List<String>.from(myProfile?['paidQuotas'] ?? []);

      for (int i = 1; i <= currentMonth; i++) {
        final quotaStr = '${'$i'.padLeft(2, '0')}/$currentYear';
        if (!paidQuotas.contains(quotaStr)) {
          unpaidQuotasCount++;
        }
      }
    }

    String activeCategory = '';
    if (sessionUser.role == 'dt') {
      activeCategory =
          selectedCoachCat ??
          (coachCategories.isNotEmpty ? coachCategories.first : '');
    } else if (sessionUser.role == 'tutor' &&
        selectedChild != null &&
        selectedChild['category'] != null) {
      activeCategory = selectedChild['category'] as String;
    } else {
      activeCategory = sessionUser.category ?? '';
    }

    final nextMatch = ref.watch(nextMatchProvider(activeCategory));

    final List<String> relevantCategories = [];
    if (sessionUser.role == 'dt') {
      if (activeCategory.isNotEmpty) {
        relevantCategories.add(activeCategory);
      } else if (coachCategories.isNotEmpty) {
        relevantCategories.add(coachCategories.first);
      }
    } else if (sessionUser.role == 'tutor') {
      if (activeCategory.isNotEmpty) {
        relevantCategories.add(activeCategory);
      } else {
        final tutorPlayers =
            ref.watch(tutorPlayersStreamProvider(sessionUser.id)).valueOrNull ??
            [];
        for (final p in tutorPlayers) {
          final cat = p['category']?.toString();
          if (cat != null && cat.isNotEmpty) {
            relevantCategories.add(cat);
          }
        }
      }
    } else {
      if (sessionUser.assignedCategories?.isNotEmpty == true) {
        relevantCategories.addAll(sessionUser.assignedCategories!);
      } else if (sessionUser.category != null &&
          sessionUser.category!.isNotEmpty) {
        relevantCategories.add(sessionUser.category!);
      }
    }

    final String categoriesStr = relevantCategories.toSet().join(',');

    final isTutorOrPlayer = sessionUser.role == 'tutor' ||
        sessionUser.role.toLowerCase() == 'padre' ||
        sessionUser.role == 'jugador';

    final tutorConvocatoriasAsync = isTutorOrPlayer
        ? ref.watch(tutorConvocatoriasProvider(sessionUser.id))
        : null;
    final List<Map<String, dynamic>> pendingConvocatorias =
        tutorConvocatoriasAsync?.valueOrNull ?? [];

    // Listen to novedades dynamically based on user role and category
    final novedadesAsync = sessionUser.isAdmin
        ? ref.watch(allNovedadesStreamProvider)
        : ref.watch(userNovedadesStreamProvider(categoriesStr));

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, ${sessionUser.name} 👋',
                            style: context.typography.headlineLarge,
                          ),
                          const SizedBox(height: 2),
                          if (sessionUser.role == 'tutor')
                            ref
                                .watch(
                                  tutorPlayersStreamProvider(sessionUser.id),
                                )
                                .when(
                                  data: (players) {
                                    if (players.isEmpty) {
                                      return Text(
                                        'Tutor · Sin Categoría',
                                        style: context.typography.bodyMedium,
                                      );
                                    }

                                    if (selectedChild == null ||
                                        !players.any(
                                          (p) => p['id'] == selectedChild['id'],
                                        )) {
                                      final firstPlayer = players.first;
                                      if (selectedChild?['id'] !=
                                          firstPlayer['id']) {
                                        Future.microtask(() {
                                          ref
                                                  .read(
                                                    selectedChildProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              firstPlayer;
                                        });
                                      }
                                    }

                                    return DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value:
                                            selectedChild?['id'] as String? ??
                                            players.first['id'] as String?,
                                        isDense: true,
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 20,
                                        ),
                                        style: context.typography.bodyMedium
                                            .copyWith(
                                              color: context.colors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                        items: players.map((p) {
                                          final cat =
                                              p['category'] ?? 'Sin categoría';
                                          return DropdownMenuItem<String>(
                                            value: p['id'] as String,
                                            child: Text(
                                              '${p['name']} ${p['lastName']} ($cat)',
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            final child = players.firstWhere(
                                              (p) => p['id'] == val,
                                            );
                                            ref
                                                    .read(
                                                      selectedChildProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                child;
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  loading: () => Text(
                                    'Tutor · ...',
                                    style: context.typography.bodyMedium,
                                  ),
                                  error: (_, _) => Text(
                                    'Tutor · Error',
                                    style: context.typography.bodyMedium,
                                  ),
                                )
                          else if (sessionUser.role == 'dt')
                            if (coachCategories.length > 1)
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      (selectedCoachCat != null &&
                                          coachCategories.contains(
                                            selectedCoachCat,
                                          ))
                                      ? selectedCoachCat
                                      : (coachCategories.isNotEmpty
                                            ? coachCategories.first
                                            : null),
                                  isDense: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                  ),
                                  style: context.typography.bodyMedium.copyWith(
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: coachCategories.map((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat,
                                      child: Text('DT · Categoría $cat'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref
                                              .read(
                                                selectedCoachCategoryProvider
                                                    .notifier,
                                              )
                                              .state =
                                          val;
                                    }
                                  },
                                ),
                              )
                            else
                              Text(
                                coachCategories.isNotEmpty
                                    ? 'DT · Categoría ${coachCategories.first}'
                                    : 'DT · Sin Categoría',
                                style: context.typography.bodyMedium.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                          else
                            Text(
                              hasPlayer
                                  ? '${sessionUser.role == 'jugador' ? sessionUser.name : (sessionUser.role.toLowerCase() == 'padre' ? 'Tutor' : sessionUser.role.toUpperCase())} · ${sessionUser.category ?? 'Sin Categoría'}'
                                  : '${(sessionUser.role.toLowerCase() == 'padre' ? 'tutor' : sessionUser.role).toUpperCase()}${sessionUser.category != null ? " · ${sessionUser.category}" : ""}',
                              style: context.typography.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    StreamBuilder<int>(
                      stream: _unreadMessagesCountStream(sessionUser),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.mail_outline,
                                color: context.colors.textPrimary,
                                size: 26,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const InboxScreen(),
                                  ),
                                );
                              },
                            ),
                            if (count > 0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .snapshots(),
                      builder: (context, snapshot) {
                        int unreadCount = 0;
                        if (snapshot.hasData) {
                          bool isDocRead(Map<String, dynamic> data) {
                            if (data['read'] == true) return true;
                            if (sessionUser.id.isNotEmpty) {
                              if (data['readBy'] is List &&
                                  (data['readBy'] as List).contains(sessionUser.id)) {
                                return true;
                              }
                            }
                            return false;
                          }

                          unreadCount = snapshot.data!.docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            if (isDocRead(data)) return false;

                            final type = data['type']?.toString().toLowerCase().trim() ?? '';
                            final targetCat = data['targetCategory']?.toString().toLowerCase().trim() ?? '';
                            final targetRole = data['targetRole']?.toString().toLowerCase().trim() ?? '';
                            final targetUserId = data['targetUserId']?.toString().trim() ?? '';
                            final targetUserIds = data['targetUserIds'] as List<dynamic>?;

                            // ─── REGLAS PARA ADMINISTRADORES ───
                            if (sessionUser.isAdmin) {
                              // Exclusión explícita: Convocatorias a partidos
                              if (type == 'convocatoria' || type == 'partido') return false;

                              // Exclusión explícita: Mensajes privados entre otros usuarios
                              if (targetCat == 'private' || type == 'private_chat') {
                                return targetUserId == sessionUser.id ||
                                    (targetUserIds != null && targetUserIds.map((e) => e.toString()).contains(sessionUser.id));
                              }

                              // 1. Solicitud de usuarios nuevos para aprobación
                              if (type == 'new_user_pending' || type == 'pending_approval') return true;

                              // 2. Notas o informes que envíen DTs o familias
                              if (type == 'coach_report' || type == 'family_note' || type == 'informe') return true;

                              // 3. Mensajes enviados directamente hacia los administradores
                              if (targetRole == 'directivo' ||
                                  targetRole == 'admin' ||
                                  targetRole == 'secretario' ||
                                  targetCat == 'admin' ||
                                  targetCat == 'directivo') {
                                return true;
                              }
                              if (targetUserId == sessionUser.id) return true;
                              if (targetUserIds != null && targetUserIds.map((e) => e.toString()).contains(sessionUser.id)) return true;

                              // Pedidos de tienda para administradores
                              if (type == 'new_order') return true;

                              return false;
                            }

                            // ─── REGLAS PARA USUARIOS GENERALES ───
                            if (type == 'new_user_pending' || type == 'coach_report') return false;

                            if (targetUserIds != null && targetUserIds.isNotEmpty) {
                              return targetUserIds.map((e) => e.toString()).contains(sessionUser.id);
                            }
                            if (targetUserId.isNotEmpty && targetUserId != 'all' && targetUserId != 'todos') {
                              return targetUserId == sessionUser.id;
                            }
                            if (targetRole.isNotEmpty && targetRole != 'all' && targetRole != 'todos') {
                              return targetRole == sessionUser.role;
                            }
                            if (targetCat.isNotEmpty && targetCat != 'all' && targetCat != 'todos') {
                              if (sessionUser.category != null &&
                                  targetCat == sessionUser.category!.toLowerCase().trim()) {
                                return true;
                              }
                              if (sessionUser.assignedCategories != null) {
                                return (sessionUser.assignedCategories as List)
                                    .any((c) => c.toString().toLowerCase().trim() == targetCat);
                              }
                              return false;
                            }
                            return targetCat == 'all' || targetCat == 'todos' || targetUserId == 'all';
                          }).length;
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: context.colors.textPrimary,
                                size: 26,
                              ),
                              onPressed: () =>
                                  showAdminNotificationsDialog(context, sessionUser: sessionUser),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    decoration: BoxDecoration(
                                      color: context.colors.error,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          widget.onNavigate(5), // settings (now index 5)
                      child: JNAvatar(
                        name: '${sessionUser.name} ${sessionUser.lastName}',
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ─── Sponsor Carousel ────────────────────────
            const SliverToBoxAdapter(child: SponsorCarousel()),

            // ─── Club Social Media Banner ────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            const SliverToBoxAdapter(child: ClubSocialBanner()),

            // ─── Convocatoria Pending Cards (For Tutors) ───
            if (pendingConvocatorias.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: pendingConvocatorias
                        .map((c) => _buildTutorConvocatoriaCard(c))
                        .toList(),
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ─── Next Match Banner ──────────────────────
            if (nextMatch != null)
              SliverToBoxAdapter(
                child:
                    Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: JNMatchCard(
                            homeTeam: nextMatch['homeTeam'] as String,
                            awayTeam: nextMatch['awayTeam'] as String,
                            homeLogoUrl: nextMatch['homeLogoUrl'] as String?,
                            awayLogoUrl: nextMatch['awayLogoUrl'] as String?,
                            homeScore: nextMatch['homeScore'] as int?,
                            awayScore: nextMatch['awayScore'] as int?,
                            date: _formatDate(nextMatch['date'] as String),
                            time: nextMatch['time'] as String,
                            venue: nextMatch['venue'] as String,
                            status:
                                nextMatch['status'] as String? ?? 'upcoming',
                            isHero: true,
                            onTap: () =>
                                widget.onNavigate(2), // Formación tab index
                          ),
                        )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.05),
              ),

            if (nextMatch != null)
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ─── Quick Actions ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.how_to_reg,
                      label: 'Asistencia',
                      color: context.colors.success,
                      onTap: () {
                        if (sessionUser.role == 'dt' || sessionUser.isAdmin) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AttendanceScreen(),
                            ),
                          );
                        } else if (sessionUser.role == 'tutor' ||
                            sessionUser.role == 'jugador') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlayerAttendanceScreen(),
                            ),
                          );
                        } else {
                          widget.onNavigate(1);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.emoji_events_outlined,
                      label: 'Resultados',
                      color: const Color(0xFFE5B842),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ResultsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.payment,
                      label: 'Cuotas',
                      color: context.colors.info,
                      badge: unpaidQuotasCount > 0
                          ? '$unpaidQuotasCount'
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PaymentsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.campaign,
                      label: 'Noticias',
                      color: context.colors.primary,
                      onTap: () => widget.onNavigate(3),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),



            // ─── Feed de Novedades del Club ───────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Novedades del Club',
                      style: context.typography.headlineMedium,
                    ),
                    if (!isNormalUser)
                      IconButton(
                        icon: Icon(
                          Icons.add_box_outlined,
                          color: context.colors.primary,
                          size: 28,
                        ),
                        onPressed: () =>
                            _showCreatePostDialog(context, sessionUser, clubs),
                        tooltip: 'Publicar Novedad',
                      ),
                  ],
                ).animate(delay: 450.ms).fadeIn(duration: 400.ms),
              ),
            ),

            novedadesAsync.when(
              data: (novedades) {
                if (novedades.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: JNCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.feed_outlined,
                              size: 48,
                              color: context.colors.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No hay novedades disponibles',
                              style: context.typography.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              sessionUser.role == 'dt'
                                  ? 'Comienza publicando una novedad para tus categorías (${sessionUser.displayCategory}).'
                                  : 'Los entrenadores o directivos subirán novedades pronto.',
                              style: context.typography.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = novedades[index];
                    final postId = post['id'] as String;
                    final isExpanded = _expandedPostIds.contains(postId);
                    final comments = List<Map<String, dynamic>>.from(
                      (post['comments'] as List? ?? []).map(
                        (e) => Map<String, dynamic>.from(e as Map),
                      ),
                    );
                    final likes = List<String>.from(
                      post['likes'] as List? ?? [],
                    );
                    final hasLiked = likes.contains(sessionUser.id);

                    final rawSeenBy = post['seenBy'] as List? ?? [];
                    final hasSeen = rawSeenBy.any(
                      (e) {
                        if (e is Map) return e['userId'] == sessionUser.id;
                        if (e is String) return e == sessionUser.id;
                        return false;
                      },
                    );
                    final seenByList = rawSeenBy
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                    if (!hasSeen && !_markedSeenPostIds.contains(postId) && sessionUser.id.isNotEmpty) {
                      _markedSeenPostIds.add(postId);
                      Future.microtask(() async {
                        try {
                          await ref
                              .read(firestoreServiceProvider)
                              .novedades
                              .markNovedadAsSeen(postId, sessionUser);
                        } catch (_) {
                          _markedSeenPostIds.remove(postId);
                        }
                      });
                    }

                    // Check permissions to delete the post
                    final bool canDeletePost =
                        sessionUser.isAdmin ||
                        post['authorId'] == sessionUser.id;

                    // Sorting comments in chronological order
                    comments.sort((a, b) {
                      final aTime = a['createdAt'];
                      final bTime = b['createdAt'];
                      if (aTime is Timestamp && bTime is Timestamp) {
                        return aTime.compareTo(bTime);
                      }
                      return 0;
                    });

                    final rawAuthor =
                        (post['authorName'] ?? post['author'] ?? '')
                            .toString()
                            .trim();
                    final String displayAuthor =
                        (rawAuthor.isNotEmpty &&
                            rawAuthor.toLowerCase() != 'autor')
                        ? rawAuthor
                        : 'Club Jorge Newbery';

                    final rawRole = (post['authorRole'] ?? '')
                        .toString()
                        .trim();
                    final String displayRole = rawRole.isNotEmpty
                        ? rawRole.toUpperCase()
                        : (post['type'] == 'birthday'
                              ? 'SISTEMA'
                              : 'DIRECTIVA');

                    final rawCat = (post['category'] ?? 'all')
                        .toString()
                        .trim();
                    final String displayCategory =
                        (rawCat.isEmpty || rawCat.toLowerCase() == 'all')
                        ? 'Global'
                        : rawCat;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: JNCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Post Header
                            Row(
                              children: [
                                JNAvatar(name: displayAuthor, size: 36),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayAuthor,
                                        style: context.typography.titleSmall,
                                      ),
                                      Text(
                                        '$displayRole · $displayCategory',
                                        style: context.typography.bodySmall
                                            .copyWith(
                                              color:
                                                  context.colors.textTertiary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!sessionUser.isNormalUser ||
                                    post['type'] == 'birthday')
                                  IconButton(
                                    icon: Icon(
                                      Icons.share,
                                      color: context.colors.primary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StoryExportScreen(
                                                announcement: post,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                if (sessionUser.isAdmin || canDeletePost)
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: context.colors.textTertiary,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    color: context.colors.surface,
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _confirmDeletePost(context, postId);
                                      } else if (value == 'view_views') {
                                        _showNovedadViewsDialog(
                                          context,
                                          seenByList,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (sessionUser.isAdmin)
                                        PopupMenuItem(
                                          value: 'view_views',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.visibility,
                                                size: 18,
                                                color: context.colors.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Ver vistas (${seenByList.length})',
                                                style: context
                                                    .typography
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (canDeletePost)
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: context.colors.error,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Eliminar publicación',
                                                style: context
                                                    .typography
                                                    .bodySmall
                                                    .copyWith(
                                                      color:
                                                          context.colors.error,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (post['eventType'] != null &&
                                post['eventType'] != 'ninguno')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (post['eventType'] ==
                                                    'comunicado' ||
                                                post['type'] == 'comunicado')
                                            ? const Color(
                                                0xFFD4AF37,
                                              ).withValues(alpha: 0.15)
                                            : context.colors.primary.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              (post['eventType'] ==
                                                      'comunicado' ||
                                                  post['type'] == 'comunicado')
                                              ? const Color(0xFFD4AF37)
                                              : context.colors.primary,
                                        ),
                                      ),
                                      child: Text(
                                        (post['eventType'] == 'comunicado' ||
                                                post['type'] == 'comunicado')
                                            ? 'COMUNICADO OFICIAL 📢'
                                            : (post['eventType'] as String)
                                                  .toUpperCase(),
                                        style: context.typography.labelSmall
                                            .copyWith(
                                              color:
                                                  (post['eventType'] ==
                                                          'comunicado' ||
                                                      post['type'] ==
                                                          'comunicado')
                                                  ? const Color(0xFFD4AF37)
                                                  : context.colors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    if (post['hasTransport'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.directions_bus,
                                              size: 14,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'TRASLADO INCLUIDO',
                                              style: context
                                                  .typography
                                                  .labelSmall
                                                  .copyWith(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            // Post Content
                            if (post['type'] == 'birthday') ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusLg,
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD32F2F), // Rojo River
                                      Color(0xFF8B0000), // Rojo Oscuro
                                      Color(0xFF121212), // Negro
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFD32F2F),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Club Emblem / Logo
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const CircleAvatar(
                                        radius: 38,
                                        backgroundColor: Colors.white,
                                        backgroundImage: AssetImage(
                                          'assets/images/app_logo.jpg',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // High-Legibility Card Container
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Header Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD32F2F),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              '🎂 CUMPLEAÑOS DEL DÍA',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            post['title'] ??
                                                '¡Feliz Cumpleaños!',
                                            style: context
                                                .typography
                                                .headlineMedium
                                                .copyWith(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            post['body'] ?? '',
                                            style: context.typography.bodyLarge
                                                .copyWith(
                                                  color: const Color(
                                                    0xFF222222,
                                                  ),
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.4,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    // Footer
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 2,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'CLUB JORGE NEWBERY',
                                          style: context.typography.labelSmall
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 30,
                                          height: 2,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (post['eventType'] == 'partido' ||
                                post['isMatch'] == true ||
                                post['type'] == 'partido') ...[
                              _buildMatchPostCard(post, clubs, context, sessionUser),
                            ] else ...[
                              Text(
                                post['title'] ?? '',
                                style: context.typography.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post['body'] ?? '',
                                style: context.typography.bodyMedium,
                              ),
                              if (post['imageUrl'] != null &&
                                  post['imageUrl'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  child: _buildPostImage(
                                    post['imageUrl'].toString(),
                                    context,
                                  ),
                                ),
                              ],
                            ],
                            Divider(height: 24, color: context.colors.divider),

                            // Post Footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        ref
                                            .read(firestoreServiceProvider)
                                            .toggleLikeNovedad(
                                              postId,
                                              sessionUser.id,
                                            );
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            hasLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 18,
                                            color: hasLiked
                                                ? context.colors.error
                                                : context.colors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            likes.isEmpty
                                                ? 'Me gusta'
                                                : '${likes.length}',
                                            style: context.typography.bodySmall
                                                .copyWith(
                                                  color: hasLiked
                                                      ? context.colors.error
                                                      : context
                                                            .colors
                                                            .textSecondary,
                                                  fontWeight: hasLiked
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _toggleComments(postId),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18,
                                            color: isExpanded
                                                ? context.colors.primary
                                                : context.colors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            comments.isEmpty
                                                ? 'Comentar'
                                                : '${comments.length}',
                                            style: context.typography.bodySmall
                                                .copyWith(
                                                  color: isExpanded
                                                      ? context.colors.primary
                                                      : context
                                                            .colors
                                                            .textSecondary,
                                                  fontWeight: isExpanded
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _toggleComments(postId),
                                  child: Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: context.colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),

                            // Expanded Comments section
                            if (isExpanded) ...[
                              const SizedBox(height: 12),
                              // Comment Input field
                              if (sessionUser.role != 'jugador') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentControllers[postId],
                                        style: context.typography.bodyMedium,
                                        decoration: const InputDecoration(
                                          hintText: 'Escribe un comentario...',
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.send,
                                        color: context.colors.primary,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _submitComment(postId, sessionUser),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    'Los jugadores no pueden realizar comentarios.',
                                    style: context.typography.bodySmall
                                        .copyWith(
                                          color: context.colors.textTertiary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ),
                              ],
                              // Comments List
                              if (comments.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: comments.length,
                                  itemBuilder: (context, commentIdx) {
                                    final comment = comments[commentIdx];
                                    final bool canDeleteComment =
                                        sessionUser.isAdmin ||
                                        comment['userId'] == sessionUser.id;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          JNAvatar(
                                            name: comment['userName'] ?? 'User',
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color:
                                                    context.colors.surfaceLight,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${comment['userName']} (${(comment['userRole'] ?? '').toUpperCase()})',
                                                        style: context
                                                            .typography
                                                            .labelSmall
                                                            .copyWith(
                                                              color: context
                                                                  .colors
                                                                  .accent,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                      if (canDeleteComment)
                                                        GestureDetector(
                                                          onTap: () =>
                                                              _confirmDeleteComment(
                                                                context,
                                                                postId,
                                                                comment,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: context
                                                                .colors
                                                                .error,
                                                            size: 14,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    comment['text'] ?? '',
                                                    style: context
                                                        .typography
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    );
                  }, childCount: novedades.length),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (err, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Error al cargar novedades: $err',
                      style: TextStyle(color: context.colors.error),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Novedad'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta publicación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).deleteNovedad(postId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Publicación eliminada'),
                    backgroundColor: context.colors.warning,
                  ),
                );
              }
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(
    BuildContext context,
    String postId,
    Map<String, dynamic> comment,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Comentario'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este comentario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(firestoreServiceProvider)
                  .deleteCommentFromNovedad(postId, comment);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Comentario eliminado'),
                    backgroundColor: context.colors.warning,
                  ),
                );
              }
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment(String postId, dynamic sessionUser) async {
    if (sessionUser.role == 'jugador') return;
    final controller = _commentControllers[postId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final commentText = controller.text.trim();
    controller.clear();

    final commentData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'userId': sessionUser.id,
      'userName': '${sessionUser.name} ${sessionUser.lastName}',
      'userRole': sessionUser.role,
      'text': commentText,
      'createdAt': Timestamp.now(),
    };

    await ref
        .read(firestoreServiceProvider)
        .addCommentToNovedad(postId, commentData);
  }

  void _showNovedadViewsDialog(
    BuildContext context,
    List<Map<String, dynamic>> seenByList,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Visto por (${seenByList.length})',
          style: context.typography.titleMedium,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: seenByList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Nadie ha visto esta publicación aún.',
                    style: context.typography.bodyMedium,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: seenByList.length,
                  itemBuilder: (context, index) {
                    final view = seenByList[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JNAvatar(name: view['userName'] ?? '', size: 36),
                      title: Text(
                        view['userName'] ?? '',
                        style: context.typography.titleSmall,
                      ),
                      subtitle: Text(
                        (view['role'] ?? '').toUpperCase(),
                        style: context.typography.bodySmall,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.trim().split('-');
      if (parts.length != 3) return dateStr;
      final months = [
        '',
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      final month = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2].split('T').first.split(' ').first) ?? 0;
      if (month >= 1 && month <= 12 && day > 0) {
        return '$day ${months[month]}';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

}

// ─── Quick Action Button ──────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: JNCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: context.typography.labelSmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildImagePreview(
  String? localPath,
  BuildContext context, {
  VoidCallback? onRemove,
}) {
  if (localPath != null && localPath.trim().isNotEmpty) {
    final cleanPath = localPath.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://'))
          CachedNetworkImage(
            imageUrl: cleanPath,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: context.colors.surfaceLight),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
          )
        else
          Image.file(
            File(cleanPath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 36),
            ),
          ),
        Container(
          color: Colors.black.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Cambiar',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 38,
          color: context.colors.primary,
        ),
        const SizedBox(height: 6),
        Text(
          'Toca para subir una foto desde la galería',
          style: context.typography.bodyMedium.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildPostImage(String url, BuildContext context) {
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) {
    return const SizedBox.shrink();
  }

  if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
    return Image.file(
      File(cleanUrl),
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }

  return CachedNetworkImage(
    imageUrl: cleanUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    placeholder: (context, url) => Container(
      width: double.infinity,
      height: 180,
      color: context.colors.surfaceLight,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      width: double.infinity,
      height: 140,
      color: context.colors.surfaceLight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: context.colors.textTertiary, size: 32),
            const SizedBox(height: 4),
            Text(
              'No se pudo cargar la imagen',
              style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildMatchPostCard(
  Map<String, dynamic> post,
  List<Map<String, dynamic>> clubs,
  BuildContext context, [
  UserSession? sessionUser,
]) {
  final localClub = clubs.where((c) => c['isLocal'] == true).firstOrNull ??
      clubs.where((c) => (c['name'] as String?)?.toLowerCase().contains('newbery') == true).firstOrNull;
  final String defaultLocalName = localClub?['name'] ?? 'Jorge Newbery';
  final String? defaultLocalLogo = localClub?['logoUrl'] ?? 'assets/images/app_logo.jpg';

  final bool isVisitor = post['isHome'] == false ||
      post['condition'] == 'visitante' ||
      post['isVisitor'] == true ||
      (post['awayTeam'] != null && post['awayTeam'].toString().toLowerCase().contains('newbery'));

  final opponentClub = clubs.where((c) =>
      (post['opponentClubId'] != null && c['id'] == post['opponentClubId']) ||
      (post['awayClubId'] != null && c['id'] == post['awayClubId'] && c['isLocal'] != true) ||
      (post['homeClubId'] != null && c['id'] == post['homeClubId'] && c['isLocal'] != true) ||
      (post['awayTeam'] != null && c['name']?.toString().toLowerCase() == post['awayTeam'].toString().toLowerCase() && c['isLocal'] != true) ||
      (post['homeTeam'] != null && c['name']?.toString().toLowerCase() == post['homeTeam'].toString().toLowerCase() && c['isLocal'] != true) ||
      (post['opponentName'] != null && c['name']?.toString().toLowerCase() == post['opponentName'].toString().toLowerCase() && c['isLocal'] != true)
  ).firstOrNull;

  final String opponentName = opponentClub?['name'] ?? post['opponentName'] ?? (isVisitor ? post['homeTeam'] : post['awayTeam']) ?? 'Rival';
  final String? opponentLogo = opponentClub?['logoUrl'] ?? (isVisitor ? post['homeLogoUrl'] : post['awayLogoUrl']);

  final String homeTeamName;
  final String? homeLogoUrl;
  final String awayTeamName;
  final String? awayLogoUrl;

  if (isVisitor) {
    homeTeamName = (post['homeTeam'] != null && !post['homeTeam'].toString().toLowerCase().contains('newbery'))
        ? post['homeTeam']
        : opponentName;
    homeLogoUrl = post['homeLogoUrl'] ?? (homeTeamName == opponentName ? opponentLogo : null);

    awayTeamName = post['awayTeam'] ?? defaultLocalName;
    awayLogoUrl = post['awayLogoUrl'] ?? defaultLocalLogo;
  } else {
    homeTeamName = post['homeTeam'] ?? defaultLocalName;
    homeLogoUrl = post['homeLogoUrl'] ?? defaultLocalLogo;

    awayTeamName = (post['awayTeam'] != null && !post['awayTeam'].toString().toLowerCase().contains('newbery'))
        ? post['awayTeam']
        : opponentName;
    awayLogoUrl = post['awayLogoUrl'] ?? (awayTeamName == opponentName ? opponentLogo : null);
  }

  final String dateStr = post['eventDate'] ?? post['date'] ?? '';
  final String timeStr = post['eventTime'] ?? post['time'] ?? 'A confirmar';
  final String venueStr = post['venue'] ?? post['location'] ?? (isVisitor ? 'Cancha Visitante' : 'Cancha Principal JN');
  final String catStr = post['category'] ?? '';

  String formatMatchDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      final parts = rawDate.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]) ?? 2026;
        final month = int.tryParse(parts[1]) ?? 1;
        final day = int.tryParse(parts[2]) ?? 1;
        final dt = DateTime(year, month, day);
        const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
        const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        return '${weekdays[dt.weekday - 1]} $day ${months[month - 1]}';
      }
    } catch (_) {}
    return rawDate;
  }

  final String dateFormatted = formatMatchDate(dateStr);
  final String dateDisplay = dateFormatted.isNotEmpty
      ? (timeStr.isNotEmpty && timeStr.toLowerCase() != 'a confirmar'
          ? '$dateFormatted · $timeStr'
          : dateFormatted)
      : (timeStr.isNotEmpty && timeStr.toLowerCase() != 'a confirmar' ? timeStr : '');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Match Hero Banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.surfaceLight,
              context.colors.surface,
              context.colors.primary.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            // Top Match Header Badge & Date
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_soccer, size: 14, color: context.colors.primary),
                      const SizedBox(width: 5),
                      Text(
                        catStr.isNotEmpty && catStr != 'all' ? 'AMISTOSO · CAT. $catStr' : 'PARTIDO AMISTOSO',
                        style: context.typography.labelSmall.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dateDisplay.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: context.colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          dateDisplay,
                          style: context.typography.bodySmall.copyWith(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Teams Row (Local VS Away with Logos)
            Row(
              children: [
                // Local Club
                Expanded(
                  child: Column(
                    children: [
                      _buildTeamLogo(context, homeTeamName, homeLogoUrl),
                      const SizedBox(height: 8),
                      Text(
                        homeTeamName,
                        style: context.typography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // VS Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'VS',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.textTertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // Away Club
                Expanded(
                  child: Column(
                    children: [
                      _buildTeamLogo(context, awayTeamName, awayLogoUrl),
                      const SizedBox(height: 8),
                      Text(
                        awayTeamName,
                        style: context.typography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            // Location / Venue
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: context.colors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  venueStr,
                  style: context.typography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),

            if (sessionUser != null && (sessionUser.role == 'dt' || sessionUser.isAdmin)) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text(
                    'Convocar Jugadores',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LineupScreen(
                          initialCategory: catStr.isNotEmpty && catStr != 'all' ? catStr : null,
                          initialMatchId: post['id'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),

      // Post Title & Body if different or extra notes
      if (post['title'] != null &&
          post['title'].toString().trim().isNotEmpty &&
          post['title'].toString().trim() != 'Partido Amistoso') ...[
        const SizedBox(height: 12),
        Text(
          post['title'],
          style: context.typography.titleMedium,
        ),
      ],
      if (post['body'] != null &&
          post['body'].toString().trim().isNotEmpty &&
          post['body'].toString().trim() != 'Convocatoria y detalles del partido') ...[
        const SizedBox(height: 6),
        Text(
          post['body'],
          style: context.typography.bodyMedium,
        ),
      ],

      // Attached photo (if any was uploaded)
      if (post['imageUrl'] != null && post['imageUrl'].toString().trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: _buildPostImage(
            post['imageUrl'].toString(),
            context,
          ),
        ),
      ],
    ],
  );
}

Widget _buildTeamLogo(BuildContext context, String team, String? logoUrl) {
  if (logoUrl != null && logoUrl.trim().isNotEmpty) {
    final cleanLogo = logoUrl.trim();
    if (cleanLogo.startsWith('assets/')) {
      return Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: Image.asset(cleanLogo, fit: BoxFit.cover),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: cleanLogo,
      width: 50,
      height: 50,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(Icons.shield_outlined, color: context.colors.primary, size: 28),
        ),
      ),
    );
  }

  if (team.toLowerCase().contains('newbery') || team.toLowerCase().contains('jorge newbery')) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: Image.asset('assets/images/app_logo.jpg', fit: BoxFit.cover),
      ),
    );
  }

  return Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: context.colors.surfaceVariant,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Icon(Icons.shield_outlined, color: context.colors.primary, size: 28),
    ),
  );
}
