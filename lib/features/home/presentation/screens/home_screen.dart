import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_match_card.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_section_header.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../widgets/sponsor_carousel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../inbox/presentation/screens/inbox_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _expandedPostIds = {};
  final Map<String, TextEditingController> _commentControllers = {};

  Stream<int> _unreadMessagesCountStream(dynamic sessionUser) {
    final db = FirebaseFirestore.instance;
    if (sessionUser.isNormalUser) {
      return db
          .collection('inbox_threads')
          .where('participants', arrayContains: sessionUser.id)
          .snapshots()
          .map((snap) => snap.docs
              .where((doc) => (doc.data()['unreadByUser'] ?? false) == true)
              .length);
    } else {
      return db
          .collection('inbox_threads')
          .snapshots()
          .map((snap) {
            var docs = snap.docs;
            if (sessionUser.role == 'dt') {
              final cat = (sessionUser.category ?? '').toLowerCase();
              docs = docs.where((doc) {
                final data = doc.data();
                final categoriesMap = data['userCategories'] as Map<String, dynamic>? ?? {};
                String otherUserId = '';
                for (final pId in data['participants'] ?? []) {
                  if (pId != sessionUser.id) {
                    otherUserId = pId;
                    break;
                  }
                }
                final otherCategory = (categoriesMap[otherUserId] ?? '').toString().toLowerCase();
                return otherCategory == cat;
              }).toList();
            }
            return docs.where((doc) => (doc.data()['unreadByAdmin'] ?? false) == true).length;
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

  void _showCreatePostDialog(BuildContext context, dynamic sessionUser) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final imageUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Default category configuration
    String selectedCategory = 'all';
    final bool isDT = sessionUser.role == 'dt';
    if (isDT && sessionUser.category != null) {
      selectedCategory = sessionUser.category!;
    }

    final List<String> categories = ['all', 'Sub-12', 'Sub-14', 'Sub-16', 'Femenino', 'Sénior'];

    final List<Map<String, String>> imagePresets = [
      {
        'label': 'Entrenamiento',
        'url': 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3'
      },
      {
        'label': 'Partido',
        'url': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3'
      },
      {
        'label': 'Festejo',
        'url': 'https://images.unsplash.com/photo-1518063319789-7217e6706b04?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3'
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: AppColors.border, width: 0.5),
              ),
              title: Text('Nueva Publicación', style: AppTypography.titleLarge),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(hintText: 'Título de la novedad', labelText: 'Título'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Ingresa un título' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bodyController,
                        maxLines: 3,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(hintText: 'Escribe aquí la novedad...', labelText: 'Contenido'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Ingresa el contenido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imageUrlController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'URL de imagen opcional (HTTPS)',
                          labelText: 'Imagen URL (Opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Presets image selection
                      Text('Imágenes rápidas:', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: imagePresets.map((preset) {
                          return ActionChip(
                            label: Text(preset['label']!),
                            labelStyle: AppTypography.labelSmall.copyWith(color: Colors.white),
                            backgroundColor: AppColors.surfaceLight,
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
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          dropdownColor: AppColors.surface,
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Visibilidad/Categoría'),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat == 'all' ? 'Global (Todos)' : cat, style: AppTypography.bodyLarge),
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final firestoreService = ref.read(firestoreServiceProvider);
                      await firestoreService.addNovedad({
                        'title': titleController.text.trim(),
                        'body': bodyController.text.trim(),
                        'imageUrl': imageUrlController.text.trim().isEmpty ? null : imageUrlController.text.trim(),
                        'category': selectedCategory,
                        'authorId': sessionUser.id,
                        'authorName': '${sessionUser.name} ${sessionUser.lastName}',
                        'authorRole': sessionUser.role,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Novedad publicada con éxito!'),
                            backgroundColor: AppColors.success,
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

  void _showSeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cargar Datos de Prueba'),
        content: const Text('Esto creará un par de novedades iniciales en Firestore para ver cómo funciona el filtrado de roles.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final firestoreService = ref.read(firestoreServiceProvider);
              // Post 1: Global
              await firestoreService.addNovedad({
                'title': '¡Gran remodelación de vestuarios!',
                'body': 'Comenzamos con las obras de remodelación en la sede del club. Gracias al esfuerzo de todos, los vestuarios de fútbol juvenil estarán listos para el próximo mes.',
                'imageUrl': 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
                'category': 'all',
                'authorId': 'usr_dir_01',
                'authorName': 'Lorena Gómez',
                'authorRole': 'directivo',
              });
              // Post 2: Sub-12 specific
              await firestoreService.addNovedad({
                'title': 'Entrenamiento táctico Sub-12',
                'body': 'Chicos, este miércoles repasaremos tácticas de balón parado. Es importante que asistan todos a horario en la cancha 2.',
                'imageUrl': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
                'category': 'Sub-12',
                'authorId': 'usr_dt_01',
                'authorName': 'Pablo Ramírez',
                'authorRole': 'dt',
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Novedades de prueba cargadas!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider) ?? SessionMocks.users['padre']!;
    final isNormalUser = sessionUser.isNormalUser;
    final hasPlayer = sessionUser.role == 'padre' || sessionUser.role == 'jugador';
    final player = MockData.currentPlayer;
    final nextMatch = MockData.nextMatch;
    final pendingPayment = MockData.payments.firstWhere((p) => p['status'] == 'pending');
    final unreadAnnouncements = MockData.announcements.where((a) => a['read'] == false).length;

    // Listen to novedades dynamically based on user role and category
    final novedadesAsync = sessionUser.isAdmin
        ? ref.watch(allNovedadesStreamProvider)
        : ref.watch(userNovedadesStreamProvider(sessionUser.category));

    return Scaffold(
      backgroundColor: AppColors.background,
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
                            style: AppTypography.headlineLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasPlayer
                                ? '${player['name']} ${player['lastName']} · ${sessionUser.category}'
                                : '${sessionUser.role.toUpperCase()}${sessionUser.category != null ? " · ${sessionUser.category}" : ""}',
                            style: AppTypography.bodyMedium,
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
                              icon: const Icon(Icons.mail_outline, color: Colors.white, size: 26),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const InboxScreen()),
                                );
                              },
                            ),
                            if (count > 0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
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
                    GestureDetector(
                      onTap: () => widget.onNavigate(5), // settings (now index 5)
                      child: JNAvatar(
                        name: '${sessionUser.name} ${sessionUser.lastName}',
                        size: 44,
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
            SliverToBoxAdapter(
              child: Padding(
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
                  onTap: () => widget.onNavigate(4), // Results tab is index 4 now
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.05),
            ),

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
                      color: AppColors.success,
                      badge: null,
                      onTap: () => widget.onNavigate(1),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.sports_soccer,
                      label: 'Formación',
                      color: AppColors.accent,
                      badge: null,
                      onTap: () => widget.onNavigate(2),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.payment,
                      label: 'Cuotas',
                      color: AppColors.info,
                      badge: '1',
                      onTap: () => widget.onNavigate(3),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.campaign,
                      label: 'Noticias',
                      color: AppColors.primary,
                      badge: unreadAnnouncements > 0 ? '$unreadAnnouncements' : null,
                      onTap: () => widget.onNavigate(3),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Payment Status ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: JNCard(
                  onTap: () => widget.onNavigate(3), // Noticias/payments tab is index 3 now
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, size: 22, color: AppColors.warning),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cuota ${pendingPayment['month']}', style: AppTypography.titleMedium),
                            Text(
                              'Vence el ${_formatDate(pendingPayment['dueDate'] as String)}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_formatNumber(pendingPayment['amount'] as int)}',
                            style: AppTypography.titleLarge.copyWith(color: AppColors.warning),
                          ),
                          JNBadge.pending(),
                        ],
                      ),
                    ],
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideX(begin: 0.03),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Player Quick Stats ─────────────────────
            if (hasPlayer) ...[
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
                      _MiniStatCard(value: '${player['goals']}', label: 'Goles', icon: Icons.sports_soccer, color: AppColors.primary),
                      const SizedBox(width: 10),
                      _MiniStatCard(value: '${player['assists']}', label: 'Asistencias', icon: Icons.handshake, color: AppColors.accent),
                      const SizedBox(width: 10),
                      _MiniStatCard(value: '${player['matches']}', label: 'Partidos', icon: Icons.stadium, color: AppColors.info),
                      const SizedBox(width: 10),
                      _MiniStatCard(value: '${player['attendance']}%', label: 'Asistencia', icon: Icons.check_circle, color: AppColors.success),
                    ],
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

            // ─── Feed de Novedades del Club ───────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Novedades del Club', style: AppTypography.headlineMedium),
                    if (!isNormalUser)
                      IconButton(
                        icon: const Icon(Icons.add_box_outlined, color: AppColors.primary, size: 28),
                        onPressed: () => _showCreatePostDialog(context, sessionUser),
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
                            const Icon(Icons.feed_outlined, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text('No hay novedades disponibles', style: AppTypography.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              sessionUser.role == 'dt'
                                  ? 'Comienza publicando una novedad para la categoría ${sessionUser.category}.'
                                  : 'Los entrenadores o directivos subirán novedades pronto.',
                              style: AppTypography.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            if (!isNormalUser) ...[
                              const SizedBox(height: 16),
                              JNButton(
                                label: 'Cargar Datos de Prueba',
                                onPressed: () => _showSeedDialog(context),
                                size: JNButtonSize.small,
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = novedades[index];
                      final postId = post['id'] as String;
                      final isExpanded = _expandedPostIds.contains(postId);
                      final comments = List<Map<String, dynamic>>.from(
                        (post['comments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
                      );
                      
                      // Check permissions to delete the post
                      final bool canDeletePost = sessionUser.isAdmin || post['authorId'] == sessionUser.id;

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
                                  JNAvatar(name: post['authorName'] ?? 'Club', size: 36),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(post['authorName'] ?? 'Autor', style: AppTypography.titleSmall),
                                        Text(
                                          '${(post['authorRole'] ?? '').toUpperCase()} · ${post['category'] == 'all' ? 'Global' : post['category']}',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canDeletePost)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                      onPressed: () => _confirmDeletePost(context, postId),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Post Content
                              Text(post['title'] ?? '', style: AppTypography.titleMedium),
                              const SizedBox(height: 6),
                              Text(post['body'] ?? '', style: AppTypography.bodyMedium),
                              if (post['imageUrl'] != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  child: CachedNetworkImage(
                                    imageUrl: post['imageUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 160,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: AppColors.surfaceLight,
                                      highlightColor: AppColors.surface,
                                      child: Container(color: AppColors.surfaceLight, height: 160),
                                    ),
                                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                              const Divider(height: 24, color: AppColors.divider),
                              
                              // Post Footer / Comment Button
                              GestureDetector(
                                onTap: () => _toggleComments(postId),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 18,
                                          color: isExpanded ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          comments.isEmpty
                                              ? 'Comentar'
                                              : '${comments.length} ${comments.length == 1 ? 'comentario' : 'comentarios'}',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: isExpanded ? AppColors.primary : AppColors.textSecondary,
                                            fontWeight: isExpanded ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),

                              // Expanded Comments section
                              if (isExpanded) ...[
                                const SizedBox(height: 12),
                                // Comment Input field
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentControllers[postId],
                                        style: AppTypography.bodyMedium,
                                        decoration: const InputDecoration(
                                          hintText: 'Escribe un comentario...',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.send, color: AppColors.primary, size: 20),
                                      onPressed: () => _submitComment(postId, sessionUser),
                                    ),
                                  ],
                                ),
                                // Comments List
                                if (comments.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: comments.length,
                                    itemBuilder: (context, commentIdx) {
                                      final comment = comments[commentIdx];
                                      final bool canDeleteComment = sessionUser.isAdmin ||
                                          comment['userId'] == sessionUser.id;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            JNAvatar(name: comment['userName'] ?? 'User', size: 24),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceLight,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          '${comment['userName']} (${(comment['userRole'] ?? '').toUpperCase()})',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            color: AppColors.accent,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        if (canDeleteComment)
                                                          GestureDetector(
                                                            onTap: () => _confirmDeleteComment(
                                                              context,
                                                              postId,
                                                              comment,
                                                            ),
                                                            child: const Icon(
                                                              Icons.delete_outline,
                                                              color: AppColors.error,
                                                              size: 14,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(comment['text'] ?? '', style: AppTypography.bodySmall),
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
                    },
                    childCount: novedades.length,
                  ),
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
                    child: Text('Error al cargar novedades: $err', style: TextStyle(color: AppColors.error)),
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
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar Novedad'),
        content: const Text('¿Estás seguro de que quieres eliminar esta publicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).deleteNovedad(postId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Publicación eliminada'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context, String postId, Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar Comentario'),
        content: const Text('¿Estás seguro de que deseas eliminar este comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).deleteCommentFromNovedad(postId, comment);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comentario eliminado'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _submitComment(String postId, dynamic sessionUser) async {
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

    await ref.read(firestoreServiceProvider).addCommentToNovedad(postId, commentData);
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final day = int.parse(parts[2]);
    final month = int.parse(parts[1]);
    return '$day ${months[month]}';
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k'.replaceAll('.', '.');
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
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
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
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
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
              Text(value, style: AppTypography.headlineMedium.copyWith(color: color)),
              Text(label.toUpperCase(), style: AppTypography.statLabel),
            ],
          ),
        ],
      ),
    );
  }
}
