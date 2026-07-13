import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for feed/novedades operations (SRP: handles only news feed domain)
class NovedadesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getAllNovedades() {
    return _db
        .collection('novedades')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getNovedadesForUser(List<String>? userCategories) {
    final List<String> categoriesToQuery = ['all'];
    if (userCategories != null && userCategories.isNotEmpty) {
      categoriesToQuery.addAll(userCategories.where((c) => c.isNotEmpty));
    }
    return _db
        .collection('novedades')
        .where('category', whereIn: categoriesToQuery)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          list.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  Future<void> addNovedad(Map<String, dynamic> novedadData) async {
    await _db.collection('novedades').add({
      ...novedadData,
      'createdAt': FieldValue.serverTimestamp(),
      'comments': [],
    });
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
}
