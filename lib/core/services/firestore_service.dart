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
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// Create a new announcement
  Future<void> addAnnouncement(Map<String, dynamic> announcementData) async {
    await _db.collection('announcements').add({
      ...announcementData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Calendar Events (Calendario) ──────────────────
  
  /// Stream of calendar events
  Stream<List<Map<String, dynamic>>> getCalendarEvents() {
    return _db
        .collection('events')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // ─── Matches & Results (Resultados/Fixture) ───────
  
  /// Stream of matches
  Stream<List<Map<String, dynamic>>> getMatches() {
    return _db
        .collection('matches')
        .orderBy('matchday', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }
}

// ─── Riverpod Providers ──────────────────────────────

/// Provider to access FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// StreamProvider for announcements
final announcementsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getAnnouncements();
});

/// StreamProvider for calendar events
final calendarEventsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getCalendarEvents();
});

/// StreamProvider for matches/results
final matchesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getMatches();
});
