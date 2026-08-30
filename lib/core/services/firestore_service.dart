import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cached_provider_helpers.dart';
import 'cache_service.dart';
import 'category_service.dart';
import 'match_service.dart';
import 'novedades_service.dart';

/// Facade service that delegates to domain-specific services.
/// Preserves backward compatibility so existing code continues to work
/// while applying in-memory caching and limits to reduce Firestore consumption.
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
  Future<void> updateNovedad(String id, Map<String, dynamic> data) => _novedades.updateNovedad(id, data);
  Future<void> deleteNovedad(String id) => _novedades.deleteNovedad(id);
  Future<void> addCommentToNovedad(String novedadId, Map<String, dynamic> commentData) =>
      _novedades.addCommentToNovedad(novedadId, commentData);
  Future<void> deleteCommentFromNovedad(String novedadId, Map<String, dynamic> commentData) =>
      _novedades.deleteCommentFromNovedad(novedadId, commentData);
  Future<void> toggleLikeNovedad(String novedadId, String userId) =>
      _novedades.toggleLikeNovedad(novedadId, userId);

  // ─── Calendar Events ──────────────────────────────
  Stream<List<Map<String, dynamic>>> getCalendarEvents() {
    return createCachedStream<List<Map<String, dynamic>>>(
      cacheKey: 'calendar_events_all',
      ttl: const Duration(minutes: 15),
      fetchFn: () async {
        final snapshot = await _db
            .collection('events')
            .orderBy('date', descending: false)
            .limit(30)
            .get();
        return snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      },
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
    return createCachedStream<List<Map<String, dynamic>>>(
      cacheKey: 'players_all',
      ttl: const Duration(minutes: 10),
      fetchFn: () async {
        final snapshot = await _db
            .collection('users')
            .where('role', isEqualTo: 'jugador')
            .limit(200)
            .get();
        return snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .where((p) => p['role'] == 'jugador')
            .toList();
      },
    );
  }

  // ─── Attendance ───────────────────────────────────
  Stream<Map<String, dynamic>?> getAttendance(String dateStr, String category) {
    final key = '$dateStr-$category';
    return createCachedStream<Map<String, dynamic>?>(
      cacheKey: 'attendance_$key',
      ttl: const Duration(minutes: 10),
      fetchFn: () async {
        final doc = await _db.collection('attendance').doc(key).get();
        return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
      },
    );
  }

  Stream<List<Map<String, dynamic>>> getAttendanceHistory(String category) {
    return createCachedStream<List<Map<String, dynamic>>>(
      cacheKey: 'attendance_history_$category',
      ttl: const Duration(minutes: 10),
      fetchFn: () async {
        final snapshot = await _db
            .collection('attendance')
            .where('category', isEqualTo: category)
            .limit(60)
            .get();
        return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      },
    );
  }

  Future<void> saveAttendance(String dateStr, String category, String dtId, List<String> present, List<String> absent) async {
    final key = '$dateStr-$category';
    await _db.collection('attendance').doc(key).set({
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
    CacheService().invalidate('attendance_$key');
    CacheService().invalidate('attendance_history_$category');
  }

  Future<void> saveAttendanceDetailed({
    required String dateStr,
    required String formattedDate,
    required String category,
    required String dtId,
    required Map<String, String> records,
  }) async {
    final key = '$dateStr-$category';
    final present = records.entries.where((e) => e.value == 'present').map((e) => e.key).toList();
    final absent = records.entries.where((e) => e.value == 'absent').map((e) => e.key).toList();

    await _db.collection('attendance').doc(key).set({
      'dateStr': dateStr,
      'date': dateStr,
      'formattedDate': formattedDate,
      'category': category,
      'dtId': dtId,
      'present': present,
      'absent': absent,
      'records': records,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    CacheService().invalidate('attendance_$key');
    CacheService().invalidate('attendance_history_$category');
  }

  // ─── Training Schedule ────────────────────────────
  Stream<Map<String, dynamic>?> getTrainingSchedule(String category) {
    return createCachedStream<Map<String, dynamic>?>(
      cacheKey: 'training_schedule_$category',
      ttl: const Duration(minutes: 30),
      fetchFn: () async {
        final doc = await _db.collection('training_schedules').doc(category).get();
        return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
      },
    );
  }

  Stream<List<Map<String, dynamic>>> getAllTrainingSchedules() {
    return createCachedStream<List<Map<String, dynamic>>>(
      cacheKey: 'training_schedules_all',
      ttl: const Duration(minutes: 30),
      fetchFn: () async {
        final snapshot = await _db.collection('training_schedules').get();
        return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      },
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
    CacheService().invalidate('training_schedule_$category');
    CacheService().invalidate('training_schedules_all');
  }

  Stream<Map<String, dynamic>?> getPlayerProfile(String playerId) {
    return createCachedStream<Map<String, dynamic>?>(
      cacheKey: 'player_profile_$playerId',
      ttl: const Duration(minutes: 10),
      fetchFn: () async {
        final doc = await _db.collection('users').doc(playerId).get();
        return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
      },
    );
  }

  Future<void> updatePlayerQuotaStatus(String playerId, String status) async {
    await _db.collection('users').doc(playerId).update({
      'quotaStatus': status,
      if (status == 'al_dia') 'lastQuotaPaymentDate': FieldValue.serverTimestamp(),
    });
    CacheService().invalidate('player_profile_$playerId');
    CacheService().invalidate('players_all');
  }

  // ─── Payments ─────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getPayments(String userId) {
    return createCachedStream<List<Map<String, dynamic>>>(
      cacheKey: 'payments_$userId',
      ttl: const Duration(minutes: 10),
      fetchFn: () async {
        final snapshot = await _db
            .collection('payments')
            .where('userId', isEqualTo: userId)
            .orderBy('dueDate', descending: true)
            .limit(20)
            .get();
        return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      },
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

  // ─── League Jornadas (delegated) ──────────────────
  Stream<List<Map<String, dynamic>>> getLeagueJornadas() => _match.getLeagueJornadas();
}

// ─── Riverpod Providers ──────────────────────────────

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final allNovedadesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.keepAlive();
  return ref.watch(firestoreServiceProvider).getAllNovedades();
});

final userNovedadesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, categoriesStr) {
      final categories = categoriesStr.isEmpty ? null : categoriesStr.split(',');
      return ref.watch(firestoreServiceProvider).getNovedadesForUser(categories);
    });

final calendarEventsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.keepAlive();
  return ref.watch(firestoreServiceProvider).getCalendarEvents();
});

final matchesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.keepAlive();
  return ref.watch(firestoreServiceProvider).getMatches();
});

final playersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.keepAlive();
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
  if (tutorId.isEmpty) return Stream.value([]);
  
  return createCachedStream<List<Map<String, dynamic>>>(
    cacheKey: 'tutor_players_$tutorId',
    ttl: const Duration(minutes: 10),
    fetchFn: () async {
      final linksSnap = await FirebaseFirestore.instance
          .collection('player_tutor_links')
          .where('tutorId', isEqualTo: tutorId)
          .get();

      final List<Map<String, dynamic>> children = [];
      final List<String> pidsToFetch = [];

      for (var doc in linksSnap.docs) {
        final data = doc.data();
        final playerId = data['playerId'] as String?;
        if (playerId != null && playerId.isNotEmpty) {
          final cachedUser = CacheService().get<Map<String, dynamic>>('user_doc_$playerId');
          if (cachedUser != null) {
            children.add(cachedUser);
          } else {
            pidsToFetch.add(playerId);
          }
        }
      }

      if (pidsToFetch.isNotEmpty) {
        for (final pid in pidsToFetch) {
          try {
            final playerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(pid)
                .get();
            if (playerDoc.exists && playerDoc.data() != null) {
              final childMap = {
                'id': playerDoc.id,
                ...playerDoc.data()!,
              };
              CacheService().set('user_doc_$pid', childMap, const Duration(minutes: 15));
              children.add(childMap);
            }
          } catch (_) {}
        }
      }
      return children;
    },
  );
});

final lineupStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return ref.watch(firestoreServiceProvider).getLineup(matchId);
});

final userPaymentsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getPayments(userId);
});

final clubsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.keepAlive();
  return ref.watch(firestoreServiceProvider).getClubs();
});

final fixturesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  return ref.watch(firestoreServiceProvider).getFixtures(category);
});

final leagueJornadasStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getLeagueJornadas();
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

