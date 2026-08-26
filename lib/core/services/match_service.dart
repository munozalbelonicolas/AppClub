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
    return _db.collection('fixtures').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      DateTime? parseDate(dynamic raw) {
        if (raw == null) return null;
        if (raw is Timestamp) return raw.toDate();
        final s = raw.toString().trim();
        if (s.isEmpty) return null;
        if (s.contains('-')) {
          final parts = s.split('-');
          if (parts.length == 3) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) return DateTime(y, m, d);
          }
        } else if (s.contains('/')) {
          final parts = s.split('/');
          if (parts.length == 3) {
            final d = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final y = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) return DateTime(y, m, d);
          }
        }
        return null;
      }

      DateTime? getFixtureDate(Map<String, dynamic> f) {
        final d = parseDate(f['date']);
        if (d != null) return d;
        final matches = f['matches'];
        if (matches is List && matches.isNotEmpty) {
          final first = matches.first;
          if (first is Map) {
            final md = parseDate(first['date']);
            if (md != null) return md;
          }
        }
        if (f['createdAt'] is Timestamp) {
          return (f['createdAt'] as Timestamp).toDate();
        }
        return null;
      }

      // Sort fixtures by date ascending
      list.sort((a, b) {
        final dateA = getFixtureDate(a);
        final dateB = getFixtureDate(b);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

      // Sort matches inside each fixture by date and time
      for (final fix in list) {
        final matches = fix['matches'];
        if (matches is List) {
          final sortedMatches = List<Map<String, dynamic>>.from(
            matches.map((m) => Map<String, dynamic>.from(m as Map)),
          );
          sortedMatches.sort((m1, m2) {
            final d1 = parseDate(m1['date']);
            final d2 = parseDate(m2['date']);
            if (d1 != null && d2 != null) {
              final cmp = d1.compareTo(d2);
              if (cmp != 0) return cmp;
            }
            final t1 = m1['time']?.toString() ?? '';
            final t2 = m2['time']?.toString() ?? '';
            return t1.compareTo(t2);
          });
          fix['matches'] = sortedMatches;
        }
      }

      return list;
    });
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
    return _db.collection('scorers').snapshots().map((snapshot) {
      final cleanTarget = category
          .replaceAll('Categoría', '')
          .replaceAll('Cat.', '')
          .replaceAll('Cat', '')
          .trim()
          .toLowerCase();

      final list = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((sc) {
        if (category == 'all' || category == 'Todas las Cat.' || category.isEmpty) {
          return true;
        }
        final scCat = (sc['category']?.toString() ?? '')
            .replaceAll('Categoría', '')
            .replaceAll('Cat.', '')
            .replaceAll('Cat', '')
            .trim()
            .toLowerCase();

        return scCat == cleanTarget ||
            (cleanTarget.isNotEmpty && scCat.contains(cleanTarget)) ||
            (scCat.isNotEmpty && cleanTarget.contains(scCat));
      }).toList();

      list.sort((a, b) {
        final ga = (a['goals'] is int)
            ? a['goals'] as int
            : int.tryParse(a['goals']?.toString() ?? '') ?? 0;
        final gb = (b['goals'] is int)
            ? b['goals'] as int
            : int.tryParse(b['goals']?.toString() ?? '') ?? 0;
        return gb.compareTo(ga);
      });

      return list;
    });
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

  // ─── League Jornadas (Planillas Oficiales UCIV) ────
  Stream<List<Map<String, dynamic>>> getLeagueJornadas() {
    return _db.collection('league_jornadas').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      list.sort((a, b) {
        final numA = num.tryParse(a['fechaNumber']?.toString() ?? '0') ?? 0;
        final numB = num.tryParse(b['fechaNumber']?.toString() ?? '0') ?? 0;
        return numB.compareTo(numA); // Descendente por defecto
      });
      return list;
    });
  }
}
