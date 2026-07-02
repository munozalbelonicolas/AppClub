import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to handle Firestore operations
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  // ─── Players (Jugadores) ──────────────────────────
  Stream<List<Map<String, dynamic>>> getPlayers() {
    return _db.collection('players').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  Stream<Map<String, dynamic>?> getPlayerProfile(String playerId) {
    return _db.collection('players').doc(playerId).snapshots().map(
          (doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null,
        );
  }

  // ─── Convocatorias & Lineups (Convocatorias y Formaciones) ───
  Stream<List<Map<String, dynamic>>> getConvocatoria(String matchId) {
    return _db.collection('matches').doc(matchId).collection('convocatoria').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getLineup(String matchId) {
    return _db.collection('matches').doc(matchId).collection('lineup').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ─── Payments (Cuotas) ───────────────────────────
  Stream<List<Map<String, dynamic>>> getPayments(String userId) {
    return _db
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ─── Clubs (Rival & Local) ─────────────────────────

  /// Stream of all clubs
  Stream<List<Map<String, dynamic>>> getClubs() {
    return _db
        .collection('clubs')
        .orderBy('name', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Create a new club
  Future<void> addClub(Map<String, dynamic> clubData) async {
    await _db.collection('clubs').add({
      ...clubData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update an existing club
  Future<void> updateClub(String id, Map<String, dynamic> clubData) async {
    await _db.collection('clubs').doc(id).update({
      ...clubData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a club
  Future<void> deleteClub(String id) async {
    await _db.collection('clubs').doc(id).delete();
  }
  // ─── Fixtures ───────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getFixtures(String category) {
    return _db.collection('fixtures').where('category', isEqualTo: category).orderBy('createdAt').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  Future<void> addFixture(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('fixtures').add(data);
  }

  Future<void> updateFixture(String id, Map<String, dynamic> data) async {
    await _db.collection('fixtures').doc(id).update(data);
  }

  Future<void> deleteFixture(String id) async {
    await _db.collection('fixtures').doc(id).delete();
  }

  // ─── League Reports ─────────────────────────────────
  Stream<List<Map<String, dynamic>>> getLeagueReports() {
    return _db.collection('league_reports').orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  Future<void> addLeagueReport(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('league_reports').add(data);
  }

  Future<void> deleteLeagueReport(String id) async {
    await _db.collection('league_reports').doc(id).delete();
  }

  // ─── Coach Reports (Reportes de Profesores) ─────────
  Stream<List<Map<String, dynamic>>> getCoachReports() {
    return _db.collection('coach_reports').orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  Future<void> addCoachReport(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('coach_reports').add(data);
  }

  Future<void> deleteCoachReport(String id) async {
    await _db.collection('coach_reports').doc(id).delete();
  }
}

// ─── Riverpod Providers ──────────────────────────────

/// Provider to access FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
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

/// StreamProvider for players
final playersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getPlayers();
});

/// StreamProvider for player profile
final playerProfileStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, playerId) {
  return ref.watch(firestoreServiceProvider).getPlayerProfile(playerId);
});

/// StreamProvider for a match's convocatoria
final convocatoriaStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return ref.watch(firestoreServiceProvider).getConvocatoria(matchId);
});

/// StreamProvider for a match's lineup
final lineupStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return ref.watch(firestoreServiceProvider).getLineup(matchId);
});

/// StreamProvider for user payments
final userPaymentsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getPayments(userId);
});

/// StreamProvider for clubs
final clubsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getClubs();
});

final fixturesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  return ref.watch(firestoreServiceProvider).getFixtures(category);
});

final leagueReportsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getLeagueReports();
});

final coachReportsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getCoachReports();
});
