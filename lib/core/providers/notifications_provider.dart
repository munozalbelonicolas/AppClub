import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_provider.dart';

/// Provider que escucha las notificaciones recientes y calcula el total de no leídas
/// sin re-consultar Firestore en cada renderizado de la pantalla.
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final sessionUser = ref.watch(currentUserProvider);
  if (sessionUser == null || sessionUser.id.isEmpty) {
    return Stream.value(0);
  }

  // Limitamos a las últimas 35 notificaciones para evitar descargar toda la base de datos
  return FirebaseFirestore.instance
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(35)
      .snapshots()
      .map((snapshot) {
        bool isDocRead(Map<String, dynamic> data) {
          if (data['read'] == true) return true;
          if (sessionUser.id.isNotEmpty) {
            final readBy = data['readBy'];
            if (readBy is List && readBy.contains(sessionUser.id)) {
              return true;
            }
          }
          return false;
        }

        return snapshot.docs.where((d) {
          final data = d.data();
          if (isDocRead(data)) return false;

          final type = data['type']?.toString().toLowerCase().trim() ?? '';
          final targetCat = data['targetCategory']?.toString().toLowerCase().trim() ?? '';
          final targetRole = data['targetRole']?.toString().toLowerCase().trim() ?? '';
          final targetUserId = data['targetUserId']?.toString().trim() ?? '';
          final targetUserIds = data['targetUserIds'] as List<dynamic>?;

          // ─── REGLAS PARA ADMINISTRADORES ───
          if (sessionUser.isAdmin) {
            // Exclusión explícita: Convocatorias a partidos
            if (type == 'convocatoria' || type == 'partido') return false;

            // Exclusión explícita: Mensajes privados entre otros usuarios
            if (targetCat == 'private' || type == 'private_chat') {
              return targetUserId == sessionUser.id ||
                  (targetUserIds != null && targetUserIds.map((e) => e.toString()).contains(sessionUser.id));
            }

            // 1. Solicitud de usuarios nuevos para aprobación
            if (type == 'new_user_pending' || type == 'pending_approval') return true;

            // 2. Notas o informes que envíen DTs o familias
            if (type == 'coach_report' || type == 'family_note' || type == 'informe') return true;

            // 3. Mensajes enviados directamente hacia los administradores
            if (targetRole == 'directivo' ||
                targetRole == 'admin' ||
                targetRole == 'secretario' ||
                targetCat == 'admin' ||
                targetCat == 'directivo') {
              return true;
            }
            if (targetUserId == sessionUser.id) return true;
            if (targetUserIds != null && targetUserIds.map((e) => e.toString()).contains(sessionUser.id)) return true;

            // Pedidos de tienda para administradores
            if (type == 'new_order') return true;

            return false;
          }

          // ─── REGLAS PARA USUARIOS GENERALES ───
          if (type == 'new_user_pending' || type == 'coach_report') return false;

          if (targetUserIds != null && targetUserIds.isNotEmpty) {
            return targetUserIds.map((e) => e.toString()).contains(sessionUser.id);
          }
          if (targetUserId.isNotEmpty && targetUserId != 'all' && targetUserId != 'todos') {
            return targetUserId == sessionUser.id;
          }
          if (targetRole.isNotEmpty && targetRole != 'all' && targetRole != 'todos') {
            return targetRole == sessionUser.role;
          }
          if (targetCat.isNotEmpty && targetCat != 'all' && targetCat != 'todos') {
            if (sessionUser.category != null &&
                targetCat == sessionUser.category!.toLowerCase().trim()) {
              return true;
            }
            if (sessionUser.assignedCategories != null) {
              return sessionUser.assignedCategories!
                  .any((c) => c.toLowerCase().trim() == targetCat);
            }
            return false;
          }
          return targetCat == 'all' || targetCat == 'todos' || targetUserId == 'all';
        }).length;
      });
});

/// Provider que escucha los hilos de mensajes no leídos del usuario
/// de forma cacheada por Riverpod.
final unreadMessagesCountProvider = StreamProvider<int>((ref) {
  final sessionUser = ref.watch(currentUserProvider);
  if (sessionUser == null || sessionUser.id.isEmpty) {
    return Stream.value(0);
  }

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
        final assignedCats = sessionUser.assignedCategories
                ?.map((c) => c.toLowerCase())
                .toList() ??
            [];
        if (assignedCats.isEmpty && sessionUser.category != null) {
          assignedCats.add(sessionUser.category!.toLowerCase());
        }
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
});
