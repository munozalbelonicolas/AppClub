import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String otherUserName;
  final String otherUserRole;
  /// True when an auditor (admin/directivo/secretario) is viewing a thread
  /// they are NOT a participant of.
  final bool isAuditMode;
  /// Map of participantId -> displayName for audit threads.
  final Map<String, String>? auditParticipantNames;
  /// Map of participantId -> role for audit threads.
  final Map<String, String>? auditParticipantRoles;

  const ChatScreen({
    super.key,
    required this.threadId,
    required this.otherUserName,
    required this.otherUserRole,
    this.isAuditMode = false,
    this.auditParticipantNames,
    this.auditParticipantRoles,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(dynamic currentUser) async {
    // Security guard: auditors can NEVER send messages in threads they don't participate in
    if (widget.isAuditMode) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Add to messages subcollection
      final msgRef = db
          .collection('inbox_threads')
          .doc(widget.threadId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'senderId': currentUser.id,
        'senderName': '${currentUser.name} ${currentUser.lastName}',
        'senderRole': currentUser.role,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update parent thread metadata
      final threadRef = db.collection('inbox_threads').doc(widget.threadId);
      // Determine other user participant
      String otherUserId = '';
      final threadIdParts = widget.threadId.split('_');
      if (threadIdParts.length >= 3 && threadIdParts[0] == 'chat') {
        final id1 = threadIdParts[1];
        final id2 = threadIdParts[2];
        if (id1 == currentUser.id) {
          otherUserId = id2;
        } else if (id2 == currentUser.id) {
          otherUserId = id1;
        }
      }

      if (otherUserId.isEmpty) {
        try {
          final docSnap = await threadRef.get();
          if (docSnap.exists) {
            final parts = docSnap.data()?['participants'] as List<dynamic>? ?? [];
            for (final p in parts) {
              if (p != currentUser.id) {
                otherUserId = p.toString();
                break;
              }
            }
          }
        } catch (_) {}
      }

      batch.set(threadRef, {
        'lastMessageText': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadByAdmin': currentUser.isNormalUser,
        'unreadByUser': !currentUser.isNormalUser,
        if (otherUserId.isNotEmpty) 'unreadBy': [otherUserId],
      }, SetOptions(merge: true));

      await batch.commit();

      if (otherUserId.isNotEmpty && otherUserId != currentUser.id) {
        try {
          NotificationService().sendNotification(
            title: 'Mensaje de ${currentUser.name} ${currentUser.lastName}'.trim(),
            body: text,
            authorId: currentUser.id,
            targetUserId: otherUserId,
            targetCategory: 'private',
          );
        } catch (_) {
          // Notification failure must NOT block message delivery
        }
      }

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
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

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: widget.isAuditMode
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Text(
                        '👁️ MODO AUDITORÍA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Row(
                children: [
                  JNAvatar(name: widget.otherUserName, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherUserName,
                          style: context.typography.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.otherUserRole.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.primary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        elevation: 0,
        backgroundColor:
            widget.isAuditMode ? const Color(0xFF1A1400) : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('inbox_threads')
                  .doc(widget.threadId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar mensajes: ${snapshot.error}',
                      style: TextStyle(color: context.colors.error),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Comienzo de la conversación',
                            style: context.typography.titleMedium.copyWith(
                              color: context.colors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Envía un mensaje privado para contactar.',
                            style: context.typography.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final senderId = data['senderId'] ?? '';
                    final text = data['text'] ?? '';
                    final Timestamp? createdAtTimestamp =
                        data['createdAt'] as Timestamp?;
                    final DateTime createdAt =
                        createdAtTimestamp?.toDate() ?? DateTime.now();

                    final isMe = senderId == currentUser.id;

                    // In audit mode, look up sender name/role from the audit maps
                    String? auditSenderLabel;
                    if (widget.isAuditMode) {
                      final senderName =
                          widget.auditParticipantNames?[senderId] ??
                          (data['senderName'] ?? 'Usuario').toString();
                      final senderRole =
                          widget.auditParticipantRoles?[senderId] ??
                          (data['senderRole'] ?? '').toString();
                      final roleLabel = _roleLabel(senderRole);
                      auditSenderLabel = roleLabel.isNotEmpty
                          ? '$senderName ($roleLabel)'
                          : senderName;
                    }

                    return _buildChatBubble(
                      text,
                      createdAt,
                      isMe,
                      auditSenderLabel: auditSenderLabel,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(currentUser),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
    String text,
    DateTime time,
    bool isMe, {
    String? auditSenderLabel,
  }) {
    final bubbleColor = isMe ? context.colors.primary : context.colors.surfaceLight;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleBorder = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(2),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(16),
          );

    return Column(
      crossAxisAlignment: align,
      children: [
        if (auditSenderLabel != null)
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 12,
              right: isMe ? 12 : 0,
              bottom: 2,
            ),
            child: Text(
              auditSenderLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 4, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: bubbleBorder,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            text,
            style: context.typography.bodyMedium.copyWith(
              color: isMe ? Colors.white : context.colors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            _formatTimestamp(time),
            style: context.typography.labelSmall.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildMessageInput(dynamic currentUser) {
    // In audit mode, hide the input form and show a read-only banner instead
    if (widget.isAuditMode) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1400),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              ),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Text('👁️', style: TextStyle(fontSize: 18)),
              ),
              Expanded(
                child: Text(
                  'Modo Supervisión Institucional: Solo lectura. '
                  'Únicamente los participantes de esta conversación '
                  'pueden interactuar o responder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Normal interactive input for actual participants
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: context.typography.bodyMedium,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje privado...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(currentUser),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: context.colors.primary,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: () => _sendMessage(currentUser),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a human-readable role label for audit sender display.
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

  String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}