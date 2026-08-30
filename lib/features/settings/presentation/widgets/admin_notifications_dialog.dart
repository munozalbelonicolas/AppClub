import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/navigation_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../communications/presentation/screens/communications_screen.dart';
import '../../../inbox/presentation/screens/chat_screen.dart';
import '../../../inbox/presentation/screens/inbox_screen.dart';
import '../../../store/presentation/screens/admin_order_detail_screen.dart';
import '../screens/admin_user_profile_screen.dart';

void showAdminNotificationsDialog(BuildContext context, {dynamic sessionUser}) {
  showDialog(
    context: context,
    builder: (context) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: const Text('Notificaciones'),
              content: Text(
                'No se pudieron cargar las notificaciones.',
                textAlign: TextAlign.center,
                style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              content: const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          // Sort and filter docs
          final allDocs = snapshot.data!.docs.toList();
          allDocs.sort((a, b) {
            final timeA = (a.data() as Map<String, dynamic>)['createdAt'];
            final timeB = (b.data() as Map<String, dynamic>)['createdAt'];
            if (timeA is Timestamp && timeB is Timestamp) {
              return timeB.compareTo(timeA);
            }
            return 0;
          });

          final docs = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (sessionUser == null) return false;
            if (sessionUser.isAdmin == true) return true;

            final targetUserId = data['targetUserId']?.toString();
            final targetUserIds = data['targetUserIds'] as List<dynamic>?;
            final targetCat = data['targetCategory']?.toString();
            final targetRole = data['targetRole']?.toString();

            if (targetUserIds != null && targetUserIds.isNotEmpty) {
              return targetUserIds.map((e) => e.toString()).contains(sessionUser.id);
            }
            if (targetUserId != null && targetUserId.isNotEmpty && targetUserId != 'all') {
              return targetUserId == sessionUser.id;
            }
            if (targetRole != null && targetRole.isNotEmpty && targetRole != 'all') {
              return targetRole == sessionUser.role;
            }
            if (targetCat != null && targetCat.isNotEmpty && targetCat != 'all' && targetCat != 'todos') {
              if (sessionUser.category != null &&
                  targetCat.toLowerCase().trim() == sessionUser.category!.toLowerCase().trim()) {
                return true;
              }
              if (sessionUser.assignedCategories != null) {
                return (sessionUser.assignedCategories as List)
                    .any((c) => c.toString().toLowerCase().trim() == targetCat.toLowerCase().trim());
              }
              return false;
            }
            return targetCat == 'all' || targetCat == 'todos' || targetUserId == 'all';
          }).take(30).toList();

          void markNotificationAsRead(DocumentReference docRef) {
            try {
              final Map<String, dynamic> updates = {};
              if (sessionUser != null && sessionUser.id != null && (sessionUser.id as String).isNotEmpty) {
                updates['readBy'] = FieldValue.arrayUnion([sessionUser.id]);
              } else {
                updates['read'] = true;
              }
              docRef.set(updates, SetOptions(merge: true));
            } catch (_) {}
          }

          void markAllAsRead() {
            try {
              final batch = FirebaseFirestore.instance.batch();
              for (final d in docs) {
                final Map<String, dynamic> updates = {};
                if (sessionUser != null && sessionUser.id != null && (sessionUser.id as String).isNotEmpty) {
                  updates['readBy'] = FieldValue.arrayUnion([sessionUser.id]);
                } else {
                  updates['read'] = true;
                }
                batch.set(d.reference, updates, SetOptions(merge: true));
              }
              batch.commit();
            } catch (_) {}
          }

          final unreadCount = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final isRead = (sessionUser != null &&
                    sessionUser.id != null &&
                    data['readBy'] is List &&
                    (data['readBy'] as List).contains(sessionUser.id)) ||
                (data['targetUserId'] == sessionUser?.id && data['read'] == true) ||
                (sessionUser == null && data['read'] == true);
            return !isRead;
          }).length;

          return AlertDialog(
            backgroundColor: context.colors.surface,
            title: Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: context.colors.primary, size: 22),
                const SizedBox(width: 8),
                const Text('Notificaciones'),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 340,
              child: docs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 48, color: context.colors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            'No tienes notificaciones pendientes',
                            textAlign: TextAlign.center,
                            style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isRead = (sessionUser != null &&
                                sessionUser.id != null &&
                                data['readBy'] is List &&
                                (data['readBy'] as List).contains(sessionUser.id)) ||
                            (data['targetUserId'] == sessionUser?.id && data['read'] == true) ||
                            (sessionUser == null && data['read'] == true);
                        final type = data['type'];

                        if (type == 'co_tutor_request') {
                          return ListTile(
                            leading: Icon(
                              Icons.group_add,
                              color: isRead ? context.colors.textTertiary : context.colors.primary,
                            ),
                            title: Text(
                              'Solicitud de Co-Tutor',
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${data['tutorName']} solicita vincularse a ${data['playerName']}.'),
                            onTap: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    backgroundColor: context.colors.surface,
                                    title: const Text('Aprobar Co-Tutor'),
                                    content: Text(
                                      '¿Permitir que ${data['tutorName']} sea co-tutor de ${data['playerName']}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          FirebaseFirestore.instance
                                              .collection('player_tutor_links')
                                              .doc(data['linkId'])
                                              .update({'status': 'rejected'});
                                          docs[index].reference.delete();
                                          Navigator.pop(context);
                                        },
                                        child: Text('Rechazar', style: TextStyle(color: context.colors.error)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: context.colors.success),
                                        onPressed: () async {
                                          final String? linkId = data['linkId'];
                                          final String? tutorId = data['tutorId'];

                                          if (linkId != null) {
                                            await FirebaseFirestore.instance
                                                .collection('player_tutor_links')
                                                .doc(linkId)
                                                .update({'status': 'linked'});
                                          }

                                          if (tutorId != null) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(tutorId)
                                                .update({'status': 'active'});
                                          }

                                          await docs[index].reference.delete();
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: const Text('Aprobar', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        }

                        // Store notifications
                        if (type == 'store_purchase' || type == 'store_receipt_uploaded') {
                          final icon = type == 'store_purchase' ? Icons.shopping_cart : Icons.receipt_long;
                          final title = type == 'store_purchase' ? 'Nueva Compra' : 'Comprobante Recibido';
                          final subtitle = type == 'store_purchase'
                              ? '${data['buyerName']} compró ${data['productName']} (Talle ${data['selectedSize']})'
                              : '${data['buyerName']} subió comprobante de ${data['productName']}';

                          return ListTile(
                            leading: Icon(
                              icon,
                              color: isRead ? context.colors.textTertiary : context.colors.accent,
                            ),
                            title: Text(
                              title,
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(subtitle),
                            onTap: () {
                              docs[index].reference.delete();
                              Navigator.pop(context);
                              final orderId = data['orderId'];
                              if (orderId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminOrderDetailScreen(orderId: orderId),
                                  ),
                                );
                              }
                            },
                          );
                        }

                        // Chat / Mensaje
                        final nestedData = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : null;
                        final effectiveType = nestedData?['type']?.toString() ?? type;
                        final rawTitle = data['title']?.toString() ?? '';
                        final isChatNotif = effectiveType == 'chat' ||
                            data['targetCategory'] == 'private' ||
                            rawTitle.startsWith('💬') ||
                            rawTitle.toLowerCase().contains('mensaje de') ||
                            data['threadId'] != null ||
                            nestedData?['threadId'] != null;

                        if (isChatNotif) {
                          final otherName = nestedData?['otherUserName']?.toString() ??
                              data['otherUserName']?.toString() ??
                              data['senderName']?.toString() ??
                              rawTitle.replaceFirst('💬 Mensaje de ', '').replaceFirst('Mensaje de ', '').trim();
                          final otherRole = nestedData?['otherUserRole']?.toString() ??
                              data['otherUserRole']?.toString() ??
                              data['senderRole']?.toString() ??
                              'usuario';
                          final otherUserId = nestedData?['otherUserId']?.toString() ??
                              data['otherUserId']?.toString() ??
                              data['authorId']?.toString() ??
                              data['senderId']?.toString();
                          final threadId = nestedData?['threadId']?.toString() ?? data['threadId']?.toString();

                          return ListTile(
                            leading: Icon(
                              Icons.chat_bubble_outline,
                              color: isRead ? context.colors.textTertiary : context.colors.primary,
                            ),
                            title: Text(
                              data['title'] ?? 'Mensaje de $otherName',
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(data['body'] ?? data['text'] ?? ''),
                            onTap: () async {
                              markNotificationAsRead(docs[index].reference);
                              Navigator.pop(context);

                              String? targetThreadId = threadId;
                              if ((targetThreadId == null || targetThreadId.isEmpty) &&
                                  otherUserId != null &&
                                  sessionUser != null &&
                                  sessionUser.id != null) {
                                try {
                                  final threadsSnap = await FirebaseFirestore.instance
                                      .collection('inbox_threads')
                                      .where('participants', arrayContains: sessionUser.id)
                                      .get();
                                  for (final tDoc in threadsSnap.docs) {
                                    final pList = (tDoc.data()['participants'] as List?)
                                            ?.map((e) => e.toString())
                                            .toList() ??
                                        [];
                                    if (pList.contains(otherUserId)) {
                                      targetThreadId = tDoc.id;
                                      break;
                                    }
                                  }
                                  targetThreadId ??= 'chat_${sessionUser.id}_$otherUserId';
                                } catch (_) {
                                  targetThreadId = 'chat_${sessionUser.id}_$otherUserId';
                                }
                              }

                              if (targetThreadId != null && targetThreadId.isNotEmpty) {
                                NavigationService.navigateTo(
                                  ChatScreen(
                                    threadId: targetThreadId,
                                    otherUserId: otherUserId,
                                    otherUserName: otherName.isNotEmpty ? otherName : 'Usuario',
                                    otherUserRole: otherRole,
                                  ),
                                );
                              } else {
                                NavigationService.navigateTo(const InboxScreen());
                              }
                            },
                          );
                        }

                        // Comunicado / Novedad
                        if (type == 'announcement' || type == 'novedad' || type == 'novedades') {
                          return ListTile(
                            leading: Icon(
                              Icons.campaign_outlined,
                              color: isRead ? context.colors.textTertiary : context.colors.accent,
                            ),
                            title: Text(
                              data['title'] ?? 'Comunicado',
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(data['body'] ?? ''),
                            onTap: () {
                              markNotificationAsRead(docs[index].reference);
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CommunicationsScreen(),
                                ),
                              );
                            },
                          );
                        }

                        // Convocatoria
                        if (type == 'convocatoria') {
                          return ListTile(
                            leading: Icon(
                              Icons.sports_soccer,
                              color: isRead ? context.colors.textTertiary : const Color(0xFF10B981),
                            ),
                            title: Text(
                              data['title'] ?? 'Convocatoria al Partido',
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(data['body'] ?? 'Tienes una citación pendiente.'),
                            onTap: () {
                              markNotificationAsRead(docs[index].reference);
                              Navigator.pop(context);
                            },
                          );
                        }

                        if (type == 'birthday') {
                          return ListTile(
                            leading: Icon(
                              Icons.cake,
                              color: isRead ? context.colors.textTertiary : context.colors.accent,
                            ),
                            title: Text(
                              data['title'] ?? 'Cumpleaños',
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(data['body'] ?? ''),
                            onTap: () {
                              markNotificationAsRead(docs[index].reference);
                            },
                          );
                        }

                        if (type == 'new_user_pending' || type == 'player_registration') {
                          return ListTile(
                            leading: Icon(
                              Icons.person_add,
                              color: isRead ? context.colors.textTertiary : context.colors.primary,
                            ),
                            title: Text(
                              'Nuevo usuario pendiente',
                              style: context.typography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${data['userName'] ?? 'Alguien'} solicita aprobación.'),
                            onTap: () {
                              try {
                                docs[index].reference.delete();
                              } catch (_) {}
                              Navigator.pop(context);

                              final userId = data['userId'];
                              if (userId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminUserProfileScreen(userId: userId),
                                  ),
                                );
                              }
                            },
                          );
                        }

                        // Fallback genérico para cualquier otro tipo de notificación
                        return ListTile(
                          leading: Icon(
                            Icons.notifications,
                            color: isRead ? context.colors.textTertiary : context.colors.primary,
                          ),
                          title: Text(
                            data['title'] ?? 'Notificación',
                            style: context.typography.bodyMedium.copyWith(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(data['body'] ?? data['title'] ?? data['message'] ?? 'Tienes una nueva notificación.'),
                          onTap: () {
                            markNotificationAsRead(docs[index].reference);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              if (unreadCount > 0)
                TextButton(
                  onPressed: markAllAsRead,
                  child: Text(
                    'Marcar todas como leídas',
                    style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              TextButton(
                onPressed: () {
                  markAllAsRead();
                  Navigator.pop(context);
                },
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    },
  );
}