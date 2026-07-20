import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

class PlayerExistsException implements Exception {
  final String playerId;
  final String playerName;

  PlayerExistsException(this.playerId, this.playerName);

  @override
  String toString() => 'PlayerExistsException: $playerName ya está registrado.';
}

class PlayerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> registerOrLinkPlayer({
    required String tutorId,
    required String dni,
    required String name,
    required String lastName,
    required DateTime? birthDate,
    required String category,
    required String weight,
    required String height,
    String? email,
    String? password,
    required bool enableAccount,
    String? avatarUrl,
    String? tutorName,
  }) async {
    // 1. Check if DNI already exists
    final querySnapshot = await _db
        .collection('users')
        .where('dni', isEqualTo: dni)
        .where('role', isEqualTo: 'jugador')
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // DNI exists, abort and throw exception
      final doc = querySnapshot.docs.first;
      final existingPlayerId = doc.id;
      final existingPlayerName = '${doc.data()['name']} ${doc.data()['lastName']}';
      throw PlayerExistsException(existingPlayerId, existingPlayerName);
    } else {
      // Create new player
      String? authUid;
      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        // To create a user without signing out the tutor, we use a secondary app
        try {
          final FirebaseApp tempApp = await Firebase.initializeApp(
            name: 'temp_register',
            options: Firebase.app().options,
          );
          final UserCredential cred = await FirebaseAuth.instanceFor(
            app: tempApp,
          ).createUserWithEmailAndPassword(email: email, password: password);
          authUid = cred.user?.uid;
          await tempApp.delete();
        } on FirebaseAuthException catch (e) {
          AppLogger.error('Error creating auth for player', error: e, tag: 'PlayerService');
          rethrow;
        }
      }

      // If no auth created, generate a document ID
      final newPlayerRef = authUid != null
          ? _db.collection('users').doc(authUid)
          : _db.collection('users').doc();

      // Calculate age for legacy compatibility
      int computedAge = 0;
      String computedCategory = category;
      if (birthDate != null) {
        final now = DateTime.now();
        computedAge = now.year - birthDate.year;
        if (now.month < birthDate.month ||
            (now.month == birthDate.month && now.day < birthDate.day)) {
          computedAge--;
        }
        
        // Dynamically assign and create category based on birth year
        computedCategory = birthDate.year.toString();

        final categoryRef = _db.collection('categories').doc(computedCategory);
        final categorySnap = await categoryRef.get();
        if (!categorySnap.exists) {
          await categoryRef.set({
            'name': computedCategory,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await newPlayerRef.set({
        'name': name,
        'lastName': lastName,
        'dni': dni,
        'age': computedAge,
        'birthDate': birthDate != null ? Timestamp.fromDate(birthDate) : null,
        'category': computedCategory,
        'weight': weight,
        'height': height,
        'email': email,
        'role': 'jugador',
        'status': 'pending_approval',
        'avatarUrl': avatarUrl,
        'fatherName': tutorName,
        'parentName': tutorName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create tutor-player link directly (since it's a new player created by this tutor)
      await _db.collection('player_tutor_links').add({
        'tutorId': tutorId,
        'playerId': newPlayerRef.id,
        'isEnabledByTutor': enableAccount,
        'status': 'linked', // Auto linked since they created it
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create notification for admin
      await _db.collection('notifications').add({
        'type': 'player_registration',
        'userId': newPlayerRef.id,
        'userName': '$name $lastName',
        'tutorId': tutorId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }



  Future<void> submitCoTutorRequest({
    required String tutorId,
    required String tutorName,
    required String playerId,
    required String playerName,
    required bool enableAccount,
  }) async {
    // Verify it's not already linked or pending
    final existingLink = await _db
        .collection('player_tutor_links')
        .where('tutorId', isEqualTo: tutorId)
        .where('playerId', isEqualTo: playerId)
        .get();

    if (existingLink.docs.isNotEmpty) {
      throw Exception('Ya existe una vinculación o solicitud pendiente para este jugador.');
    }

    // 1. Create the link request
    final linkRef = await _db.collection('player_tutor_links').add({
      'tutorId': tutorId,
      'playerId': playerId,
      'isEnabledByTutor': enableAccount,
      'status': 'pending_admin_approval',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Create the notification for admins
    await _db.collection('notifications').add({
      'type': 'co_tutor_request',
      'linkId': linkRef.id,
      'tutorId': tutorId,
      'tutorName': tutorName,
      'playerId': playerId,
      'playerName': playerName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService();
});
