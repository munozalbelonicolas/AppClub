import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/providers/session_provider.dart';
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
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _NewChatUserSelector(
          currentUserId: currentUser.id,
          currentUserRole: currentUser.role,
          currentUserCategory: currentUser.category,
          onUserSelected: (selectedUser) async {
            Navigator.pop(context);
            // Create or get thread
            final threadId = await _getOrCreateThread(currentUser, selectedUser);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    threadId: threadId,
                    otherUserName: '${selectedUser['name']} ${selectedUser['lastName']}',
                    otherUserRole: selectedUser['role'],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<String> _getOrCreateThread(dynamic currentUser, Map<String, dynamic> otherUser) async {
    final db = FirebaseFirestore.instance;
    // Thread ID format: lower id first to ensure uniqueness between two users
    final participants = [currentUser.id, otherUser['id']];
    participants.sort();
    final threadId = 'chat_${participants[0]}_${participants[1]}';

    final docRef = db.collection('inbox_threads').doc(threadId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'id': threadId,
        'participants': participants,
        'lastMessageText': 'Conversación iniciada',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadByAdmin': currentUser.isNormalUser,
        'unreadByUser': !currentUser.isNormalUser,
        // Store meta for listing easily
        'user1Id': participants[0],
        'user2Id': participants[1],
        'userNames': {
          currentUser.id: '${currentUser.name} ${currentUser.lastName}',
          otherUser['id']: '${otherUser['name']} ${otherUser['lastName']}',
        },
        'userRoles': {
          currentUser.id: currentUser.role,
          otherUser['id']: otherUser['role'],
        },
        'userCategories': {
          currentUser.id: currentUser.category ?? 'Todos',
          otherUser['id']: otherUser['category'] ?? 'Todos',
        }
      });
    }

    return threadId;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider) ?? SessionMocks.users['padre']!;
    final isStaff = !currentUser.isNormalUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buzón de Entrada (Inbox)'),
        elevation: 0,
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _startNewChatDialog(context, currentUser),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.message, color: Colors.white),
            ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack)
          : null,
      body: Column(
        children: [
          if (isStaff) ...[
            // Search and Category filters for staff
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _searchController,
                style: AppTypography.bodyMedium,
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
                children: ['Todas', 'Sub-12', 'Sub-14', 'Padres', 'DTs'].map((cat) {
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
                      labelStyle: AppTypography.labelSmall.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceLight,
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
                color: AppColors.surfaceLight,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aquí puedes comunicarte en privado con el cuerpo directivo, secretaría o tu director técnico.',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          Expanded(
            child: _buildThreadsStream(currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsStream(dynamic currentUser) {
    final query = FirebaseFirestore.instance.collection('inbox_threads');

    // Filter threads
    Query filteredQuery = query;
    if (currentUser.isNormalUser) {
      // Normal users only see threads they participate in
      filteredQuery = query.where('participants', arrayContains: currentUser.id);
    } else if (currentUser.role == 'dt') {
      // Coaches can see threads of participants in their category
      // For simplicity, we get threads containing the DT or we fetch all and filter in memory
    }

    // NOTE: We do NOT use .orderBy('lastMessageTime') here because
    // combining arrayContains with orderBy requires a Firestore composite index.
    // Instead we sort in-memory after fetching the documents.

    return StreamBuilder<QuerySnapshot>(
      stream: filteredQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error al cargar mensajes: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Sort docs in-memory by lastMessageTime descending
        var docsList = snapshot.data?.docs ?? [];
        docsList.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime); // descending
        });

        // Apply local filtering in memory for Search and Category Filters
        if (!currentUser.isNormalUser) {
          docsList = docsList.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final namesMap = data['userNames'] as Map<String, dynamic>? ?? {};
            final rolesMap = data['userRoles'] as Map<String, dynamic>? ?? {};
            final categoriesMap = data['userCategories'] as Map<String, dynamic>? ?? {};

            // Find the other participant (the normal user)
            String otherUserId = '';
            for (final pId in data['participants'] ?? []) {
              if (pId != currentUser.id) {
                otherUserId = pId;
                break;
              }
            }

            if (otherUserId.isEmpty) return false;

            final otherName = (namesMap[otherUserId] ?? '').toString().toLowerCase();
            final otherRole = (rolesMap[otherUserId] ?? '').toString().toLowerCase();
            final otherCategory = (categoriesMap[otherUserId] ?? '').toString().toLowerCase();

            // Search filter
            if (_searchQuery.isNotEmpty && !otherName.contains(_searchQuery)) {
              return false;
            }

            // Coach restriction: DTs only manage their own category
            if (currentUser.role == 'dt') {
              final dtCategory = (currentUser.category ?? '').toLowerCase();
              if (otherCategory != dtCategory && otherUserId != currentUser.id) {
                return false;
              }
            }

            // Category filters
            if (_selectedCategoryFilter == 'Sub-12' && otherCategory != 'sub-12') return false;
            if (_selectedCategoryFilter == 'Sub-14' && otherCategory != 'sub-14') return false;
            if (_selectedCategoryFilter == 'Padres' && otherRole != 'padre') return false;
            if (_selectedCategoryFilter == 'DTs' && otherRole != 'dt') return false;

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
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.forum_outlined, size: 48, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay conversaciones activas',
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUser.isNormalUser
                        ? 'Si necesitas consultar algo privado con el club, puedes iniciar una conversación presionando en Soporte o esperando a que te escriban.'
                        : 'Utiliza el botón de abajo para iniciar una conversación con un usuario.',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (currentUser.isNormalUser) ...[
                    const SizedBox(height: 24),
                    JNButton(
                      label: 'Escribir a la Secretaría',
                      onPressed: () async {
                        // Start chat with secretary
                        final secUser = {
                          'id': 'usr_sec_01',
                          'name': 'Jorge',
                          'lastName': 'Newbery',
                          'role': 'secretario',
                          'category': 'Todos',
                        };
                        final threadId = await _getOrCreateThread(currentUser, secUser);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                threadId: threadId,
                                otherUserName: 'Secretaría Jorge Newbery',
                                otherUserRole: 'secretario',
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

            // Find the other participant in the chat
            String otherUserId = '';
            for (final pId in data['participants'] ?? []) {
              if (pId != currentUser.id) {
                otherUserId = pId;
                break;
              }
            }

            final namesMap = data['userNames'] as Map<String, dynamic>? ?? {};
            final rolesMap = data['userRoles'] as Map<String, dynamic>? ?? {};
            final categoriesMap = data['userCategories'] as Map<String, dynamic>? ?? {};

            final String otherName = namesMap[otherUserId] ?? 'Usuario';
            final String otherRole = rolesMap[otherUserId] ?? 'padre';
            final String otherCategory = categoriesMap[otherUserId] ?? '';

            final lastMsg = data['lastMessageText'] ?? '';
            final Timestamp? lastTimeTimestamp = data['lastMessageTime'] as Timestamp?;
            final DateTime lastTime = lastTimeTimestamp?.toDate() ?? DateTime.now();

            final bool isUnread = currentUser.isNormalUser
                ? (data['unreadByUser'] ?? false)
                : (data['unreadByAdmin'] ?? false);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JNCard(
                onTap: () {
                  // Mark as read in Firestore
                  FirebaseFirestore.instance
                      .collection('inbox_threads')
                      .doc(threadId)
                      .update(currentUser.isNormalUser
                          ? {'unreadByUser': false}
                          : {'unreadByAdmin': false});

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        threadId: threadId,
                        otherUserName: otherName,
                        otherUserRole: otherRole,
                      ),
                    ),
                  );
                },
                border: isUnread
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2)
                    : null,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    JNAvatar(name: otherName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(otherName, style: AppTypography.titleMedium),
                              const SizedBox(width: 8),
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
                              if (otherCategory.isNotEmpty && otherCategory != 'Todos') ...[
                                const SizedBox(width: 4),
                                JNBadge(label: otherCategory, type: JNBadgeType.neutral, small: true),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMsg,
                            style: AppTypography.bodySmall.copyWith(
                              color: isUnread ? AppColors.textPrimary : AppColors.textTertiary,
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
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
                          style: AppTypography.labelSmall,
                        ),
                        if (isUnread) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.day == time.day && now.month == time.month && now.year == time.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}';
  }
}

class _NewChatUserSelector extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  final String? currentUserCategory;
  final Function(Map<String, dynamic>) onUserSelected;

  const _NewChatUserSelector({
    required this.currentUserId,
    required this.currentUserRole,
    this.currentUserCategory,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nueva Conversación', style: AppTypography.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
                }

                var docs = snapshot.data?.docs ?? [];
                
                // Convert to Maps and filter
                var users = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return <String, dynamic>{
                    'id': doc.id,
                    ...data,
                  };
                }).where((u) {
                  // Don't chat with self
                  if (u['id'] == currentUserId) return false;

                  // Coaches (DT) can only message users of their category
                  if (currentUserRole == 'dt') {
                    return u['category'] == currentUserCategory;
                  }

                  return true;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay usuarios disponibles para mensajería.',
                      style: AppTypography.bodySmall,
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final String name = '${user['name']} ${user['lastName']}';
                    final String role = user['role'] ?? 'padre';
                    final String category = user['category'] ?? '';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: JNAvatar(name: name, size: 38),
                      title: Text(name, style: AppTypography.titleMedium),
                      subtitle: Row(
                        children: [
                          Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.accent)),
                          if (category.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('·', style: AppTypography.bodySmall),
                            const SizedBox(width: 6),
                            Text(category, style: AppTypography.bodySmall),
                          ],
                        ],
                      ),
                      onTap: () => onUserSelected(user),
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
