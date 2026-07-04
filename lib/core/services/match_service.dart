import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for match-related operations: matches, fixtures, formations, lineups, 
/// convocatorias, league reports, coach reports, and scorers.
/// (SRP: handles the competitive/sports domain)
class MatchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Matches ───────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getMatches() {
    return _db
        .collection('matches')
        .orderBy('matchday', descending: false)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // ─── Convocatorias & Lineups ───────────────────────
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

  Stream<Map<String, dynamic>?> getFormation(String matchId) {
    return _db.collection('matches').doc(matchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['formation'] as Map<String, dynamic>?;
    });
  }

  Future<void> saveFormation(String matchId, Map<String, dynamic> formationData) async {
    await _db.collection('matches').doc(matchId).update({
      'formation': formationData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Fixtures ──────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getFixtures(String category) {
    return _db.collection('fixtures').where('category', isEqualTo: category).orderBy('createdAt').limit(20).snapshots().map(
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

  // ─── League Reports ────────────────────────────────
  Stream<List<Map<String, dynamic>>> getLeagueReports() {
    return _db.collection('league_reports').orderBy('createdAt', descending: true).limit(20).snapshots().map(
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

  // ─── Coach Reports ─────────────────────────────────
  Stream<List<Map<String, dynamic>>> getCoachReports() {
    return _db.collection('coach_reports').orderBy('createdAt', descending: true).limit(20).snapshots().map(
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

  // ─── Scorers ───────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getScorersByCategory(String category) {
    return _db
        .collection('scorers')
        .where('category', isEqualTo: category)
        .orderBy('goals', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> addScorer(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('scorers').add(data);
  }

  Future<void> updateScorer(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('scorers').doc(id).update(data);
  }

  Future<void> deleteScorer(String id) async {
    await _db.collection('scorers').doc(id).delete();
  }

  // ─── Clubs ─────────────────────────────────────────
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

  Future<void> addClub(Map<String, dynamic> clubData) async {
    await _db.collection('clubs').add({
      ...clubData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateClub(String id, Map<String, dynamic> clubData) async {
    await _db.collection('clubs').doc(id).update({
      ...clubData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteClub(String id) async {
    await _db.collection('clubs').doc(id).delete();
  }
}
