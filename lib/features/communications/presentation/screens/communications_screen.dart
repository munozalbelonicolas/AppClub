import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/user_session.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../data/repositories/announcement_repository.dart';
import 'story_export_screen.dart';

class CommunicationsScreen extends ConsumerStatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  ConsumerState<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends ConsumerState<CommunicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _expandedAnnIds = {};
  final Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleComments(String annId) {
    setState(() {
      if (_expandedAnnIds.contains(annId)) {
        _expandedAnnIds.remove(annId);
      } else {
        _expandedAnnIds.add(annId);
        _commentControllers.putIfAbsent(annId, () => TextEditingController());
      }
    });
  }

  void _showCreateAnnouncementDialog(BuildContext context, dynamic sessionUser, List<Map<String, dynamic>> clubs) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String eventType = 'ninguno';
    bool hasTransport = false;
    String? selectedOpponentId;
    DateTime? eventDate;

    String selectedCategory = 'deportivo';
    String selectedPriority = 'normal';
    bool commentsEnabled = true;
    final bool isDT = sessionUser.role == 'dt';
    if (isDT && sessionUser.category != null) {
      selectedCategory = sessionUser.category!;
    }
    
    String? selectedEventCategory;
    if (isDT) {
      if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
        selectedEventCategory = sessionUser.assignedCategories!.first;
      } else {
        selectedEventCategory = sessionUser.category;
      }
    }

    final appCategories = ref.read(appCategoriesProvider);
    final List<String> categories = ['deportivo', 'administrativo', 'todos', ...appCategories];

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
              title: Text('Nuevo Comunicado', style: context.typography.titleLarge),
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
                        decoration: const InputDecoration(hintText: 'Título del comunicado', labelText: 'Título'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Ingresa un título' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bodyController,
                        maxLines: 4,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(hintText: 'Escribe el mensaje oficial...', labelText: 'Cuerpo'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Ingresa el mensaje' : null,
                      ),
                      const SizedBox(height: 12),
                      if (isDT) ...[
                        Text(
                          'Categoría/Visibilidad: ${sessionUser.category}',
                          style: context.typography.bodyMedium.copyWith(color: context.colors.primary, fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          dropdownColor: context.colors.surface,
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Categoría/Visibilidad'),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat.toUpperCase(), style: context.typography.bodyLarge),
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
                        initialValue: selectedPriority,
                        decoration: const InputDecoration(labelText: 'Prioridad'),
                        items: [
                          DropdownMenuItem<String>(value: 'normal', child: Text('Normal', style: context.typography.bodyLarge)),
                          DropdownMenuItem<String>(value: 'high', child: Text('Alta (IMPORTANTE)', style: context.typography.bodyLarge)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedPriority = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Habilitar comentarios'),
                        value: commentsEnabled,
                        activeTrackColor: context.colors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() {
                            commentsEnabled = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        dropdownColor: context.colors.surface,
                        initialValue: eventType,
                        decoration: const InputDecoration(labelText: 'Tipo de Evento'),
                        items: const [
                          DropdownMenuItem(value: 'ninguno', child: Text('Ninguno (Comunicado normal)')),
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
                        DropdownButtonFormField<String>(
                          dropdownColor: context.colors.surface,
                          initialValue: selectedEventCategory,
                          decoration: const InputDecoration(labelText: 'Categoría del Evento/Partido'),
                          items: (isDT 
                            ? (sessionUser.assignedCategories ?? (sessionUser.category != null ? [sessionUser.category!] : <String>[])) 
                            : appCategories).map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat.toString().toUpperCase(), style: context.typography.bodyLarge),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedEventCategory = val;
                            });
                          },
                          validator: (val) => val == null ? 'Requerido para eventos' : null,
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
                          items: clubs.map((club) {
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
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: eventDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => eventDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Fecha del Evento (Opcional)'),
                            child: Text(
                              eventDate != null
                                  ? '${eventDate!.day}/${eventDate!.month}/${eventDate!.year}'
                                  : 'Seleccionar fecha',
                              style: context.typography.bodyLarge,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final now = DateTime.now();
                      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                      
                      final announcementRepo = ref.read(announcementRepositoryProvider);
                      await announcementRepo.addAnnouncement({
                        'title': titleController.text.trim(),
                        'body': bodyController.text.trim(),
                        'category': selectedCategory,
                        'eventCategory': selectedEventCategory,
                        'priority': selectedPriority,
                        'date': dateStr,
                        'read': false,
                        'authorId': sessionUser.id,
                        'authorName': '${sessionUser.name} ${sessionUser.lastName}',
                        'authorRole': sessionUser.role,
                        'commentsEnabled': commentsEnabled,
                        'isMatch': eventType == 'partido', // Backwards compatibility
                        'eventType': eventType,
                        'hasTransport': hasTransport,
                        'opponentClubId': (eventType != 'ninguno') ? selectedOpponentId : null,
                        'eventDate': eventDate != null
                            ? '${eventDate!.year}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}'
                            : null,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Comunicado oficial publicado con éxito!'),
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

  void _showSeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Cargar Comunicados de Prueba'),
        content: const Text('Esto cargará un par de comunicados oficiales iniciales en Firestore para probar la sección.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final announcementRepo = ref.read(announcementRepositoryProvider);
              final now = DateTime.now();
              final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              
              await announcementRepo.addAnnouncement({
                'title': 'Cierre de inscripciones para el torneo',
                'body': 'Recordamos a los tutores que este viernes vence el plazo para presentar la ficha médica y completar el registro del torneo anual. No se aceptarán prórrogas.',
                'category': 'administrativo',
                'priority': 'high',
                'date': dateStr,
                'read': false,
                'authorId': 'usr_dir_01',
                'authorName': 'Lorena Gómez',
                'authorRole': 'directivo',
              });

              await announcementRepo.addAnnouncement({
                'title': 'Convocatoria amistoso contra Central',
                'body': 'El sábado jugamos un partido amistoso de preparación contra Rosario Central. La citación es a las 9:00 hs en la puerta del club. Traer indumentaria blanca.',
                'category': 'Sub-12',
                'priority': 'normal',
                'date': dateStr,
                'read': false,
                'authorId': 'usr_dt_01',
                'authorName': 'Pablo Ramírez',
                'authorRole': 'dt',
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Comunicados de prueba cargados!'),
                    backgroundColor: context.colors.success,
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
    final sessionUser = ref.watch(currentUserProvider) ??
        const UserSession(
          id: 'mock',
          name: 'Mock',
          lastName: 'User',
          email: 'mock@mock.com',
          role: 'tutor',
        );
    final isNormalUser = sessionUser.isNormalUser;
    final query = UserAnnouncementQuery(category: sessionUser.category, isAdmin: sessionUser.isAdmin);
    final announcementsAsync = ref.watch(userAnnouncementsStreamProvider(query));
    final clubs = ref.watch(clubsStreamProvider).value ?? [];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Comunicados Oficiales'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.colors.primary,
          labelColor: context.colors.primary,
          unselectedLabelColor: context.colors.textSecondary,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Deportivo'),
            Tab(text: 'Administrativo'),
          ],
        ),
      ),
      floatingActionButton: !isNormalUser
          ? FloatingActionButton(
              onPressed: () => _showCreateAnnouncementDialog(context, sessionUser, clubs),
              backgroundColor: context.colors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack)
          : null,
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.campaign, size: 64, color: context.colors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No hay comunicados oficiales',
                      style: context.typography.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los comunicados importantes y novedades de tu categoría se mostrarán aquí.',
                      style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (!isNormalUser) ...[
                      const SizedBox(height: 24),
                      JNButton(
                        label: 'Cargar Comunicados de Prueba',
                        onPressed: () => _showSeedDialog(context),
                      ),
                    ]
                  ],
                ),
              ),
            );
          }

          final allAnnouncements = announcements;
          final deportivoAnnouncements = announcements.where((a) => a['category'] != 'administrativo' && a['category'] != 'todos').toList();
          final administrativoAnnouncements = announcements.where((a) => a['category'] == 'administrativo' || a['category'] == 'todos').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAnnouncementList(allAnnouncements, sessionUser, clubs),
              _buildAnnouncementList(deportivoAnnouncements, sessionUser, clubs),
              _buildAnnouncementList(administrativoAnnouncements, sessionUser, clubs),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error al cargar comunicados: $err', style: TextStyle(color: context.colors.error)),
        ),
      ),
    );
  }

  Widget _buildAnnouncementList(List<Map<String, dynamic>> announcements, dynamic sessionUser, List<Map<String, dynamic>> clubs) {
    if (announcements.isEmpty) {
      return Center(
        child: Text(
          'No hay comunicados en esta categoría.',
          style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: announcements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ann = announcements[index];
        final annId = ann['id'] as String;
        final isExpanded = _expandedAnnIds.contains(annId);
        
        final seenByList = List<Map<String, dynamic>>.from(
          (ann['seenBy'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        final hasSeen = seenByList.any((e) => e['userId'] == sessionUser.id);

        if (!hasSeen) {
          Future.microtask(() {
            ref.read(announcementRepositoryProvider).markAnnouncementAsSeen(annId, sessionUser);
          });
        }

        final comments = List<Map<String, dynamic>>.from(
          (ann['comments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );

        final bool canDelete = sessionUser.isAdmin || ann['authorId'] == sessionUser.id;
        final bool commentsEnabled = ann['commentsEnabled'] ?? true;

        comments.sort((a, b) {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return aTime.compareTo(bTime);
          }
          return 0;
        });

        final isMatch = ann['isMatch'] == true;
        final opponentClub = isMatch
            ? clubs.where((c) => c['id'] == ann['opponentClubId']).firstOrNull
            : null;
        final localClub = clubs.where((c) => c['isLocal'] == true).firstOrNull;

        return JNCard(
          border: !hasSeen
              ? Border.all(color: context.colors.primary.withValues(alpha: 0.4))
              : null,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasSeen)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ann['title'] as String, style: context.typography.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Publicado por: ${ann['authorName'] ?? 'Club'} · ${(ann['authorRole'] ?? '').toUpperCase()}',
                          style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (canDelete)
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
                          _confirmDeleteAnnouncement(context, annId);
                        } else if (value == 'toggle_comments') {
                          ref
                              .read(announcementRepositoryProvider)
                              .toggleAnnouncementComments(
                                annId,
                                !commentsEnabled,
                              );
                        } else if (value == 'view_views') {
                          _showViewsDialog(context, seenByList);
                        } else if (value == 'export_story') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryExportScreen(announcement: ann),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'export_story',
                          child: Row(
                            children: [
                              Icon(
                                Icons.mobile_screen_share,
                                size: 18,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Exportar para Redes (Historia)',
                                style: context.typography.bodySmall,
                              ),
                            ],
                          ),
                        ),
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
                        PopupMenuItem(
                          value: 'toggle_comments',
                          child: Row(
                            children: [
                              Icon(
                                commentsEnabled
                                    ? Icons.comments_disabled
                                    : Icons.comment,
                                size: 18,
                                color: context.colors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                commentsEnabled
                                    ? 'Deshabilitar comentarios'
                                    : 'Habilitar comentarios',
                                style: context.typography.bodySmall,
                              ),
                            ],
                          ),
                        ),
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
                                'Eliminar',
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
              const SizedBox(height: 8),
              if (ann['eventType'] != null && ann['eventType'] != 'ninguno')
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
                          (ann['eventType'] as String).toUpperCase(),
                          style: context.typography.labelSmall.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (ann['hasTransport'] == true)
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
              Text(
                ann['body'] as String,
                style: context.typography.bodyMedium,
              ),

              if (isMatch && opponentClub != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border, width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildClubLogo(localClub),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textTertiary,
                          ),
                        ),
                      ),
                      _buildClubLogo(opponentClub),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  JNBadge(
                    label: (ann['category'] as String).toUpperCase(),
                    type: ann['category'] == 'deportivo'
                        ? JNBadgeType.accent
                        : ann['category'] == 'administrativo'
                            ? JNBadgeType.info
                            : JNBadgeType.neutral,
                    small: true,
                  ),
                  if (ann['priority'] == 'high') ...[
                    const SizedBox(width: 6),
                    const JNBadge(label: 'IMPORTANTE', type: JNBadgeType.error, small: true),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(ann['date'] as String),
                    style: context.typography.bodySmall,
                  ),
                ],
              ),
              Divider(height: 24, color: context.colors.divider),
              
              GestureDetector(
                onTap: () => _toggleComments(annId),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: isExpanded ? context.colors.primary : context.colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          comments.isEmpty
                              ? 'Comentarios'
                              : '${comments.length} ${comments.length == 1 ? 'comentario' : 'comentarios'}',
                          style: context.typography.bodySmall.copyWith(
                            color: isExpanded ? context.colors.primary : context.colors.textSecondary,
                            fontWeight: isExpanded ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: context.colors.textTertiary,
                    ),
                  ],
                ),
              ),

              if (isExpanded) ...[
                const SizedBox(height: 12),
                if (!commentsEnabled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Los comentarios están desactivados.',
                      style: context.typography.bodySmall.copyWith(
                        color: context.colors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ] else if (sessionUser.role != 'jugador') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentControllers[annId],
                          style: context.typography.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Comentar...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.send, color: context.colors.primary, size: 18),
                        onPressed: () => _submitComment(annId, sessionUser),
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
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            JNAvatar(name: comment['userName'] ?? 'User', size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceLight,
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
                                          style: context.typography.labelSmall.copyWith(
                                            color: context.colors.accent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (canDeleteComment)
                                          GestureDetector(
                                            onTap: () => _confirmDeleteComment(
                                              context,
                                              annId,
                                              comment,
                                            ),
                                            child: Icon(
                                              Icons.delete_outline,
                                              color: context.colors.error,
                                              size: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(comment['text'] ?? '', style: context.typography.bodySmall),
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
        ).animate(delay: (index * 80).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03);
      },
    );
  }

  void _confirmDeleteAnnouncement(BuildContext context, String annId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Comunicado'),
        content: const Text('¿Estás seguro de que deseas eliminar este comunicado oficial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(announcementRepositoryProvider).deleteAnnouncement(annId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Comunicado oficial eliminado'),
                    backgroundColor: context.colors.warning,
                  ),
                );
              }
            },
            child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context, String annId, Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Comentario'),
        content: const Text('¿Estás seguro de que deseas eliminar este comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(announcementRepositoryProvider).deleteCommentFromAnnouncement(annId, comment);
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
            child: Text('Eliminar', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
  }

  void _submitComment(String annId, dynamic sessionUser) async {
    final controller = _commentControllers[annId];
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

    await ref.read(announcementRepositoryProvider).addCommentToAnnouncement(annId, commentData);
  }

  void _showViewsDialog(BuildContext context, List<Map<String, dynamic>> seenByList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Visto por (${seenByList.length})', style: context.typography.titleMedium),
        content: SizedBox(
          width: double.maxFinite,
          child: seenByList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nadie ha visto este comunicado aún.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: seenByList.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final view = seenByList[index];
                    final timestamp = view['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate();
                    final formattedDate = date != null
                        ? '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                        : 'Desconocido';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JNAvatar(name: view['userName'] ?? 'User', size: 36),
                      title: Text(view['userName'] ?? 'Desconocido', style: context.typography.bodyMedium),
                      subtitle: Text(
                        '${(view['userRole'] ?? '').toUpperCase()} • $formattedDate',
                        style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: context.colors.primary)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final day = int.parse(parts[2]);
    final month = int.parse(parts[1]);
    return '$day ${months[month]}';
  }

  Widget _buildClubLogo(Map<String, dynamic>? club) {
    if (club == null) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: context.colors.surface,
        child: Icon(Icons.shield, color: context.colors.textTertiary),
      );
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: context.colors.surface,
          backgroundImage: club['logoUrl'] != null && club['logoUrl'].toString().isNotEmpty
              ? NetworkImage(club['logoUrl'])
              : null,
          child: (club['logoUrl'] == null || club['logoUrl'].toString().isEmpty)
              ? Icon(Icons.shield, color: context.colors.textTertiary)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          club['name'] ?? '',
          style: context.typography.labelSmall,
          overflow: TextOverflow.ellipsis,
        )
      ],
    );
  }
}