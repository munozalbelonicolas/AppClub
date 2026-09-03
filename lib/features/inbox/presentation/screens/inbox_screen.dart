import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_empty_state.dart';
import '../../../../core/widgets/jn_skeleton_card.dart';
import 'chat_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryFilter = 'Todas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startNewChatDialog(BuildContext context, dynamic currentUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: _NewChatUserSelector(
            currentUserId: currentUser.id,
            currentUserRole: currentUser.role,
            currentUserCategory: currentUser.category,
            currentUserAssignedCategories: currentUser.assignedCategories,
            onUserSelected: (selectedUser, {String? tutorChildrenInfo}) async {
              Navigator.pop(modalContext);
              try {
                final threadId = await _getOrCreateThread(
                  currentUser,
                  selectedUser,
                  tutorChildrenInfo: tutorChildrenInfo,
                );
                if (mounted) {
                  final otherName =
                      '${selectedUser['name'] ?? ''} ${selectedUser['lastName'] ?? ''}'.trim();
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        threadId: threadId,
                        otherUserId: selectedUser['id']?.toString(),
                        otherUserName: otherName.isNotEmpty ? otherName : 'Usuario',
                        otherUserRole: selectedUser['role'] ?? 'tutor',
                        otherUserSubtitle: tutorChildrenInfo != null && tutorChildrenInfo.isNotEmpty
                            ? 'A cargo de: $tutorChildrenInfo'
                            : null,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Error al abrir conversación: $e'),
                      backgroundColor: Theme.of(this.context).colorScheme.error,
                    ),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Future<String> _getOrCreateThread(
    dynamic currentUser,
    Map<String, dynamic> otherUser, {
    String? tutorChildrenInfo,
  }) async {
    final db = FirebaseFirestore.instance;
    // Thread ID format: lower id first to ensure uniqueness between two users
    final participants = [currentUser.id, otherUser['id']];
    participants.sort();
    final threadId = 'chat_${participants[0]}_${participants[1]}';

    final docRef = db.collection('inbox_threads').doc(threadId);
    final docSnap = await docRef.get();

    final updateData = <String, dynamic>{
      'id': threadId,
      'participants': participants,
      if (!docSnap.exists) 'lastMessageText': 'Conversación iniciada',
      if (!docSnap.exists) 'lastMessageTime': FieldValue.serverTimestamp(),
      if (!docSnap.exists) 'unreadByAdmin': currentUser.isNormalUser,
      if (!docSnap.exists) 'unreadByUser': !currentUser.isNormalUser,
      'user1Id': participants[0],
      'user2Id': participants[1],
      'userNames': {
        currentUser.id: '${currentUser.name} ${currentUser.lastName}'.trim(),
        if (otherUser['name'] != null)
          otherUser['id']:
              '${otherUser['name'] ?? ''} ${otherUser['lastName'] ?? ''}'
                  .trim(),
      },
      'userRoles': {
        currentUser.id: currentUser.role,
        if (otherUser['role'] != null) otherUser['id']: otherUser['role'],
      },
      'userCategories': {
        currentUser.id: currentUser.category ?? 'Todos',
        if (otherUser['category'] != null) otherUser['id']: otherUser['category'],
      },
      if (tutorChildrenInfo != null && tutorChildrenInfo.isNotEmpty)
        'tutorChildren': {
          otherUser['id']: tutorChildrenInfo,
        },
    };

    await docRef.set(updateData, SetOptions(merge: true));

    return threadId;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isStaff = currentUser.isAdmin || currentUser.isCoach;
    final categories = ref.watch(appCategoriesProvider);
    final filterOptions = ['Todas', ...categories, 'Tutores', 'DTs'];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Buzón de Entrada (Inbox)'),
        elevation: 0,
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _startNewChatDialog(context, currentUser),
              backgroundColor: context.colors.primary,
              child: const Icon(Icons.message, color: Colors.white),
            ).animate().scale(
              delay: 200.ms,
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
          : null,
      body: Column(
        children: [
          if (isStaff) ...[
            // Search and Category filters for staff
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _searchController,
                style: context.typography.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o apellido...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: filterOptions.map((
                  cat,
                ) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategoryFilter = cat;
                          });
                        }
                      },
                      labelStyle: context.typography.labelSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : context.colors.textSecondary,
                      ),
                      selectedColor: context.colors.primary,
                      backgroundColor: context.colors.surfaceLight,
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            // For parents: quick header explaining the inbox
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: JNCard(
                padding: const EdgeInsets.all(14),
                color: context.colors.surfaceLight,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.colors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aquí puedes comunicarte en privado con el cuerpo directivo, secretaría o tu director técnico.',
                        style: context.typography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          Expanded(child: _buildThreadsStream(currentUser)),
        ],
      ),
    );
  }

  /// Determines if the current user is a privileged auditor who can see ALL threads.
  bool _isAuditor(dynamic currentUser) {
    final role = currentUser.role as String? ?? '';
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'directivo' ||
        role == 'secretario';
  }

  Widget _buildThreadsStream(dynamic currentUser) {
    final query = FirebaseFirestore.instance.collection('inbox_threads');

    // Auditors (admin/directivo/secretario) see ALL threads for institutional oversight.
    // DTs, coaches and normal users only see their own threads.
    Query filteredQuery;
    if (_isAuditor(currentUser)) {
      filteredQuery = query; // all threads – sorted in-memory below
    } else {
      // Normal users, DTs, coaches, tutors, socios, jugadores – only own threads
      filteredQuery = query.where(
        'participants',
        arrayContains: currentUser.id,
      );
    }

    // NOTE: We do NOT use .orderBy('lastMessageTime') here because
    // combining arrayContains with orderBy requires a Firestore composite index.
    // Instead we sort in-memory after fetching the documents.

    return StreamBuilder<QuerySnapshot>(
      stream: filteredQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 5,
            itemBuilder: (context, index) => const JNSkeletonCard(height: 90),
          );
        }
        if (snapshot.hasError) {
          return const JNEmptyState(
            icon: Icons.error_outline,
            title: 'Error de carga',
            message: 'Ocurrió un problema al cargar los mensajes.',
          );
        }

        // Sort docs in-memory by lastMessageTime descending
        var docsList = snapshot.data?.docs ?? [];
        if (docsList.isEmpty) {
          return const JNEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'Sin mensajes',
            message: 'Aún no tienes conversaciones. ¡Inicia un chat nuevo!',
          );
        }

        docsList.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime =
              (aData['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          final bTime =
              (bData['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          return bTime.compareTo(aTime); // descending
        });

        // Apply local filtering in memory for Search and Category Filters
        if (!currentUser.isNormalUser) {
          docsList = docsList.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final namesMap = data['userNames'] as Map<String, dynamic>? ?? {};
            final rolesMap = data['userRoles'] as Map<String, dynamic>? ?? {};
            final categoriesMap =
                data['userCategories'] as Map<String, dynamic>? ?? {};
            final participants = (data['participants'] as List?)?.cast<String>() ?? [];
            final isAuditThread = _isAuditor(currentUser) && !participants.contains(currentUser.id);

            if (isAuditThread) {
              // For audit threads (admin sees foreign chats), search against all participant names
              if (_searchQuery.isNotEmpty) {
                final allNames = namesMap.values.map((v) => v.toString().toLowerCase()).join(' ');
                if (!allNames.contains(_searchQuery)) return false;
              }
              // Category filters: apply against any participant's category
              if (_selectedCategoryFilter != 'Todas') {
                final allCategories = categoriesMap.values.map((v) => v.toString().toLowerCase());
                final allRoles = rolesMap.values.map((v) => v.toString().toLowerCase());
                if (_selectedCategoryFilter == 'Tutores') {
                  if (!allRoles.contains('tutor')) return false;
                } else if (_selectedCategoryFilter == 'DTs') {
                  if (!allRoles.contains('dt')) return false;
                } else {
                  if (!allCategories.contains(_selectedCategoryFilter.toLowerCase())) return false;
                }
              }
              return true;
            }

            // Find the other participant (the normal user)
            String otherUserId = '';
            for (final pId in participants) {
              if (pId != currentUser.id) {
                otherUserId = pId;
                break;
              }
            }

            if (otherUserId.isEmpty) return false;

            final otherName = (namesMap[otherUserId] ?? '')
                .toString()
                .toLowerCase();
            final otherRole = (rolesMap[otherUserId] ?? '')
                .toString()
                .toLowerCase();
            final otherCategory = (categoriesMap[otherUserId] ?? '')
                .toString()
                .toLowerCase();

            // Search filter
            if (_searchQuery.isNotEmpty && !otherName.contains(_searchQuery)) {
              return false;
            }

            // Coach restriction: DTs only manage their own category
            if (currentUser.role == 'dt') {
              final dtCategory = (currentUser.category ?? '').toLowerCase();
              final isParticipant = participants.contains(currentUser.id);
              if (otherCategory != dtCategory && !isParticipant) {
                return false;
              }
            }

            // Category filters
            if (_selectedCategoryFilter != 'Todas' && 
                _selectedCategoryFilter != 'Tutores' && 
                _selectedCategoryFilter != 'DTs') {
              if (otherCategory != _selectedCategoryFilter.toLowerCase()) {
                return false;
              }
            }
            if (_selectedCategoryFilter == 'Tutores' && otherRole != 'tutor') {
              return false;
            }
            if (_selectedCategoryFilter == 'DTs' && otherRole != 'dt') {
              return false;
            }

            return true;
          }).toList();
        }

        if (docsList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.forum_outlined,
                      size: 48,
                      color: context.colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay conversaciones activas',
                    style: context.typography.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUser.isNormalUser
                        ? 'Si necesitas consultar algo privado con el club, puedes iniciar una conversación presionando en Soporte o esperando a que te escriban.'
                        : 'Utiliza el botón de abajo para iniciar una conversación con un usuario.',
                    style: context.typography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (currentUser.isNormalUser) ...[
                    const SizedBox(height: 24),
                      JNButton(
                        label: 'Escribir a la Secretaría',
                        onPressed: () async {
                          // Find actual secretary/admin user in Firestore
                          final secSnap = await FirebaseFirestore.instance
                              .collection('users')
                              .where('role', whereIn: ['secretario', 'directivo'])
                              .limit(1)
                              .get();

                          Map<String, dynamic> secUser;
                          if (secSnap.docs.isNotEmpty) {
                            final doc = secSnap.docs.first;
                            secUser = {'id': doc.id, ...doc.data()};
                          } else {
                            secUser = {
                              'id': 'admin_general',
                              'name': 'Secretaría',
                              'lastName': 'Club',
                              'role': 'secretario',
                              'category': 'Todos',
                            };
                          }

                          final threadId = await _getOrCreateThread(
                            currentUser,
                            secUser,
                          );
                          if (context.mounted) {
                            final secName = secUser['name'] != null
                                ? '${secUser['name']} ${secUser['lastName'] ?? ''}'.trim()
                                : 'Secretaría Club';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  threadId: threadId,
                                  otherUserId: secUser['id']?.toString(),
                                  otherUserName: secName,
                                  otherUserRole: secUser['role'] ?? 'secretario',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: docsList.length,
          itemBuilder: (context, index) {
            final doc = docsList[index];
            final data = doc.data() as Map<String, dynamic>;
            final threadId = doc.id;

            final participants = (data['participants'] as List?)?.cast<String>() ?? [];
            final namesMap = data['userNames'] as Map<String, dynamic>? ?? {};
            final rolesMap = data['userRoles'] as Map<String, dynamic>? ?? {};
            final categoriesMap =
                data['userCategories'] as Map<String, dynamic>? ?? {};
            final tutorChildrenMap =
                data['tutorChildren'] as Map<String, dynamic>? ?? {};

            // Detect audit mode: admin is viewing a thread they are NOT part of
            final isAuditMode =
                _isAuditor(currentUser) && !participants.contains(currentUser.id);

            // Build display title and role
            String displayTitle;
            String displayRole;
            String avatarName;
            String otherRole;
            String otherCategory;
            String otherTutorChildren = '';

            String otherUserId = '';
            if (isAuditMode) {
              // Show both participants in audit format: "Nombre1 (Rol1) ↔ Nombre2 (Rol2)"
              final entries = participants.map((pid) {
                final name = (namesMap[pid] ?? 'Usuario').toString();
                final role = _roleLabel((rolesMap[pid] ?? '').toString());
                return '$name ($role)';
              }).toList();
              displayTitle = entries.join(' ↔ ');
              displayRole = 'supervisión';
              avatarName = entries.isNotEmpty ? entries.first : '??';
              otherRole = 'supervisión';
              otherCategory = '';
            } else {
              // Normal view: show the other participant
              for (final pId in participants) {
                if (pId != currentUser.id) {
                  otherUserId = pId;
                  break;
                }
              }
              displayTitle = namesMap[otherUserId] ?? 'Usuario';
              otherRole = (rolesMap[otherUserId] ?? 'tutor').toString();
              displayRole = otherRole;
              avatarName = displayTitle;
              otherCategory = (categoriesMap[otherUserId] ?? '').toString();
              otherTutorChildren = tutorChildrenMap[otherUserId]?.toString() ?? '';
            }

            final lastMsg = data['lastMessageText'] ?? '';
            final Timestamp? lastTimeTimestamp =
                data['lastMessageTime'] as Timestamp?;
            final DateTime lastTime =
                lastTimeTimestamp?.toDate() ?? DateTime.now();

            bool isUnread = (data['unreadBy'] as List?)?.contains(currentUser.id) ?? false;
            if (!isUnread) {
              isUnread = currentUser.isNormalUser
                  ? (data['unreadByUser'] == true)
                  : (data['unreadByAdmin'] == true);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JNCard(
                onTap: () {
                  // Mark as read in Firestore only if admin is a participant
                  if (!isAuditMode) {
                    FirebaseFirestore.instance
                        .collection('inbox_threads')
                        .doc(threadId)
                        .update({
                          if (currentUser.isNormalUser) 'unreadByUser': false else 'unreadByAdmin': false,
                          'unreadBy': FieldValue.arrayRemove([currentUser.id]),
                        });
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        threadId: threadId,
                        otherUserId: !isAuditMode && otherUserId.isNotEmpty ? otherUserId : null,
                        otherUserName: displayTitle,
                        otherUserRole: displayRole,
                        otherUserSubtitle: otherTutorChildren.isNotEmpty
                            ? 'A cargo de: $otherTutorChildren'
                            : null,
                        isAuditMode: isAuditMode,
                        auditParticipantNames: isAuditMode
                            ? Map<String, String>.fromEntries(
                                namesMap.entries.map((e) => MapEntry(e.key, e.value.toString())),
                              )
                            : null,
                        auditParticipantRoles: isAuditMode
                            ? Map<String, String>.fromEntries(
                                rolesMap.entries.map((e) => MapEntry(e.key, e.value.toString())),
                              )
                            : null,
                      ),
                    ),
                  );
                },
                border: isAuditMode
                    ? Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                        width: 1.5,
                      )
                    : isUnread
                    ? Border.all(
                        color: context.colors.primary.withValues(alpha: 0.5),
                        width: 1.2,
                      )
                    : null,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    isAuditMode
                        ? Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2A2000),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('👁️', style: TextStyle(fontSize: 20)),
                            ),
                          )
                        : JNAvatar(name: avatarName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                displayTitle,
                                style: context.typography.titleMedium,
                              ),
                              if (isAuditMode)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700),
                                      width: 0.8,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SUPERVISIÓN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFD700),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                )
                              else ...[
                                JNBadge(
                                  label: otherRole.toUpperCase(),
                                  type: otherRole == 'directivo'
                                      ? JNBadgeType.error
                                      : otherRole == 'secretario'
                                      ? JNBadgeType.info
                                      : otherRole == 'dt'
                                      ? JNBadgeType.accent
                                      : JNBadgeType.neutral,
                                  small: true,
                                ),
                                if (otherTutorChildren.isNotEmpty)
                                  JNBadge(
                                    label: 'A cargo de: $otherTutorChildren',
                                    small: true,
                                  )
                                else if (otherCategory.isNotEmpty &&
                                    otherCategory != 'Todos')
                                  JNBadge(
                                    label: otherCategory,
                                    small: true,
                                  ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMsg,
                            style: context.typography.bodySmall.copyWith(
                              color: isUnread && !isAuditMode
                                  ? context.colors.textPrimary
                                  : context.colors.textTertiary,
                              fontWeight: isUnread && !isAuditMode
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(lastTime),
                          style: context.typography.labelSmall,
                        ),
                        if (isUnread && !isAuditMode) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ).animate(delay: (index * 50).ms).fadeIn().slideX(begin: 0.02);
          },
        );
      },
    );
  }

  /// Returns a human-readable role label for audit display.
  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'ADMIN';
      case 'directivo':
        return 'DIRECTIVO';
      case 'secretario':
        return 'SECRETARIO';
      case 'dt':
      case 'coach':
        return 'DT';
      case 'tutor':
        return 'TUTOR';
      case 'socio':
        return 'SOCIO';
      case 'jugador':
        return 'JUGADOR';
      default:
        return role.toUpperCase();
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.day == time.day &&
        now.month == time.month &&
        now.year == time.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}';
  }
}

