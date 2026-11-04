import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';

/// Streams the convocatorias of a tutor's players: pending ones plus the ones already
/// answered (confirmed/rejected) for upcoming matches, so the tutor keeps seeing them.
/// Listens in real-time to the 'tutor_convocatorias' collection.
final tutorConvocatoriasProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  if (userId.isEmpty) {
    return Stream.value([]);
  }

  final db = FirebaseFirestore.instance;

  return db
      .collection('tutor_convocatorias')
      .snapshots()
      .asyncMap((snapshot) async {
    // 1. Get linked player IDs for this tutor
    final Set<String> playerIds = {userId};
    final Map<String, Map<String, dynamic>> playerInfoMap = {};

    try {
      final linksSnap = await db
          .collection('player_tutor_links')
          .where('tutorId', isEqualTo: userId)
          .get();
      for (final doc in linksSnap.docs) {
        final pid = doc.data()['playerId']?.toString();
        if (pid != null && pid.isNotEmpty) {
          playerIds.add(pid);
        }
      }
    } catch (_) {}

    // Fetch user doc for each linked player
    for (final pid in playerIds) {
      try {
        final pDoc = await db.collection('users').doc(pid).get();
        if (pDoc.exists && pDoc.data() != null) {
          playerInfoMap[pid] = pDoc.data()!;
        }
      } catch (_) {}
    }

    // matchId_playerId -> convocatoria (one per player even if it has several tutor docs)
    final Map<String, Map<String, dynamic>> resultByKey = {};
    final Set<String> handledPlayerMatchKeys = {};

    // 2. Check existing tutor_convocatorias docs
    for (final doc in snapshot.docs) {
      final d = doc.data();
      final tutorId = d['tutorId']?.toString();
      final playerId = d['playerId']?.toString();
      final tutorIds = (d['tutorIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      
      final isForUser = tutorId == userId ||
          playerIds.contains(playerId) ||
          tutorIds.contains(userId);
      if (!isForUser || !_isRelevantForTutor(d)) continue;

      final matchId = d['matchId']?.toString() ?? doc.id;
      final pId = playerId ?? userId;
      final key = '${matchId}_$pId';
      handledPlayerMatchKeys.add(key);
      final existing = resultByKey[key];
      // Si hay varios docs (uno por tutor), gana el que ya tiene respuesta
      if (existing == null || _normalizeStatus(existing['status']) == 'pending') {
        resultByKey[key] = {'id': doc.id, ...d, 'status': _normalizeStatus(d['status'])};
      }
    }

    // 3. Fallback: Check matches and subcollections for any convocated child
    for (final entry in playerInfoMap.entries) {
      final childId = entry.key;
      final childData = entry.value;
      final childCategory = childData['category']?.toString() ?? '';
      final childName = '${childData['name'] ?? ''} ${childData['lastName'] ?? ''}'.trim();

      if (childCategory.isNotEmpty) {
        try {
          final matchesSnap = await db
              .collection('matches')
              .limit(10)
              .get();

          for (final mDoc in matchesSnap.docs) {
            final matchId = mDoc.id;
            final key = '${matchId}_$childId';
            if (handledPlayerMatchKeys.contains(key)) continue;

            final mData = mDoc.data();
            final matchCat = mData['category']?.toString() ?? '';
            
            // Check if match category matches child category or if subcollection has player
            final cDoc = await db
                .collection('matches')
                .doc(matchId)
                .collection('convocatoria')
                .doc(childId)
                .get();

            if (cDoc.exists) {
              final cData = cDoc.data() ?? {};
              final st = _normalizeStatus(cData['status']);
              if (_isRelevantForTutor({...mData, ...cData, 'status': st})) {
                handledPlayerMatchKeys.add(key);
                resultByKey[key] = {
                  'id': '${matchId}_$childId',
                  'matchId': matchId,
                  'playerId': childId,
                  'playerName': childName.isNotEmpty ? childName : (cData['name'] ?? 'Jugador'),
                  'category': matchCat.isNotEmpty ? matchCat : childCategory,
                  'homeTeam': mData['homeTeam'] ?? 'Jorge Newbery',
                  'awayTeam': mData['awayTeam'] ?? mData['rival'] ?? 'Rival',
                  'venue': mData['venue'] ?? mData['location'] ?? 'Cancha Principal JN',
                  'date': mData['date'] ??
                      mData['matchDate'] ??
                      mData['eventDate'] ??
                      mData['dateYMD'] ??
                      mData['fecha'] ??
                      mData['startDate'] ??
                      '',
                  'time': mData['time'] ??
                      mData['eventTime'] ??
                      mData['matchTime'] ??
                      mData['hora'] ??
                      mData['startTime'] ??
                      '',
                  'status': st,
                  if (cData['rejectionReason'] != null) 'rejectionReason': cData['rejectionReason'],
                };
              }
            }
          }
        } catch (_) {}
      }
    }

    return resultByKey.values.toList();
  });
});

