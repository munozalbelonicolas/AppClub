import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of all announcements ordered by date
  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _db
        .collection('announcements')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Stream of announcements filtered by user category
  Stream<List<Map<String, dynamic>>> getAnnouncementsForUser(
    String? category,
    bool isAdmin,
  ) {
    return _db.collection('announcements').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort in memory by date (descending) or createdAt
      list.sort((a, b) {
        final aVal = a['date']?.toString() ?? '';
        final bVal = b['date']?.toString() ?? '';
        return bVal.compareTo(aVal);
      });

      if (isAdmin) return list;

      return list.where((ann) {
        final cat = ann['category']?.toString().toLowerCase();
        if (cat == 'todos' ||
            cat == 'all' ||
            cat == 'general' ||
            cat == 'deportivo' ||
            cat == 'administrativo') {
          return true;
        }
        if (category == null) return false;
        return cat == category.toLowerCase();
      }).toList();
    });
  }

  /// Create a new announcement
  Future<void> addAnnouncement(Map<String, dynamic> announcementData) async {
    await _db.collection('announcements').add({
      ...announcementData,
      'createdAt': FieldValue.serverTimestamp(),
      'comments': [],
      'seenBy': [],
    });
  }

  /// Delete an announcement
  Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
  }

  /// Add comment to an announcement
  Future<void> addCommentToAnnouncement(
    String announcementId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('announcements').doc(announcementId).update({
      'comments': FieldValue.arrayUnion([commentData]),
    });
  }

  /// Delete a comment from an announcement
  Future<void> deleteCommentFromAnnouncement(
    String announcementId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('announcements').doc(announcementId).update({
      'comments': FieldValue.arrayRemove([commentData]),
    });
  }

  /// Enable or disable comments for an announcement
  Future<void> toggleAnnouncementComments(
    String announcementId,
    bool isEnabled,
  ) async {
    await _db.collection('announcements').doc(announcementId).update({
      'commentsEnabled': isEnabled,
    });
  }

  /// Mark an announcement as seen by a user
  Future<void> markAnnouncementAsSeen(
    String announcementId,
    dynamic sessionUser,
  ) async {
    final viewData = {
      'userId': sessionUser.id,
      'userName': '${sessionUser.name} ${sessionUser.lastName}',
      'userRole': sessionUser.role,
      'timestamp': Timestamp.now(),
    };
    await _db.collection('announcements').doc(announcementId).update({
      'seenBy': FieldValue.arrayUnion([viewData]),
    });
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

class UserAnnouncementQuery {
  final String? category;
  final bool isAdmin;

  UserAnnouncementQuery({required this.category, required this.isAdmin});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAnnouncementQuery &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          isAdmin == other.isAdmin;

  @override
  int get hashCode => category.hashCode ^ isAdmin.hashCode;
}

final announcementsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(announcementRepositoryProvider).getAnnouncements();
});

final userAnnouncementsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, UserAnnouncementQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(announcementRepositoryProvider)
          .getAnnouncementsForUser(query.category, query.isAdmin);
    });
