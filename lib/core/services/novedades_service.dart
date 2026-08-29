import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_logger.dart';
import 'notification_service.dart';

/// Service for feed/novedades operations (SRP: handles only news feed domain)
class NovedadesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getAllNovedades() {
    return _db.collection('novedades').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortNovedades(list);
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getNovedadesForUser(
    List<String>? userCategories,
  ) {
    return _db.collection('novedades').snapshots().map((snapshot) {
      final userCats = (userCategories ?? [])
          .map((c) => c.toString().trim().toLowerCase())
          .where((c) => c.isNotEmpty)
          .toSet();

      final list = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((doc) {
        final rawCat =
            (doc['category'] ?? 'all').toString().trim().toLowerCase();

        final bool isGlobal = rawCat.isEmpty ||
            rawCat == 'all' ||
            rawCat == 'todos' ||
            rawCat == 'general' ||
            rawCat == 'club' ||
            rawCat == 'sin categoría' ||
            rawCat == 'sin categoria';

        if (isGlobal) return true;
        if (userCats.isEmpty) return true;
        return userCats.contains(rawCat);
      }).toList();

      _sortNovedades(list);
      return list;
    });
  }

  void _sortNovedades(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      DateTime? timeA;
      DateTime? timeB;

      final rawA = a['createdAt'] ?? a['date'] ?? a['postedAt'];
      final rawB = b['createdAt'] ?? b['date'] ?? b['postedAt'];

      if (rawA is Timestamp) {
        timeA = rawA.toDate();
      } else if (rawA is DateTime) {
        timeA = rawA;
      } else if (rawA is String) {
        timeA = DateTime.tryParse(rawA);
      }

      if (rawB is Timestamp) {
        timeB = rawB.toDate();
      } else if (rawB is DateTime) {
        timeB = rawB;
      } else if (rawB is String) {
        timeB = DateTime.tryParse(rawB);
      }

      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA); // Newest first
    });
  }

  Future<void> addNovedad(Map<String, dynamic> novedadData) async {
    await _db.collection('novedades').add({
      ...novedadData,
      'createdAt': FieldValue.serverTimestamp(),
      'comments': [],
    });

    // Enviar notificación Push (FCM / OneSignal / In-app)
    try {
      final rawTitle = (novedadData['title'] ?? '').toString().trim();
      final rawBody = (novedadData['body'] ?? '').toString().trim();
      final authorId = (novedadData['authorId'] ?? '').toString();
      final rawCategory = (novedadData['category'] ?? '').toString().trim();
      final type = (novedadData['type'] ?? novedadData['eventType'] ?? '').toString().toLowerCase();
      final isMatch = novedadData['isMatch'] == true || type == 'partido';

      String notifTitle;
      String notifBody;

      if (isMatch) {
        final homeTeam = (novedadData['homeTeam'] ?? (novedadData['isHome'] == false ? (novedadData['opponentName'] ?? 'Rival') : 'Jorge Newbery')).toString();
        final awayTeam = (novedadData['awayTeam'] ?? (novedadData['isHome'] == false ? 'Jorge Newbery' : (novedadData['opponentName'] ?? 'Rival'))).toString();
        final catLabel = (rawCategory.isNotEmpty && rawCategory.toLowerCase() != 'all' && rawCategory.toLowerCase() != 'todos')
            ? ' (Cat. $rawCategory)'
            : '';
        notifTitle = '⚽ Partido Amistoso$catLabel';
        final date = (novedadData['date'] ?? novedadData['eventDate'] ?? '').toString();
        final time = (novedadData['time'] ?? novedadData['eventTime'] ?? '').toString();
        final venue = (novedadData['venue'] ?? novedadData['location'] ?? '').toString();

        final details = [
          '$homeTeam vs $awayTeam',
          if (date.isNotEmpty) '📅 $date',
          if (time.isNotEmpty) '⏰ $time',
          if (venue.isNotEmpty) '📍 $venue',
        ].join(' · ');

        notifBody = rawBody.isNotEmpty ? '$details\n$rawBody' : details;
      } else if (type == 'comunicado') {
        notifTitle = rawTitle.isNotEmpty ? '📢 Comunicado: $rawTitle' : '📢 Nuevo Comunicado Oficial';
        notifBody = rawBody.isNotEmpty ? rawBody : 'Se ha publicado un nuevo comunicado oficial del club.';
      } else {
        final catLabel = (rawCategory.isNotEmpty && rawCategory.toLowerCase() != 'all' && rawCategory.toLowerCase() != 'todos')
            ? ' [Cat. $rawCategory]'
            : '';
        notifTitle = rawTitle.isNotEmpty ? '📰$catLabel $rawTitle' : '📰 Nueva Noticia del Club';
        notifBody = rawBody.isNotEmpty ? rawBody : 'Hay una nueva publicación en el club.';
      }

      final targetCategory = (rawCategory.isEmpty ||
              rawCategory.toLowerCase() == 'all' ||
              rawCategory.toLowerCase() == 'todos' ||
              rawCategory.toLowerCase() == 'general')
          ? 'all'
          : rawCategory;

      await NotificationService().sendNotification(
        title: notifTitle,
        body: notifBody.length > 200 ? '${notifBody.substring(0, 197)}...' : notifBody,
        authorId: authorId,
        targetCategory: targetCategory,
      );
    } catch (e) {
      AppLogger.error('Error al disparar notificación push para novedad', error: e, tag: 'Novedades');
    }
  }

  Future<void> updateNovedad(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('novedades').doc(id).update(data);
  }

  Future<void> deleteNovedad(String id) async {
    await _db.collection('novedades').doc(id).delete();
  }

  Future<void> addCommentToNovedad(
    String novedadId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('novedades').doc(novedadId).update({
      'comments': FieldValue.arrayUnion([commentData]),
    });
  }

  Future<void> deleteCommentFromNovedad(
    String novedadId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('novedades').doc(novedadId).update({
      'comments': FieldValue.arrayRemove([commentData]),
    });
  }

  Future<void> toggleLikeNovedad(String novedadId, String userId) async {
    final docRef = _db.collection('novedades').doc(novedadId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data()!;
    final List<dynamic> likes = data['likes'] ?? [];
    if (likes.contains(userId)) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<void> markNovedadAsSeen(String novedadId, dynamic user) async {
    try {
      if (user == null || (user.id ?? '').toString().isEmpty) return;
      final docRef = _db.collection('novedades').doc(novedadId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data()!;
      final rawSeenBy = data['seenBy'] as List? ?? [];
      final bool alreadySeen = rawSeenBy.any((e) {
        if (e is Map) return e['userId'] == user.id;
        if (e is String) return e == user.id;
        return false;
      });
      if (alreadySeen) return;

      final viewData = {
        'userId': user.id,
        'userName': '${user.name} ${user.lastName}'.trim(),
        'role': user.role ?? '',
        'seenAt': Timestamp.now(),
      };

      await docRef.update({
        'seenBy': FieldValue.arrayUnion([viewData]),
      });
    } catch (e) {
      AppLogger.error('Error al marcar novedad como vista', error: e, tag: 'Novedades');
    }
  }
}
