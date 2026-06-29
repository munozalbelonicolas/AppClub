import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/providers/session_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String otherUserName;
  final String otherUserRole;

  const ChatScreen({
    super.key,
    required this.threadId,
    required this.otherUserName,
    required this.otherUserRole,
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
      batch.update(threadRef, {
        'lastMessageText': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadByAdmin': currentUser.isNormalUser,
        'unreadByUser': !currentUser.isNormalUser,
      });

      await batch.commit();

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
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            JNAvatar(name: widget.otherUserName, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: AppTypography.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.otherUserRole.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary.withValues(alpha: 0.8),
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
                      style: const TextStyle(color: AppColors.error),
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
                          const Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Comienzo de la conversación',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Envía un mensaje privado para contactar.',
                            style: AppTypography.bodySmall,
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

                    return _buildChatBubble(text, createdAt, isMe);
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

  Widget _buildChatBubble(String text, DateTime time, bool isMe) {
    final bubbleColor = isMe ? AppColors.primary : AppColors.surfaceLight;
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
            style: AppTypography.bodyMedium.copyWith(
              color: isMe ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            _formatTimestamp(time),
            style: AppTypography.labelSmall.copyWith(fontSize: 9),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildMessageInput(dynamic currentUser) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: AppTypography.bodyMedium,
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
            backgroundColor: AppColors.primary,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(currentUser),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
