import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      .map((snapshot) {
    return snapshot.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .where((d) =>
            (d['tutorId'] == userId || d['playerId'] == userId) &&
            (d['status'] == 'pending' || d['status'] == null))
        .toList();
  });
});

/// Streams all tutor convocatorias for a specific match to show live status to the coach
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
      final pid = doc.data()['playerId'] as String?;
      final st = doc.data()['status'] as String? ?? 'pending';
      if (pid != null) {
        statusMap[pid] = st;
      }
    }
    return statusMap;
  });
});

/// Updates the convocatoria status for a specific player in a match.
/// Updates both 'tutor_convocatorias' and 'matches/{matchId}/convocatoria/{playerId}'.
Future<void> updateConvocatoriaStatus({
  required String matchId,
  required String playerId,
  required String status, // 'confirmed' or 'rejected'
  String? tutorId,
  String? rejectionReason,
}) async {
  final db = FirebaseFirestore.instance;
  final updateData = <String, dynamic>{
    'status': status,
    'confirmedAt': FieldValue.serverTimestamp(),
  };
  if (rejectionReason != null && rejectionReason.isNotEmpty) {
    updateData['rejectionReason'] = rejectionReason;
  }

  // 1. Update in matches/{matchId}/convocatoria/{playerId}
  try {
    await db
        .collection('matches')
        .doc(matchId)
        .collection('convocatoria')
        .doc(playerId)
        .set(updateData, SetOptions(merge: true));
  } catch (_) {}

  // 2. Update matching documents in tutor_convocatorias collection ONLY for this specific match
  try {
    final query = await db
        .collection('tutor_convocatorias')
        .where('playerId', isEqualTo: playerId)
        .where('matchId', isEqualTo: matchId)
        .get();

    for (final doc in query.docs) {
      await doc.reference.update(updateData);
    }
  } catch (_) {}
}

