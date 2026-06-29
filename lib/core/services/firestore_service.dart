import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to handle Firestore operations
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Announcements (Comunicados) ───────────────────

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
    dynamic sessionUser, // Using dynamic to avoid circular import if user_session is not imported here, but we will pass UserSession
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

  // ─── Sponsors (Publicidades) ───────────────────

  /// Stream of all sponsors
  Stream<List<Map<String, dynamic>>> getSponsors() {
    return _db
        .collection('sponsors')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Create a new sponsor
  Future<void> addSponsor(Map<String, dynamic> sponsorData) async {
    await _db.collection('sponsors').add(sponsorData);
  }

  /// Delete a sponsor
  Future<void> deleteSponsor(String id) async {
    await _db.collection('sponsors').doc(id).delete();
  }

  // ─── Novedades (Feed Principal) ───────────────────

  /// Stream of all novedades
  Stream<List<Map<String, dynamic>>> getAllNovedades() {
    return _db
        .collection('novedades')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Stream of novedades filtered by category visibility
  Stream<List<Map<String, dynamic>>> getNovedadesForUser(String? category) {
    List<String> categories = ['all'];
    if (category != null && category.isNotEmpty) {
      categories.add(category);
    }
    return _db
        .collection('novedades')
        .where('category', whereIn: categories)
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

  /// Create a new novedad
  Future<void> addNovedad(Map<String, dynamic> novedadData) async {
    await _db.collection('novedades').add({
      ...novedadData,
      'createdAt': FieldValue.serverTimestamp(),
      'comments': [],
    });
  }

  /// Delete a novedad
  Future<void> deleteNovedad(String id) async {
    await _db.collection('novedades').doc(id).delete();
  }

  /// Add comment to a novedad
  Future<void> addCommentToNovedad(
    String novedadId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('novedades').doc(novedadId).update({
      'comments': FieldValue.arrayUnion([commentData]),
    });
  }

  /// Delete a comment from a novedad
  Future<void> deleteCommentFromNovedad(
    String novedadId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('novedades').doc(novedadId).update({
      'comments': FieldValue.arrayRemove([commentData]),
    });
  }

  // ─── Calendar Events (Calendario) ──────────────────

  /// Stream of calendar events
  Stream<List<Map<String, dynamic>>> getCalendarEvents() {
    return _db
        .collection('events')
        .orderBy('date', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // ─── Matches & Results (Resultados/Fixture) ───────

  /// Stream of matches
  Stream<List<Map<String, dynamic>>> getMatches() {
    return _db
        .collection('matches')
        .orderBy('matchday', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }
}

// ─── Riverpod Providers ──────────────────────────────

/// Provider to access FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// StreamProvider for announcements (legacy)
final announcementsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(firestoreServiceProvider).getAnnouncements();
});

/// StreamProvider for announcements filtered by category
final userAnnouncementsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, UserAnnouncementQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(firestoreServiceProvider)
          .getAnnouncementsForUser(query.category, query.isAdmin);
    });

/// StreamProvider for all sponsors
final sponsorsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(firestoreServiceProvider).getSponsors();
});

/// StreamProvider for all novedades (visible to admin/coordinators)
final allNovedadesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(firestoreServiceProvider).getAllNovedades();
});

/// StreamProvider for novedades filtered by user category
final userNovedadesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String?>((ref, category) {
      return ref.watch(firestoreServiceProvider).getNovedadesForUser(category);
    });

/// StreamProvider for calendar events
final calendarEventsStreamProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) {
    return ref.watch(firestoreServiceProvider).getCalendarEvents();
  },
);

/// StreamProvider for matches/results
final matchesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getMatches();
});

/// Helper class for user announcements query parameter
class UserAnnouncementQuery {
  final String? category;
  final bool isAdmin;

  const UserAnnouncementQuery({this.category, required this.isAdmin});

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