String _normalizeToYMD(dynamic rawDate) {
  if (rawDate == null) return '';
  if (rawDate is Timestamp) {
    final d = rawDate.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  if (rawDate is DateTime) {
    return '${rawDate.year}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.day.toString().padLeft(2, '0')}';
  }
  final s = rawDate.toString().trim();
  if (s.isEmpty) return '';
  if (s.contains('T')) return s.split('T')[0];
  if (s.contains('-')) {
    final parts = s.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) return s;
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
  }
  if (s.contains('/')) {
    final parts = s.split('/');
    if (parts.length == 3) {
      if (parts[0].length == 4) return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
  }
  return s;
}

final allUpcomingMatchesProvider = Provider.family<List<Map<String, dynamic>>, String>((ref, category) {
  final matches = ref.watch(matchesStreamProvider).valueOrNull ?? [];
  final fixtures = ref.watch(fixturesStreamProvider(category)).valueOrNull ?? [];
  final novedades = ref.watch(allNovedadesStreamProvider).valueOrNull ?? [];
  final clubs = ref.watch(clubsStreamProvider).valueOrNull ?? [];

  // Identify local club
  final localClub = clubs.where((c) => c['isLocal'] == true).firstOrNull ??
      clubs.where((c) => (c['name'] as String?)?.toLowerCase().contains('los pibes') == true).firstOrNull ??
      clubs.where((c) => (c['name'] as String?)?.toLowerCase().contains('newbery') == true).firstOrNull ??
      (clubs.isNotEmpty ? clubs.first : null);

  final List<Map<String, dynamic>> candidates = [];

  // Helper to extract match details cleanly
  Map<String, dynamic> buildCandidate({
    required String id,
    required Map<String, dynamic> raw,
    required String source,
    String? cat,
    int? homeScore,
    int? awayScore,
  }) {
    final String defaultLocalName = localClub?['name'] ?? 'Jorge Newbery';
    final String? defaultLocalLogo = localClub?['logoUrl'] ?? localClub?['logo'] ?? localClub?['imageUrl'];

    String homeTeamName = defaultLocalName;
    String? homeLogoUrl = defaultLocalLogo;
    String awayTeamName = 'Rival';
    String? awayLogoUrl;

    final homeClubId = raw['homeClubId']?.toString();
    final awayClubId = raw['awayClubId']?.toString();

    // 1. If explicit homeClubId and awayClubId exist (e.g. from fixtures)
    if (homeClubId != null && awayClubId != null) {
      final homeClub = clubs.where((c) => c['id'] == homeClubId || c['name'] == homeClubId).firstOrNull;
      final awayClub = clubs.where((c) => c['id'] == awayClubId || c['name'] == awayClubId).firstOrNull;

      final isHomeLocal = homeClub?['isLocal'] == true || (homeClub?['name'] as String?)?.toLowerCase().contains('newbery') == true || homeClubId == localClub?['id'];
      final isAwayLocal = awayClub?['isLocal'] == true || (awayClub?['name'] as String?)?.toLowerCase().contains('newbery') == true || awayClubId == localClub?['id'];

      homeTeamName = homeClub?['name'] ?? raw['homeTeam'] ?? (isHomeLocal ? defaultLocalName : 'Local');
      homeLogoUrl = homeClub?['logoUrl'] ?? homeClub?['logo'] ?? homeClub?['imageUrl'] ?? raw['homeLogoUrl'] ?? (isHomeLocal ? defaultLocalLogo : null);

      awayTeamName = awayClub?['name'] ?? raw['awayTeam'] ?? (isAwayLocal ? defaultLocalName : 'Visitante');
      awayLogoUrl = awayClub?['logoUrl'] ?? awayClub?['logo'] ?? awayClub?['imageUrl'] ?? raw['awayLogoUrl'] ?? (isAwayLocal ? defaultLocalLogo : null);
    } else {
      // 2. From Novedades or Matches collection
      final rawHome = raw['homeTeam']?.toString().trim();
      final rawAway = raw['awayTeam']?.toString().trim();
      final bool isVisitor = raw['isHome'] == false ||
          raw['isVisitor'] == true ||
          raw['condition'] == 'visitante' ||
          (rawAway != null && (rawAway.toLowerCase().contains('newbery') || rawAway.toLowerCase().contains('jorge newbery')));

      // Resolve opponent club
      final opponentId = raw['opponentClubId'] ?? raw['awayClubId'] ?? raw['rivalClubId'] ?? raw['opponentId'] ?? (isVisitor ? raw['homeClubId'] : raw['awayClubId']);
      Map<String, dynamic>? opponentClub;

      if (opponentId != null) {
        opponentClub = clubs.where((c) => (c['id'] == opponentId || c['name'] == opponentId) && c['isLocal'] != true).firstOrNull;
      }

      if (opponentClub == null && raw['opponentName'] != null) {
        final oppName = raw['opponentName'].toString().trim().toLowerCase();
        opponentClub = clubs.where((c) => c['name']?.toString().trim().toLowerCase() == oppName && c['isLocal'] != true).firstOrNull;
      }

      // Check direct fields
      if (opponentClub == null) {
        for (final k in ['awayTeam', 'opponentName', 'rival', 'opponent', 'homeTeam']) {
          final val = raw[k]?.toString().trim();
          if (val != null && val.isNotEmpty && val != 'Rival' && val != defaultLocalName && val != 'Jorge Newbery') {
            final club = clubs.where((c) => (c['name']?.toString().toLowerCase() == val.toLowerCase() || c['id'] == val) && c['isLocal'] != true).firstOrNull;
            if (club != null) {
              opponentClub = club;
              break;
            }
          }
        }
      }

      // Check title and body for club names
      if (opponentClub == null) {
        for (final club in clubs) {
          final clubName = (club['name'] as String?)?.trim();
          if (clubName != null && clubName.isNotEmpty && club['isLocal'] != true) {
            final titleStr = (raw['title']?.toString() ?? '').toLowerCase();
            final bodyStr = (raw['body']?.toString() ?? '').toLowerCase();
            if (titleStr.contains(clubName.toLowerCase()) || bodyStr.contains(clubName.toLowerCase())) {
              opponentClub = club;
              break;
            }
          }
        }
      }

      String opponentName = opponentClub?['name'] ?? raw['opponentName'] ?? 'Rival';
      String? opponentLogo = opponentClub?['logoUrl'] ?? opponentClub?['logo'] ?? opponentClub?['imageUrl'];

      if (opponentName == 'Rival' && raw['title'] != null) {
        final title = raw['title'].toString().trim();
        final vsIndex = title.toLowerCase().indexOf('vs');
        if (vsIndex != -1 && vsIndex + 2 < title.length) {
          final candidate = title.substring(vsIndex + 2).trim();
          if (candidate.isNotEmpty && !candidate.toLowerCase().contains('newbery')) {
            opponentName = candidate;
            final club = clubs.where((c) => c['name']?.toString().toLowerCase() == candidate.toLowerCase() && c['isLocal'] != true).firstOrNull;
            if (club != null) {
              opponentLogo = club['logoUrl'] ?? club['logo'] ?? club['imageUrl'];
            }
          }
        }
      }

      if (isVisitor) {
        // Jorge Newbery is AWAY / VISITANTE
        homeTeamName = (rawHome != null && rawHome.isNotEmpty && !rawHome.toLowerCase().contains('newbery'))
            ? rawHome
            : opponentName;
        homeLogoUrl = raw['homeLogoUrl'] ?? (homeTeamName == opponentName ? opponentLogo : null);

        awayTeamName = (rawAway != null && rawAway.isNotEmpty && rawAway.toLowerCase().contains('newbery'))
            ? rawAway
            : defaultLocalName;
        awayLogoUrl = raw['awayLogoUrl'] ?? defaultLocalLogo;
      } else {
        // Jorge Newbery is HOME / LOCAL
        homeTeamName = (rawHome != null && rawHome.isNotEmpty && rawHome.toLowerCase().contains('newbery'))
            ? rawHome
            : defaultLocalName;
        homeLogoUrl = raw['homeLogoUrl'] ?? defaultLocalLogo;

        awayTeamName = (rawAway != null && rawAway.isNotEmpty && !rawAway.toLowerCase().contains('newbery'))
            ? rawAway
            : opponentName;
        awayLogoUrl = raw['awayLogoUrl'] ?? (awayTeamName == opponentName ? opponentLogo : null);
      }
    }

    return {
      'id': id,
      'homeTeam': homeTeamName,
      'awayTeam': awayTeamName,
      'homeLogoUrl': homeLogoUrl,
      'awayLogoUrl': awayLogoUrl,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'category': cat ?? category,
      'venue': raw['venue'] ?? raw['location'] ?? 'Cancha Principal JN',
      'date': raw['eventDate'] ??
          raw['date'] ??
          raw['matchDate'] ??
          raw['dateYMD'] ??
          raw['match_date'] ??
          raw['fecha'] ??
          raw['startDate'] ??
          '',
      'time': raw['eventTime'] ??
          raw['time'] ??
          raw['matchTime'] ??
          raw['hora'] ??
          raw['startTime'] ??
          '',
      'status': raw['status'] ?? 'upcoming',
      'source': source,
      'title': raw['title'] ?? 'Partido',
      'body': raw['body'] ?? '',
      'opponentClubId': raw['opponentClubId'],
      'hasTransport': raw['hasTransport'] ?? false,
    };
  }

  // 1. From 'matches' collection
  for (final m in matches) {
    final cat = m['category']?.toString();
    if (cat == null || cat == 'all' || cat == 'todos' || cat == category || category.isEmpty) {
      candidates.add(buildCandidate(
        id: m['id'],
        raw: m,
        source: 'matches',
        cat: cat,
        homeScore: m['homeScore'] as int?,
        awayScore: m['awayScore'] as int?,
      ));
    }
  }

  // 2. From 'fixtures' collection
  for (final f in fixtures) {
    final cat = f['category']?.toString();
    if (cat == null || cat == 'all' || cat == 'todos' || cat == category || category.isEmpty) {
      final matchesList = List<Map<String, dynamic>>.from(f['matches'] ?? []);
      for (final m in matchesList) {
        candidates.add(buildCandidate(
          id: '${f['id']}_${m['homeClubId']}_${m['awayClubId']}',
          raw: {
            ...f,
            ...m,
            'date': m['date'] ??
                m['matchDate'] ??
                m['eventDate'] ??
                m['dateYMD'] ??
                f['date'] ??
                f['eventDate'] ??
                f['matchDate'] ??
                f['dateYMD'] ??
                f['fecha'],
            'time': m['time'] ??
                m['eventTime'] ??
                m['matchTime'] ??
                m['hora'] ??
                f['time'] ??
                f['eventTime'] ??
                f['matchTime'] ??
                f['hora'],
            'venue': m['venue'] ?? m['location'] ?? f['venue'] ?? f['location'],
          },
          source: 'fixture',
          cat: cat,
          homeScore: m['homeScore'] as int?,
          awayScore: m['awayScore'] as int?,
        ));
      }
    }
  }

  // 3. From 'novedades' collection
  for (final n in novedades) {
    final bool isMatch = n['isMatch'] == true || n['eventType'] == 'partido';
    if (!isMatch) continue;

    final cat = n['category']?.toString() ?? n['eventCategory']?.toString();
    if (cat == null || cat == 'all' || cat == 'todos' || cat == category || category.isEmpty) {
      candidates.add(buildCandidate(
        id: n['id'],
        raw: n,
        source: 'novedad',
        cat: cat,
      ));
    }
  }

  // Deduplicate candidates by unique id
  final seenIds = <String>{};
  final List<Map<String, dynamic>> uniqueCandidates = [];
  for (final c in candidates) {
    final id = c['id']?.toString() ?? '';
    if (id.isNotEmpty && seenIds.add(id)) {
      uniqueCandidates.add(c);
    }
  }

  // Sort candidates by date. Non-empty valid dates come first.
  uniqueCandidates.sort((a, b) {
    final dateA = _normalizeToYMD(a['date']);
    final dateB = _normalizeToYMD(b['date']);
    if (dateA.isEmpty && dateB.isEmpty) return 0;
    if (dateA.isEmpty) return 1;
    if (dateB.isEmpty) return -1;
    return dateA.compareTo(dateB);
  });

  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  // Strictly filter out past matches (date before today). Only keep matches >= todayStr or unscheduled.
  final upcomingOnly = uniqueCandidates.where((c) {
    final ymd = _normalizeToYMD(c['date']);
    if (ymd.isNotEmpty) {
      return ymd.compareTo(todayStr) >= 0;
    }
    return true;
  }).toList();

  return upcomingOnly;
});

final nextMatchProvider = Provider.family<Map<String, dynamic>?, String>((ref, category) {
  final candidates = ref.watch(allUpcomingMatchesProvider(category));
  if (candidates.isEmpty) return null;
  return candidates.first;
});
