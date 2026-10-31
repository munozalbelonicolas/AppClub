import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';

/// Streams all pending convocatorias for a tutor.
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

    final List<Map<String, dynamic>> result = [];
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
      final status = d['status']?.toString();
      final isPending = status == 'pending' || status == null || status.isEmpty;

      if (isForUser && isPending) {
        final matchId = d['matchId']?.toString() ?? doc.id;
        final pId = playerId ?? userId;
        handledPlayerMatchKeys.add('${matchId}_$pId');
        result.add({'id': doc.id, ...d});
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
              final st = cData['status']?.toString();
              if (st == 'pending' || st == null || st.isEmpty) {
                handledPlayerMatchKeys.add(key);
                result.add({
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
                  'status': 'pending',
                });
              }
            }
          }
        } catch (_) {}
      }
    }

    return result;
  });
});

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
