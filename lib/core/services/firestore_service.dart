import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'match_service.dart';
import 'novedades_service.dart';

/// Facade service that delegates to domain-specific services.
/// Preserves backward compatibility so existing code continues to work
/// while the internal logic is properly separated by domain (SRP).
class FirestoreService {
  final NovedadesService _novedades = NovedadesService();
  final MatchService _match = MatchService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Direct access to domain services ─────────────
  NovedadesService get novedades => _novedades;
  MatchService get match => _match;

  // ─── Novedades (delegated) ────────────────────────
  Stream<List<Map<String, dynamic>>> getAllNovedades() => _novedades.getAllNovedades();
  Stream<List<Map<String, dynamic>>> getNovedadesForUser(String? category) => _novedades.getNovedadesForUser(category);
  Future<void> addNovedad(Map<String, dynamic> data) => _novedades.addNovedad(data);
  Future<void> deleteNovedad(String id) => _novedades.deleteNovedad(id);
  Future<void> addCommentToNovedad(String novedadId, Map<String, dynamic> commentData) =>
      _novedades.addCommentToNovedad(novedadId, commentData);
  Future<void> deleteCommentFromNovedad(String novedadId, Map<String, dynamic> commentData) =>
      _novedades.deleteCommentFromNovedad(novedadId, commentData);
  Future<void> toggleLikeNovedad(String novedadId, String userId) =>
      _novedades.toggleLikeNovedad(novedadId, userId);

  // ─── Calendar Events ──────────────────────────────
  Stream<List<Map<String, dynamic>>> getCalendarEvents() {
    return _db
        .collection('events')
        .orderBy('date', descending: false)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // ─── Matches (delegated) ──────────────────────────
  Stream<List<Map<String, dynamic>>> getMatches() => _match.getMatches();
  Stream<List<Map<String, dynamic>>> getConvocatoria(String matchId) => _match.getConvocatoria(matchId);
  Stream<List<Map<String, dynamic>>> getLineup(String matchId) => _match.getLineup(matchId);
  Stream<Map<String, dynamic>?> getFormation(String matchId) => _match.getFormation(matchId);
  Future<void> saveFormation(String matchId, Map<String, dynamic> data) => _match.saveFormation(matchId, data);

  // ─── Players ──────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getPlayers() {
    return _db.collection('users').where('role', isEqualTo: 'jugador').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  Stream<Map<String, dynamic>?> getPlayerProfile(String playerId) {
    return _db.collection('users').doc(playerId).snapshots().map(
          (doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null,
        );
  }

  Future<void> updatePlayerQuotaStatus(String playerId, String status) async {
    await _db.collection('users').doc(playerId).update({
      'quotaStatus': status,
      if (status == 'al_dia') 'lastQuotaPaymentDate': FieldValue.serverTimestamp(),
    });
  }

  // ─── Payments ─────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getPayments(String userId) {
    return _db
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ─── Clubs (delegated) ────────────────────────────
  Stream<List<Map<String, dynamic>>> getClubs() => _match.getClubs();
  Future<void> addClub(Map<String, dynamic> data) => _match.addClub(data);
  Future<void> updateClub(String id, Map<String, dynamic> data) => _match.updateClub(id, data);
  Future<void> deleteClub(String id) => _match.deleteClub(id);

  // ─── Fixtures (delegated) ─────────────────────────
  Stream<List<Map<String, dynamic>>> getFixtures(String category) => _match.getFixtures(category);
  Future<void> addFixture(Map<String, dynamic> data) => _match.addFixture(data);
  Future<void> updateFixture(String id, Map<String, dynamic> data) => _match.updateFixture(id, data);
  Future<void> deleteFixture(String id) => _match.deleteFixture(id);

  // ─── League Reports (delegated) ───────────────────
  Stream<List<Map<String, dynamic>>> getLeagueReports() => _match.getLeagueReports();
  Future<void> addLeagueReport(Map<String, dynamic> data) => _match.addLeagueReport(data);
  Future<void> deleteLeagueReport(String id) => _match.deleteLeagueReport(id);

  // ─── Coach Reports (delegated) ────────────────────
  Stream<List<Map<String, dynamic>>> getCoachReports() => _match.getCoachReports();
  Future<void> addCoachReport(Map<String, dynamic> data) => _match.addCoachReport(data);
  Future<void> deleteCoachReport(String id) => _match.deleteCoachReport(id);

  // ─── Scorers (delegated) ──────────────────────────
  Stream<List<Map<String, dynamic>>> getScorersByCategory(String category) => _match.getScorersByCategory(category);
  Future<void> addScorer(Map<String, dynamic> data) => _match.addScorer(data);
  Future<void> updateScorer(String id, Map<String, dynamic> data) => _match.updateScorer(id, data);
  Future<void> deleteScorer(String id) => _match.deleteScorer(id);
}

// ─── Riverpod Providers ──────────────────────────────

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final allNovedadesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getAllNovedades();
});

final userNovedadesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String?>((ref, category) {
      return ref.watch(firestoreServiceProvider).getNovedadesForUser(category);
    });

final calendarEventsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getCalendarEvents();
});

final matchesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getMatches();
});

final playersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getPlayers();
});

final playerProfileStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, playerId) {
  return ref.watch(firestoreServiceProvider).getPlayerProfile(playerId);
});

final convocatoriaStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return ref.watch(firestoreServiceProvider).getConvocatoria(matchId);
});

final tutorPlayersStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, tutorId) {
  return FirebaseFirestore.instance
      .collection('player_tutor_links')
      .where('tutorId', isEqualTo: tutorId)
      .snapshots()
      .asyncMap((snapshot) async {
    final List<Map<String, dynamic>> children = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final playerId = data['playerId'] as String?;
      if (playerId != null) {
        final playerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(playerId)
            .get();
        if (playerDoc.exists) {
          children.add({
            'id': playerDoc.id,
            ...playerDoc.data()!,
          });
        }
      }
    }
    return children;
  });
});

final lineupStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return ref.watch(firestoreServiceProvider).getLineup(matchId);
});

final userPaymentsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getPayments(userId);
});

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

final scorersStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  return ref.watch(firestoreServiceProvider).getScorersByCategory(category);
});