typedef OnChatUserSelected = void Function(Map<String, dynamic> user, {String? tutorChildrenInfo});

class _NewChatUserSelector extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  final String? currentUserCategory;
  final List<String>? currentUserAssignedCategories;
  final OnChatUserSelected onUserSelected;

  const _NewChatUserSelector({
    required this.currentUserId,
    required this.currentUserRole,
    this.currentUserCategory,
    this.currentUserAssignedCategories,
    required this.onUserSelected,
  });

  @override
  State<_NewChatUserSelector> createState() => _NewChatUserSelectorState();
}

class _NewChatUserSelectorState extends State<_NewChatUserSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handlePlayerTapped(
    BuildContext context,
    Map<String, dynamic> player,
    List<Map<String, dynamic>> linkedTutors,
  ) {
    final playerName = '${player['name'] ?? ''} ${player['lastName'] ?? ''}'.trim();
    final playerCat = (player['category'] != null && player['category'].toString().isNotEmpty)
        ? 'Cat. ${player['category']}'
        : '';
    final playerSubtitle = playerCat.isNotEmpty ? '$playerName ($playerCat)' : playerName;

    if (linkedTutors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El jugador "$playerName" no tiene tutores vinculados aún.'),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    if (linkedTutors.length == 1) {
      final singleTutor = linkedTutors.first;
      final tutorName = '${singleTutor['name'] ?? ''} ${singleTutor['lastName'] ?? ''}'.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conectando con el tutor: $tutorName...'),
          duration: const Duration(seconds: 1),
        ),
      );
      widget.onUserSelected(
        singleTutor,
        tutorChildrenInfo: playerSubtitle,
      );
      return;
    }

    // Multiple tutors linked (e.g. Padre y Madre) -> Prompt admin to choose
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tutores de $playerName',
                      style: context.typography.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Este jugador tiene ${linkedTutors.length} tutores registrados. ¿Con quién deseas chatear?',
                  style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...linkedTutors.map((tutor) {
                  final tName = '${tutor['name'] ?? ''} ${tutor['lastName'] ?? ''}'.trim();
                  final tPhone = tutor['phone1'] ?? tutor['phone2'] ?? tutor['email'] ?? 'Tutor registrado';
                  return JNCard(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      widget.onUserSelected(
                        tutor,
                        tutorChildrenInfo: playerSubtitle,
                      );
                    },
                    child: Row(
                      children: [
                        JNAvatar(name: tName.isNotEmpty ? tName : 'Tutor', size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tName, style: context.typography.titleMedium),
                              Text(
                                tPhone,
                                style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chat_outlined, color: context.colors.primary),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDT = widget.currentUserRole == 'dt';
    final List<String> roleFilters = isDT
        ? ['Todos', 'Tutores', 'Jugadores', 'Directivos']
        : ['Todos', 'Tutores', 'Jugadores', 'DTs', 'Directivos', 'Secretarios'];

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nueva Conversación', style: context.typography.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Input
          TextField(
            controller: _searchController,
            style: context.typography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, apellido, DNI, categoría o hijo...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 10),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roleFilters.map((filter) {
                final isSelected = _selectedRoleFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedRoleFilter = filter);
                      }
                    },
                    labelStyle: context.typography.labelSmall.copyWith(
                      color: isSelected ? Colors.white : context.colors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    selectedColor: context.colors.primary,
                    backgroundColor: context.colors.surfaceLight,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('player_tutor_links').snapshots(),
              builder: (context, linksSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, usersSnapshot) {
                    if (usersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (usersSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error al cargar usuarios: ${usersSnapshot.error}',
                          style: TextStyle(color: context.colors.error),
                        ),
                      );
                    }

                    final usersDocs = usersSnapshot.data?.docs ?? [];
                    final linksDocs = linksSnapshot.data?.docs ?? [];

                    // Fast map of user ID -> user data
                    final Map<String, Map<String, dynamic>> usersMap = {};
                    for (final doc in usersDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      usersMap[doc.id] = <String, dynamic>{'id': doc.id, ...data};
                    }

                    // Map tutorId -> list of players
                    final Map<String, List<Map<String, dynamic>>> tutorPlayersMap = {};
                    // Map playerId -> list of tutors
                    final Map<String, List<Map<String, dynamic>>> playerTutorsMap = {};

                    for (final lDoc in linksDocs) {
                      final lData = lDoc.data() as Map<String, dynamic>;
                      final tId = lData['tutorId']?.toString();
                      final pId = lData['playerId']?.toString();
                      if (tId != null && pId != null) {
                        final player = usersMap[pId];
                        final tutor = usersMap[tId];
                        if (player != null) {
                          tutorPlayersMap.putIfAbsent(tId, () => []).add(player);
                        }
                        if (tutor != null) {
                          playerTutorsMap.putIfAbsent(pId, () => []).add(tutor);
                        }
                      }
                    }

                    // Filter users by role and permissions
                    final List<Map<String, dynamic>> allAllowedUsers = usersMap.values.where((u) {
                      if (u['id'] == widget.currentUserId) return false;

                      // Coaches (DT) permissions
                      if (widget.currentUserRole == 'dt') {
                        final uRole = (u['role'] ?? '').toString().toLowerCase();
                        final isStaff = uRole == 'secretario' || uRole == 'directivo' || uRole == 'admin';
                        if (isStaff) return true;

                        // If user is a tutor, check if any of their children belong to DT's category
                        if (uRole == 'tutor') {
                          final children = tutorPlayersMap[u['id']] ?? [];
                          return children.any((c) {
                            final cCat = (c['category'] ?? '').toString();
                            return (widget.currentUserAssignedCategories != null && widget.currentUserAssignedCategories!.isNotEmpty)
                                ? widget.currentUserAssignedCategories!.contains(cCat)
                                : cCat == widget.currentUserCategory;
                          });
                        }

                        // If user is a player, check category
                        final uCategory = (u['category'] ?? '').toString();
                        final hasAssignedCategory = (widget.currentUserAssignedCategories != null && widget.currentUserAssignedCategories!.isNotEmpty)
                            ? widget.currentUserAssignedCategories!.contains(uCategory)
                            : uCategory == widget.currentUserCategory;

                        return hasAssignedCategory;
                      }

                      return true;
                    }).toList();

                    // Apply role filter and search query
                    final filteredUsers = allAllowedUsers.where((u) {
                      final uRole = (u['role'] ?? 'tutor').toString().toLowerCase();
                      if (_selectedRoleFilter == 'Tutores' && uRole != 'tutor') return false;
                      if (_selectedRoleFilter == 'Jugadores' && uRole != 'jugador') return false;
                      if (_selectedRoleFilter == 'DTs' && uRole != 'dt' && uRole != 'coach' && uRole != 'profesor') return false;
                      if (_selectedRoleFilter == 'Directivos' && uRole != 'directivo' && uRole != 'admin' && uRole != 'administrator') return false;
                      if (_selectedRoleFilter == 'Secretarios' && uRole != 'secretario') return false;

                      if (_searchQuery.isNotEmpty) {
                        final name = (u['name'] ?? '').toString().toLowerCase();
                        final lastName = (u['lastName'] ?? '').toString().toLowerCase();
                        final fullName = '$name $lastName';
                        final dni = (u['dni'] ?? '').toString().toLowerCase();
                        final category = (u['category'] ?? '').toString().toLowerCase();
                        final role = uRole;

                        bool matches = fullName.contains(_searchQuery) ||
                            name.contains(_searchQuery) ||
                            lastName.contains(_searchQuery) ||
                            dni.contains(_searchQuery) ||
                            category.contains(_searchQuery) ||
                            role.contains(_searchQuery);

                        // If tutor, search also against their children's names and categories
                        if (!matches && uRole == 'tutor') {
                          final children = tutorPlayersMap[u['id']] ?? [];
                          matches = children.any((c) {
                            final cName = (c['name'] ?? '').toString().toLowerCase();
                            final cLastName = (c['lastName'] ?? '').toString().toLowerCase();
                            final cFullName = '$cName $cLastName';
                            final cCat = (c['category'] ?? '').toString().toLowerCase();
                            final cDni = (c['dni'] ?? '').toString().toLowerCase();
                            return cFullName.contains(_searchQuery) ||
                                cName.contains(_searchQuery) ||
                                cLastName.contains(_searchQuery) ||
                                cCat.contains(_searchQuery) ||
                                cDni.contains(_searchQuery);
                          });
                        }

                        // If player, search also against their tutors' names
                        if (!matches && uRole == 'jugador') {
                          final tutors = playerTutorsMap[u['id']] ?? [];
                          matches = tutors.any((t) {
                            final tName = (t['name'] ?? '').toString().toLowerCase();
                            final tLastName = (t['lastName'] ?? '').toString().toLowerCase();
                            return '$tName $tLastName'.contains(_searchQuery);
                          });
                        }

                        if (!matches) return false;
                      }

                      return true;
                    }).toList();

                    // Sort alphabetically
                    filteredUsers.sort((a, b) {
                      final nameA = '${a['lastName'] ?? ''} ${a['name'] ?? ''}'.trim().toLowerCase();
                      final nameB = '${b['lastName'] ?? ''} ${b['name'] ?? ''}'.trim().toLowerCase();
                      return nameA.compareTo(nameB);
                    });

                    if (filteredUsers.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 48,
                                color: context.colors.textTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No se encontraron usuarios para "$_searchQuery"'
                                    : 'No hay usuarios en este filtro.',
                                style: context.typography.bodyMedium.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredUsers.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: context.colors.divider),
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final String name = '${user['name'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                        final String displayName = name.isNotEmpty ? name : (user['email'] ?? 'Usuario');
                        final String role = (user['role'] ?? 'tutor').toString().toLowerCase();
                        final String category = user['category']?.toString() ?? '';

                        // Tutor children info
                        String childrenSummary = '';
                        if (role == 'tutor') {
                          final children = tutorPlayersMap[user['id']] ?? [];
                          childrenSummary = children.map((c) {
                            final cName = '${c['name'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                            final cCat = (c['category'] != null && c['category'].toString().isNotEmpty)
                                ? 'Cat. ${c['category']}'
                                : '';
                            return cCat.isNotEmpty ? '$cName ($cCat)' : cName;
                          }).join(' · ');
                        }

                        // Player tutor info
                        String tutorSummary = '';
                        if (role == 'jugador') {
                          final tutors = playerTutorsMap[user['id']] ?? [];
                          tutorSummary = tutors.map((t) => '${t['name'] ?? ''} ${t['lastName'] ?? ''}'.trim()).join(', ');
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: JNAvatar(name: displayName, size: 40),
                          title: Text(displayName, style: context.typography.titleSmall),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: role == 'directivo' || role == 'admin'
                                          ? context.colors.error.withValues(alpha: 0.15)
                                          : role == 'secretario'
                                              ? context.colors.info.withValues(alpha: 0.15)
                                              : role == 'dt'
                                                  ? context.colors.accent.withValues(alpha: 0.15)
                                                  : context.colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: role == 'directivo' || role == 'admin'
                                            ? context.colors.error
                                            : role == 'secretario'
                                                ? context.colors.info
                                                : role == 'dt'
                                                    ? context.colors.accent
                                                    : context.colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (category.isNotEmpty && category != 'Todos') ...[
                                    const SizedBox(width: 8),
                                    Text('Cat. $category', style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary)),
                                  ],
                                ],
                              ),
                              if (childrenSummary.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'A cargo de: $childrenSummary',
                                  style: context.typography.labelSmall.copyWith(
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (role == 'jugador' && tutorSummary.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Tutor: $tutorSummary',
                                  style: context.typography.labelSmall.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: context.colors.primary,
                          ),
                          onTap: () {
                            if (role == 'jugador') {
                              final linkedTutors = playerTutorsMap[user['id']] ?? [];
                              _handlePlayerTapped(context, user, linkedTutors);
                            } else {
                              widget.onUserSelected(
                                user,
                                tutorChildrenInfo: childrenSummary.isNotEmpty ? childrenSummary : null,
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}