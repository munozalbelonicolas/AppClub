import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/birthday_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_match_card.dart';
import '../../../../core/widgets/jn_section_header.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../inbox/presentation/screens/inbox_screen.dart';
import '../../../payments/presentation/screens/payments_screen.dart';
import '../../../settings/presentation/widgets/admin_notifications_dialog.dart';
import '../widgets/export_post_dialog.dart';
import '../widgets/sponsor_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _expandedPostIds = {};
  final Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final sessionUser = ref.read(currentUserProvider);
        if (sessionUser != null && (sessionUser.role == 'directivo' || sessionUser.role == 'secretario')) {
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
                return (data['unreadBy'] as List?)?.contains(sessionUser.id) ?? false;
              }
              return (data['unreadByUser'] ?? false) == true;
            }).length,
          );
    } else {
      return db.collection('inbox_threads').snapshots().map((snap) {
        var docs = snap.docs;
        if (sessionUser.role == 'dt') {
          final assignedCats = sessionUser.assignedCategories?.map((c) => c.toLowerCase()).toList() ?? [];
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
            final isParticipant = (data['participants'] as List?)?.contains(sessionUser.id) ?? false;
            return assignedCats.contains(otherCategory) || isParticipant;
          }).toList();
        }
        return docs.where((doc) {
          final data = doc.data();
          bool isUnread = (data['unreadBy'] as List?)?.contains(sessionUser.id) ?? false;
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

  void _showCreatePostDialog(BuildContext context, dynamic sessionUser, List<Map<String, dynamic>> clubs) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final imageUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String eventType = 'ninguno';
    bool hasTransport = false;
    String? selectedOpponentId;

    // Default category configuration
    String selectedCategory = 'all';
    final bool isDT = sessionUser.role == 'dt';
    if (isDT && sessionUser.category != null) {
      selectedCategory = sessionUser.category!;
    }

    final appCategories = ref.read(appCategoriesProvider);
    final List<String> categories = ['all', ...appCategories];

    final List<Map<String, String>> imagePresets = [
      {
        'label': 'Entrenamiento',
        'url':
            'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      },
      {
        'label': 'Partido',
        'url':
            'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      },
      {
        'label': 'Festejo',
        'url':
            'https://images.unsplash.com/photo-1518063319789-7217e6706b04?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      },
    ];

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
              title: Text('Nueva Publicación', style: context.typography.titleLarge),
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
                      TextFormField(
                        controller: imageUrlController,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'URL de imagen opcional (HTTPS)',
                          labelText: 'Imagen URL (Opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Presets image selection
                      Text(
                        'Imágenes rápidas:',
                        style: context.typography.labelSmall.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: imagePresets.map((preset) {
                          return ActionChip(
                            label: Text(preset['label']!),
                            labelStyle: context.typography.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                            backgroundColor: context.colors.surfaceLight,
                            onPressed: () {
                              setDialogState(() {
                                imageUrlController.text = preset['url']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      // Category selection
                      if (isDT) ...[
                        Text(
                          'Categoría: ${sessionUser.category}',
                          style: context.typography.bodyMedium.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          dropdownColor: context.colors.surface,
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Visibilidad/Categoría',
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(
                                cat == 'all' ? 'Global (Todos)' : cat,
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
                        decoration: const InputDecoration(labelText: 'Tipo de Evento'),
                        items: const [
                          DropdownMenuItem(value: 'ninguno', child: Text('Ninguno (Publicación normal)')),
                          DropdownMenuItem(value: 'partido', child: Text('Partido')),
                          DropdownMenuItem(value: 'evento', child: Text('Evento Especial')),
                          DropdownMenuItem(value: 'jornada', child: Text('Jornada')),
                          DropdownMenuItem(value: 'cuadrangular', child: Text('Cuadrangular')),
                          DropdownMenuItem(value: 'torneo', child: Text('Torneo')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              eventType = val;
                              if (eventType == 'ninguno') {
                                hasTransport = false;
                                selectedOpponentId = null;
                              }
                            });
                          }
                        },
                      ),
                      if (eventType != 'ninguno') ...[
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
                          activeTrackColor: Colors.orange.withValues(alpha: 0.3),
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
                          decoration: const InputDecoration(labelText: 'Club Rival (Opcional)'),
                          items: clubs.where((c) => c['isLocal'] != true).map((club) {
                            return DropdownMenuItem<String>(
                              value: club['id'],
                              child: Text(club['name'], style: context.typography.bodyLarge),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedOpponentId = val;
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final firestoreService = ref.read(
                        firestoreServiceProvider,
                      );
                      await firestoreService.addNovedad({
                        'title': titleController.text.trim(),
                        'body': bodyController.text.trim(),
                        'imageUrl': imageUrlController.text.trim().isEmpty
                            ? null
                            : imageUrlController.text.trim(),
                        'category': selectedCategory,
                        'authorId': sessionUser.id,
                        'authorName':
                            '${sessionUser.name} ${sessionUser.lastName}',
                        'authorRole': sessionUser.role,
                        'isMatch': eventType == 'partido', // Kept for backwards compatibility
                        'eventType': eventType,
                        'hasTransport': hasTransport,
                        'opponentClubId': (eventType != 'ninguno') ? selectedOpponentId : null,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Novedad publicada con éxito!'),
                            backgroundColor: context.colors.success,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Publicar'),
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
    final sessionUser = ref.watch(currentUserProvider)!;
    final isNormalUser = sessionUser.isNormalUser;
    final clubs = ref.watch(clubsStreamProvider).value ?? [];
    final hasPlayer =
        sessionUser.role == 'tutor' || sessionUser.role == 'jugador';
        
    final selectedChild = ref.watch(selectedChildProvider);

    // In production, these will come from streams or futures.
    // For now, we set them to empty to ensure the app doesn't crash without MockData.
    const Map<String, dynamic>? player = null; // To be fetched from Firestore
    const Map<String, dynamic>? nextMatch =
        null; // To be fetched from Firestore
    const Map<String, dynamic>? pendingPayment =
        null; // To be fetched from Firestore

    String categoriesStr = sessionUser.assignedCategories?.isNotEmpty == true
        ? sessionUser.assignedCategories!.join(',')
        : (sessionUser.category ?? '');
        
    if (sessionUser.role == 'tutor' && selectedChild != null && selectedChild['category'] != null) {
      categoriesStr = selectedChild['category'] as String;
    }

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
                            ref.watch(tutorPlayersStreamProvider(sessionUser.id)).when(
                                  data: (players) {
                                    if (players.isEmpty) {
                                      return Text(
                                        'Tutor · Sin Categoría',
                                        style: context.typography.bodyMedium,
                                      );
                                    }
                                    
                                    // Set default selected child if null
                                    if (selectedChild == null) {
                                      Future.microtask(() {
                                        ref.read(selectedChildProvider.notifier).state = players.first;
                                      });
                                    }
                                    
                                    return DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedChild?['id'] as String? ?? players.first['id'] as String?,
                                        isDense: true,
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                        style: context.typography.bodyMedium.copyWith(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        items: players.map((p) {
                                          final cat = p['category'] ?? 'Sin categoría';
                                          return DropdownMenuItem<String>(
                                            value: p['id'] as String,
                                            child: Text('${p['name']} ${p['lastName']} ($cat)'),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            final child = players.firstWhere((p) => p['id'] == val);
                                            ref.read(selectedChildProvider.notifier).state = child;
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
                    if (sessionUser.isAdmin)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where('read', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data?.docs.length ?? 0;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications_outlined, color: context.colors.textPrimary, size: 26),
                                onPressed: () => showAdminNotificationsDialog(context),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: context.colors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                            homeScore: nextMatch['homeScore'] as int?,
                            awayScore: nextMatch['awayScore'] as int?,
                            date: _formatDate(nextMatch['date'] as String),
                            time: nextMatch['time'] as String,
                            venue: nextMatch['venue'] as String,
                            status: nextMatch['status'] as String,
                            isHero: true,
                            onTap: () => widget.onNavigate(
                              4,
                            ), // Results tab is index 4 now
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
                        } else {
                          widget.onNavigate(1);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.sports_soccer,
                      label: 'Formación',
                      color: context.colors.accent,
                      onTap: () => widget.onNavigate(2),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.payment,
                      label: 'Cuotas',
                      color: context.colors.info,
                      badge: '1',
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

            // ─── Payment Status ─────────────────────────
            if (pendingPayment != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: JNCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentsScreen(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.colors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            size: 22,
                            color: context.colors.warning,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cuota ${pendingPayment['month']}',
                                style: context.typography.titleMedium,
                              ),
                              Text(
                                'Vence el ${_formatDate(pendingPayment['dueDate'] as String)}',
                                style: context.typography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${_formatNumber(pendingPayment['amount'] as int)}',
                              style: context.typography.titleLarge.copyWith(
                                color: context.colors.warning,
                              ),
                            ),
                            JNBadge.pending(),
                          ],
                        ),
                      ],
                    ),
                  ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideX(begin: 0.03),
                ),
              ),

            if (pendingPayment != null)
              const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Player Quick Stats ─────────────────────
            if (hasPlayer && player != null) ...[
              SliverToBoxAdapter(
                child: JNSectionHeader(
                  title: 'Estadísticas de ${player['name']}',
                  actionLabel: 'Ver perfil',
                  onAction: () {},
                ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _MiniStatCard(
                        value: '${player['goals']}',
                        label: 'Goles',
                        icon: Icons.sports_soccer,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 10),
                      _MiniStatCard(
                        value: '${player['assists']}',
                        label: 'Asistencias',
                        icon: Icons.handshake,
                        color: context.colors.accent,
                      ),
                      const SizedBox(width: 10),
                      _MiniStatCard(
                        value: '${player['matches']}',
                        label: 'Partidos',
                        icon: Icons.stadium,
                        color: context.colors.info,
                      ),
                      const SizedBox(width: 10),
                      _MiniStatCard(
                        value: '${player['attendance']}%',
                        label: 'Asistencia',
                        icon: Icons.check_circle,
                        color: context.colors.success,
                      ),
                    ],
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

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
                                  ? 'Comienza publicando una novedad para la categoría ${sessionUser.category}.'
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
                    final likes = List<String>.from(post['likes'] as List? ?? []);
                    final hasLiked = likes.contains(sessionUser.id);
                    
                    final seenByList = List<Map<String, dynamic>>.from(
                      (post['seenBy'] as List? ?? []).map(
                        (e) => Map<String, dynamic>.from(e as Map),
                      ),
                    );
                    final hasSeen = seenByList.any((e) => e['userId'] == sessionUser.id);

                    if (!hasSeen) {
                      Future.microtask(() {
                        ref.read(firestoreServiceProvider).novedades.markNovedadAsSeen(postId, sessionUser);
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
                                JNAvatar(
                                  name: post['authorName'] ?? 'Club',
                                  size: 36,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post['authorName'] ?? 'Autor',
                                        style: context.typography.titleSmall,
                                      ),
                                      Text(
                                        '${(post['authorRole'] ?? '').toUpperCase()} · ${post['category'] == 'all' ? 'Global' : post['category']}',
                                        style: context.typography.bodySmall.copyWith(
                                          color: context.colors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!sessionUser.isNormalUser || post['type'] == 'birthday')
                                  IconButton(
                                    icon: Icon(
                                      Icons.share,
                                      color: context.colors.primary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            ExportPostDialog(postId: postId),
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
                                        _showNovedadViewsDialog(context, seenByList);
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
                                                style: context.typography.bodySmall,
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
                                                style: context.typography.bodySmall.copyWith(
                                                  color: context.colors.error,
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
                            if (post['eventType'] != null && post['eventType'] != 'ninguno')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.colors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: context.colors.primary),
                                      ),
                                      child: Text(
                                        (post['eventType'] as String).toUpperCase(),
                                        style: context.typography.labelSmall.copyWith(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (post['hasTransport'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.directions_bus, size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              'TRASLADO INCLUIDO',
                                              style: context.typography.labelSmall.copyWith(
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
                                  vertical: 32,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      context.colors.primary,
                                      context.colors.accent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '🎉',
                                      style: TextStyle(fontSize: 48),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      post['title'] ?? '¡Feliz Cumpleaños!',
                                      style: context.typography.headlineMedium
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      post['body'] ?? '',
                                      style: context.typography.bodyLarge.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '🎂',
                                          style: TextStyle(fontSize: 24),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '🎈',
                                          style: TextStyle(fontSize: 24),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '🎁',
                                          style: TextStyle(fontSize: 24),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
                              if (post['imageUrl'] != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: post['imageUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 160,
                                    placeholder: (context, url) =>
                                        Shimmer.fromColors(
                                          baseColor: context.colors.surfaceLight,
                                          highlightColor: context.colors.surface,
                                          child: Container(
                                            color: context.colors.surfaceLight,
                                            height: 160,
                                          ),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        const SizedBox.shrink(),
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
                                        ref.read(firestoreServiceProvider).toggleLikeNovedad(postId, sessionUser.id);
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            hasLiked ? Icons.favorite : Icons.favorite_border,
                                            size: 18,
                                            color: hasLiked ? context.colors.error : context.colors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            likes.isEmpty
                                                ? 'Me gusta'
                                                : '${likes.length}',
                                            style: context.typography.bodySmall.copyWith(
                                              color: hasLiked ? context.colors.error : context.colors.textSecondary,
                                              fontWeight: hasLiked ? FontWeight.bold : FontWeight.normal,
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
                                            style: context.typography.bodySmall.copyWith(
                                              color: isExpanded
                                                  ? context.colors.primary
                                                  : context.colors.textSecondary,
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
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'Los jugadores no pueden realizar comentarios.',
                                    style: context.typography.bodySmall.copyWith(
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
                                                color: context.colors.surfaceLight,
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
                                                        style: context.typography
                                                            .labelSmall
                                                            .copyWith(
                                                              color: context.colors
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
                                                            color:
                                                                context.colors.error,
                                                            size: 14,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    comment['text'] ?? '',
                                                    style:
                                                        context.typography.bodySmall,
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

  void _showNovedadViewsDialog(BuildContext context, List<Map<String, dynamic>> seenByList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Visto por (${seenByList.length})', style: context.typography.titleMedium),
        content: SizedBox(
          width: double.maxFinite,
          child: seenByList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Nadie ha visto esta publicación aún.', style: context.typography.bodyMedium),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: seenByList.length,
                  itemBuilder: (context, index) {
                    final view = seenByList[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JNAvatar(name: view['userName'] ?? '', size: 36),
                      title: Text(view['userName'] ?? '', style: context.typography.titleSmall),
                      subtitle: Text((view['role'] ?? '').toUpperCase(), style: context.typography.bodySmall),
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
    final parts = dateStr.split('-');
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
    final day = int.parse(parts[2]);
    final month = int.parse(parts[1]);
    return '$day ${months[month]}';
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k'
          .replaceAll('.', '.');
    }
    return number.toString();
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

// ─── Mini Stat Card ─────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return JNCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.typography.headlineMedium.copyWith(color: color),
              ),
              Text(label.toUpperCase(), style: context.typography.statLabel),
            ],
          ),
        ],
      ),
    );
  }
}