/// Pending convocatorias are always shown. Answered ones only while the match is upcoming
/// (or, if the date can't be parsed, during the week after the answer).
bool _isRelevantForTutor(Map<String, dynamic> d) {
  if (_normalizeStatus(d['status']) == 'pending') return true;

  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  final matchDate = _parseMatchDate(d['date'] ?? d['matchDate'] ?? d['eventDate'] ?? d['dateYMD']);
  if (matchDate != null) return !matchDate.isBefore(startOfToday);

  final answeredAt = d['respondedAt'] ?? d['confirmedAt'];
  if (answeredAt is Timestamp) {
    return today.difference(answeredAt.toDate()).inDays < 7;
  }
  return true;
}

DateTime? _parseMatchDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s.split('T').first);
  if (iso != null) return iso;
  final parts = s.split(RegExp(r'[/-]'));
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) return DateTime(year, month, day);
  }
  return null;
}

/// Streams all tutor convocatorias for a specific match to show live status to the coach.
/// A player may have one doc per tutor: a real response always wins over 'pending'.
final coachConvocatoriaStatusProvider =
    StreamProvider.family<Map<String, String>, String>((ref, matchId) {
  if (matchId.isEmpty) {
    return Stream.value({});
  }

  final db = FirebaseFirestore.instance;

  return db
      .collection('tutor_convocatorias')
      .where('matchId', isEqualTo: matchId)
      .snapshots()
      .map((snapshot) {
    final Map<String, String> statusMap = {};
    for (final doc in snapshot.docs) {
      final pid = doc.data()['playerId']?.toString();
      final st = _normalizeStatus(doc.data()['status']);
      if (pid == null) continue;
      if (st != 'pending' || !statusMap.containsKey(pid)) {
        statusMap[pid] = st;
      }
    }
    return statusMap;
  });
});

/// Combined convocatoria status per player for a match (playerId -> confirmed/rejected/pending).
/// Merges matches/{matchId}/convocatoria (source of truth) with tutor_convocatorias.
final matchConvocatoriaStatusProvider =
    Provider.family<Map<String, String>, String>((ref, matchId) {
  final subDocs = ref.watch(convocatoriaStreamProvider(matchId)).valueOrNull ?? [];
  final tutorStatus = ref.watch(coachConvocatoriaStatusProvider(matchId)).valueOrNull ?? {};

  final Map<String, String> statusMap = {};
  for (final doc in subDocs) {
    final pid = (doc['playerId'] ?? doc['id'])?.toString();
    if (pid != null) statusMap[pid] = _normalizeStatus(doc['status']);
  }
  tutorStatus.forEach((pid, st) {
    if (!statusMap.containsKey(pid) || (st != 'pending' && statusMap[pid] == 'pending')) {
      statusMap[pid] = st;
    }
  });
  return statusMap;
});

String _normalizeStatus(dynamic raw) {
  final st = raw?.toString() ?? '';
  return st == 'confirmed' || st == 'rejected' ? st : 'pending';
}

/// Updates the convocatoria status for a specific player in a match.
/// Writes atomically to 'matches/{matchId}/convocatoria/{playerId}' and every
/// matching 'tutor_convocatorias' doc. Errors are propagated so the UI can report them.
Future<void> updateConvocatoriaStatus({
  required String matchId,
  required String playerId,
  required String status, // 'confirmed' or 'rejected'
  String? tutorId,
  String? rejectionReason,
}) async {
  if (matchId.isEmpty || playerId.isEmpty) {
    throw ArgumentError('matchId y playerId son obligatorios');
  }

  final db = FirebaseFirestore.instance;
  final hasReason = status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty;
  final updateData = <String, dynamic>{
    'status': status,
    'respondedAt': FieldValue.serverTimestamp(),
    'confirmedAt': FieldValue.serverTimestamp(),
    'rejectionReason': hasReason ? rejectionReason : FieldValue.delete(),
    if (tutorId != null && tutorId.isNotEmpty) 'respondedBy': tutorId,
  };

  final batch = db.batch();

  batch.set(
    db.collection('matches').doc(matchId).collection('convocatoria').doc(playerId),
    {'playerId': playerId, 'matchId': matchId, ...updateData},
    SetOptions(merge: true),
  );

  final tutorConvs = await db
      .collection('tutor_convocatorias')
      .where('playerId', isEqualTo: playerId)
      .get();
  for (final doc in tutorConvs.docs) {
    final docMatchId = doc.data()['matchId']?.toString();
    if (docMatchId == matchId || (docMatchId == null && doc.id.startsWith('${matchId}_'))) {
      batch.set(doc.reference, updateData, SetOptions(merge: true));
    }
  }

  await batch.commit();
}
