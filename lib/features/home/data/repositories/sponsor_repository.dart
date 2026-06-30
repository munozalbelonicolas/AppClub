import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SponsorRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of all sponsors
  Stream<List<Map<String, dynamic>>> getSponsors() {
    return _db
        .collection('sponsors')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Create a new sponsor
  Future<void> addSponsor(Map<String, dynamic> sponsorData) async {
    await _db.collection('sponsors').add(sponsorData);
  }

  /// Delete a sponsor
  Future<void> deleteSponsor(String id) async {
    await _db.collection('sponsors').doc(id).delete();
  }
}

final sponsorRepositoryProvider = Provider<SponsorRepository>((ref) {
  return SponsorRepository();
});

final sponsorsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(sponsorRepositoryProvider).getSponsors();
});
