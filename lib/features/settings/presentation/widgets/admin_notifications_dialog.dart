import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../store/presentation/screens/admin_order_detail_screen.dart';
import '../screens/admin_user_profile_screen.dart';

void showAdminNotificationsDialog(BuildContext context, {dynamic sessionUser}) {
  showDialog(
    context: context,
    builder: (context) => const _AdminNotificationsDialog(),
  );
}

class _AdminNotificationsDialog extends StatefulWidget {
  const _AdminNotificationsDialog();

  @override
  State<_AdminNotificationsDialog> createState() => _AdminNotificationsDialogState();
}

class _AdminNotificationsDialogState extends State<_AdminNotificationsDialog> {
  int _selectedTab = 0; // 0: No leídas, 1: Todas
  bool _isProcessing = false;

  Future<void> _markAllAsRead() async {
    setState(() => _isProcessing = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay notificaciones sin leer.')),
          );
        }
        return;
      }

      // Batch in chunks of 400 operations
      for (var i = 0; i < query.docs.length; i += 400) {
        final end = (i + 400 < query.docs.length) ? i + 400 : query.docs.length;
        final batch = FirebaseFirestore.instance.batch();
        for (var j = i; j < end; j++) {
          batch.update(query.docs[j].reference, {'read': true});
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${query.docs.length} notificaciones marcadas como leídas.'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al marcar notificaciones: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAllNotifications(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar notificaciones'),
        content: Text(
          '¿Estás seguro de que deseas eliminar las ${docs.length} notificaciones mostradas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar todas', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      for (var i = 0; i < docs.length; i += 400) {
        final end = (i + 400 < docs.length) ? i + 400 : docs.length;
        final batch = FirebaseFirestore.instance.batch();
        for (var j = i; j < end; j++) {
          batch.delete(docs[j].reference);
        }
        await batch.commit();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notificaciones eliminadas.'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return DateFormat('dd/MM HH:mm').format(date);
  }

  void _showNotificationDetail(
    BuildContext context,
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) {
    // Mark as read
    if ((data['read'] ?? false) == false) {
      docRef.update({'read': true}).catchError((_) {});
    }

    final title = data['title']?.toString() ?? 'Notificación';
    final body = data['body']?.toString() ??
        data['message']?.toString() ??
        'Sin contenido adicional.';
    final dateStr = _formatTimestamp(data['createdAt']);
    final authorName = data['authorName']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(title, style: context.typography.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateStr.isNotEmpty)
              Text(
                dateStr,
                style: context.typography.bodySmall.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            if (authorName != null && authorName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'De: $authorName',
                style: context.typography.bodySmall.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(body, style: context.typography.bodyMedium),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.delete_outline, size: 18, color: context.colors.error),
            label: Text('Eliminar', style: TextStyle(color: context.colors.error)),
            onPressed: () {
              docRef.delete();
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return AlertDialog(
      backgroundColor: context.colors.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Row(
        children: [
          const Icon(Icons.notifications_outlined, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (_isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.done_all, size: 22),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: maxHeight,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data!.docs;
            final unreadDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['read'] ?? false) == false;
            }).toList();

            final displayDocs = _selectedTab == 0 ? unreadDocs : allDocs;

            return Column(
              children: [
                // ─── Filter Tabs ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedTab == 0,
                        label: Text('No leídas (${unreadDocs.length})'),
                        onSelected: (_) => setState(() => _selectedTab = 0),
                        selectedColor: context.colors.primary.withValues(alpha: 0.15),
                        checkmarkColor: context.colors.primary,
                        labelStyle: TextStyle(
                          color: _selectedTab == 0 ? context.colors.primary : context.colors.textSecondary,
                          fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _selectedTab == 1,
                        label: Text('Todas (${allDocs.length})'),
                        onSelected: (_) => setState(() => _selectedTab = 1),
                        selectedColor: context.colors.primary.withValues(alpha: 0.15),
                        checkmarkColor: context.colors.primary,
                        labelStyle: TextStyle(
                          color: _selectedTab == 1 ? context.colors.primary : context.colors.textSecondary,
                          fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (displayDocs.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.delete_sweep_outlined, size: 20, color: context.colors.textTertiary),
                          tooltip: 'Eliminar las de esta lista',
                          onPressed: () => _deleteAllNotifications(displayDocs),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ─── List of Notifications ───
                Expanded(
                  child: displayDocs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedTab == 0 ? Icons.done_all : Icons.notifications_off_outlined,
                                  size: 48,
                                  color: context.colors.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedTab == 0
                                      ? '¡Estás al día! No hay notificaciones pendientes.'
                                      : 'No hay notificaciones.',
                                  textAlign: TextAlign.center,
                                  style: context.typography.bodyMedium.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: displayDocs.length,
                          separatorBuilder: (_, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doc = displayDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final isRead = data['read'] ?? false;
                            final type = data['type'];
                            final timeStr = _formatTimestamp(data['createdAt']);

                            // 1. Solicitud de Co-Tutor
                            if (type == 'co_tutor_request') {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRead
                                      ? context.colors.textTertiary.withValues(alpha: 0.1)
                                      : context.colors.primary.withValues(alpha: 0.15),
                                  child: Icon(
                                    Icons.group_add,
                                    color: isRead ? context.colors.textTertiary : context.colors.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Solicitud de Co-Tutor',
                                        style: context.typography.bodyMedium.copyWith(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                      ),
                                  ],
                                ),
                                subtitle: Text('${data['tutorName']} solicita vincularse a ${data['playerName']}.'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Eliminar notificación',
                                  onPressed: () => doc.reference.delete(),
                                ),
                                onTap: () {
                                  // Mark read
                                  doc.reference.update({'read': true}).catchError((_) {});
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (ctx) {
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
                                              doc.reference.delete();
                                              Navigator.pop(ctx);
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

                                              await doc.reference.delete();
                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
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

                            // 2. Compras / Comprobantes Tienda
                            if (type == 'store_purchase' || type == 'store_receipt_uploaded') {
                              final icon = type == 'store_purchase' ? Icons.shopping_cart : Icons.receipt_long;
                              final title = type == 'store_purchase' ? 'Nueva Compra' : 'Comprobante Recibido';
                              final subtitle = type == 'store_purchase'
                                  ? '${data['buyerName']} compró ${data['productName']} (Talle ${data['selectedSize']})'
                                  : '${data['buyerName']} subió comprobante de ${data['productName']}';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRead
                                      ? context.colors.textTertiary.withValues(alpha: 0.1)
                                      : context.colors.accent.withValues(alpha: 0.15),
                                  child: Icon(
                                    icon,
                                    color: isRead ? context.colors.textTertiary : context.colors.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: context.typography.bodyMedium.copyWith(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                      ),
                                  ],
                                ),
                                subtitle: Text(subtitle),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Eliminar notificación',
                                  onPressed: () => doc.reference.delete(),
                                ),
                                onTap: () {
                                  doc.reference.update({'read': true}).catchError((_) {});
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

                            // 3. Nuevos usuarios / registros pendientes
                            if (type == 'new_user_pending' || type == 'player_registration') {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRead
                                      ? context.colors.textTertiary.withValues(alpha: 0.1)
                                      : context.colors.primary.withValues(alpha: 0.15),
                                  child: Icon(
                                    Icons.person_add,
                                    color: isRead ? context.colors.textTertiary : context.colors.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Nuevo usuario pendiente',
                                        style: context.typography.bodyMedium.copyWith(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                      ),
                                  ],
                                ),
                                subtitle: Text('${data['userName'] ?? 'Alguien'} solicita aprobación.'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Eliminar notificación',
                                  onPressed: () => doc.reference.delete(),
                                ),
                                onTap: () {
                                  doc.reference.update({'read': true}).catchError((_) {});
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

                            // 4. Cumpleaños
                            if (type == 'birthday') {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isRead
                                      ? context.colors.textTertiary.withValues(alpha: 0.1)
                                      : context.colors.accent.withValues(alpha: 0.15),
                                  child: Icon(
                                    Icons.cake,
                                    color: isRead ? context.colors.textTertiary : context.colors.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['title'] ?? 'Cumpleaños',
                                        style: context.typography.bodyMedium.copyWith(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                      ),
                                  ],
                                ),
                                subtitle: Text(data['body'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Eliminar notificación',
                                  onPressed: () => doc.reference.delete(),
                                ),
                                onTap: () => _showNotificationDetail(context, doc.reference, data),
                              );
                            }

                            // 5. Fallback genérico para cualquier otra notificación (comunicados, partidos, informes, etc.)
                            final title = data['title']?.toString() ?? 'Notificación';
                            final subtitle = data['body']?.toString() ??
                                data['message']?.toString() ??
                                'Tienes una nueva notificación.';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isRead
                                    ? context.colors.textTertiary.withValues(alpha: 0.1)
                                    : context.colors.primary.withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.notifications,
                                  color: isRead ? context.colors.textTertiary : context.colors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: context.typography.bodyMedium.copyWith(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Text(
                                      timeStr,
                                      style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Eliminar notificación',
                                onPressed: () => doc.reference.delete(),
                              ),
                              onTap: () => _showNotificationDetail(context, doc.reference, data),
                            );
                          },
                        ),
                ),
              ],
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
    );
  }
}