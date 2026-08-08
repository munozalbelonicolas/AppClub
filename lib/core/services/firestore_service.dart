import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'category_service.dart';
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
  Stream<List<Map<String, dynamic>>> getNovedadesForUser(List<String>? categories) => _novedades.getNovedadesForUser(categories);
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
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((p) => p['role'] == 'jugador')
              .toList(),
        );
  }

  // ─── Attendance ───────────────────────────────────
  Stream<Map<String, dynamic>?> getAttendance(String dateStr, String category) {
    return _db
        .collection('attendance')
        .doc('$dateStr-$category')
        .snapshots()
        .map((doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null);
  }

  Stream<List<Map<String, dynamic>>> getAttendanceHistory(String category) {
    return _db
        .collection('attendance')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> saveAttendance(String dateStr, String category, String dtId, List<String> present, List<String> absent) async {
    await _db.collection('attendance').doc('$dateStr-$category').set({
      'dateStr': dateStr,
      'date': dateStr,
      'category': category,
      'dtId': dtId,
      'present': present,
      'absent': absent,
      'records': {
        for (var p in present) p: 'present',
        for (var a in absent) a: 'absent',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveAttendanceDetailed({
    required String dateStr,
    required String formattedDate,
    required String category,
    required String dtId,
    required Map<String, String> records,
  }) async {
    final present = records.entries.where((e) => e.value == 'present').map((e) => e.key).toList();
    final absent = records.entries.where((e) => e.value == 'absent').map((e) => e.key).toList();

    await _db.collection('attendance').doc('$dateStr-$category').set({
      'dateStr': dateStr,
      'date': dateStr,
      'formattedDate': formattedDate,
      'category': category,
      'dtId': dtId,
      'present': present,
      'absent': absent,
      'records': records,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Training Schedule ────────────────────────────
  Stream<Map<String, dynamic>?> getTrainingSchedule(String category) {
    return _db.collection('training_schedules').doc(category).snapshots().map(
          (doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null,
        );
  }

  Stream<List<Map<String, dynamic>>> getAllTrainingSchedules() {
    return _db.collection('training_schedules').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  Future<void> saveTrainingSchedule(String category, List<String> days, String time, String location) async {
    await _db.collection('training_schedules').doc(category).set({
      'category': category,
      'days': days,
      'time': time,
      'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, categoriesStr) {
      final categories = categoriesStr.isEmpty ? null : categoriesStr.split(',');
      return ref.watch(firestoreServiceProvider).getNovedadesForUser(categories);
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

final appCategoriesProvider = Provider<List<String>>((ref) {
  final categoriesAsync = ref.watch(categoriesStreamProvider);
  final fetchedCategories = categoriesAsync.valueOrNull ?? [];
  
  // Strict filter: only allow categories that are 4 digits (e.g., 2010, 2021)
  final validCategories = fetchedCategories
      .map((c) => c.trim())
      .where((cat) => RegExp(r'^\d{4}$').hasMatch(cat))
      .toList();
      
  return validCategories.isEmpty 
      ? ['2010', '2011', '2012', '2013', '2014', '2015', '2016', '2017', '2018', '2019', '2020', '2021'] 
      : validCategories;
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

final attendanceStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, param) {
  final parts = param.split('|');
  if (parts.length != 2) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).getAttendance(parts[0], parts[1]);
});

final attendanceHistoryStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  return ref.watch(firestoreServiceProvider).getAttendanceHistory(category);
});

final trainingScheduleStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, category) {
  return ref.watch(firestoreServiceProvider).getTrainingSchedule(category);
});

final allTrainingSchedulesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getAllTrainingSchedules();
});

final nextMatchProvider = Provider.family<Map<String, dynamic>?, String>((ref, category) {
  final matches = ref.watch(matchesStreamProvider).valueOrNull ?? [];
  final fixtures = ref.watch(fixturesStreamProvider(category)).valueOrNull ?? [];
  final novedades = ref.watch(allNovedadesStreamProvider).valueOrNull ?? [];
  final clubs = ref.watch(clubsStreamProvider).valueOrNull ?? [];

  final List<Map<String, dynamic>> candidates = [];

  // 1. From 'matches' collection
  for (final m in matches) {
    final cat = m['category']?.toString();
    if (cat == null || cat == 'all' || cat == 'todos' || cat == category || category.isEmpty) {
      candidates.add({
        'id': m['id'],
        'homeTeam': m['homeTeam'] ?? 'Jorge Newbery',
        'awayTeam': m['awayTeam'] ?? 'Rival',
        'homeScore': m['homeScore'],
        'awayScore': m['awayScore'],
        'category': cat ?? category,
        'venue': m['venue'] ?? m['location'] ?? 'Cancha Principal JN',
        'date': m['date'] ?? '',
        'time': m['time'] ?? 'A confirmar',
        'status': m['status'] ?? 'programado',
        'source': 'matches',
      });
    }
  }

  // 2. From 'fixtures' collection
  for (final f in fixtures) {
    final cat = f['category']?.toString();
    if (cat == null || cat == 'all' || cat == 'todos' || cat == category || category.isEmpty) {
      final matchesList = List<Map<String, dynamic>>.from(f['matches'] ?? []);
      for (final m in matchesList) {
        final homeClub = clubs.where((c) => c['id'] == m['homeClubId']).firstOrNull;
        final awayClub = clubs.where((c) => c['id'] == m['awayClubId']).firstOrNull;
        final homeName = homeClub?['name'] ?? 'Jorge Newbery';
        final awayName = awayClub?['name'] ?? 'Rival';

        candidates.add({
          'id': '${f['id']}_${m['homeClubId']}_${m['awayClubId']}',
          'homeTeam': homeName,
          'awayTeam': awayName,
          'homeScore': m['homeScore'],
          'awayScore': m['awayScore'],
          'category': cat ?? category,
          'venue': m['venue'] ?? m['location'] ?? 'Cancha Principal JN',
          'date': m['date'] ?? '',
          'time': m['time'] ?? 'A confirmar',
          'status': m['status'] ?? 'programado',
          'source': 'fixture',
          'fixtureName': f['name'] ?? 'Fecha Fixture',
        });
      }
    }
  }

  // 3. From 'novedades' collection (partidos / amistosos creados por DT o ADMIN)
  for (final n in novedades) {
    final bool isMatch = n['isMatch'] == true || n['eventType'] == 'partido';
    if (!isMatch) continue;

    final cat = n['category']?.toString() ?? n['eventCategory']?.toString();
    if (cat == null || cat == 'all' || cat == 'todos' || cat == category || category.isEmpty) {
      String awayTeam = 'Rival';
      if (n['opponentClubId'] != null) {
        final club = clubs.where((c) => c['id'] == n['opponentClubId']).firstOrNull;
        if (club != null && club['name'] != null) {
          awayTeam = club['name'] as String;
        }
      }
      if (awayTeam == 'Rival' && n['title'] != null && n['title'].toString().isNotEmpty) {
        awayTeam = n['title'] as String;
      }

      candidates.add({
        'id': n['id'],
        'homeTeam': 'Jorge Newbery',
        'awayTeam': awayTeam,
        'homeScore': null,
        'awayScore': null,
        'category': cat ?? category,
        'venue': n['location'] ?? 'Cancha Principal JN',
        'date': n['eventDate'] ?? n['date'] ?? '',
        'time': n['eventTime'] ?? n['time'] ?? 'A confirmar',
        'status': 'programado',
        'source': 'novedad',
        'title': n['title'] ?? 'Partido Amistoso',
      });
    }
  }

  if (candidates.isEmpty) return null;

  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  candidates.sort((a, b) {
    final dateA = a['date']?.toString() ?? '';
    final dateB = b['date']?.toString() ?? '';
    return dateA.compareTo(dateB);
  });

  final upcoming = candidates.where((c) {
    final dateStr = c['date']?.toString() ?? '';
    return dateStr.isEmpty || dateStr.compareTo(todayStr) >= 0;
  }).toList();

  if (upcoming.isNotEmpty) {
    return upcoming.first;
  }

  return candidates.last;
});
