import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../store/presentation/screens/admin_order_detail_screen.dart';
import '../screens/admin_user_profile_screen.dart';

void showAdminNotificationsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Notificaciones'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No hay notificaciones.'));
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isRead = data['read'] ?? false;
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
                        Navigator.pop(context); // close notifications dialog
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
                        docs[index].reference.update({'read': true});
                        // Can also navigate to player profile if we had playerId in notification
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
                        docs[index].reference.delete();
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
                      'Notificación',
                      style: context.typography.bodyMedium.copyWith(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(data['body'] ?? data['title'] ?? data['message'] ?? 'Tienes una nueva notificación.'),
                    onTap: () {
                      docs[index].reference.update({'read': true});
                    },
                  );
                },
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
    },
  );
}