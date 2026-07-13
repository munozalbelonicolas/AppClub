import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

class BirthdayService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> checkAndTriggerBirthdays() async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final currentYear = today.year;

      final configDoc = await _db.doc('settings/birthday_system').get();
      if (!configDoc.exists) return;
      final config = configDoc.data()!;

      final enablePosts = config['enablePosts'] ?? true;
      final enableNotifications = config['enableNotifications'] ?? true;
      final daysPriorToNotify = config['daysPriorToNotify'] ?? 1;
      final textTemplate = config['textTemplate'] ??
          'Todo el equipo de AppClub y nuestro club queremos desearle un muy feliz cumpleaños a {nombre}. Esperamos que tengas un excelente día junto a tu familia y amigos.';

      if (!enablePosts && !enableNotifications) return;

      final targetNotificationDate = today.add(Duration(days: daysPriorToNotify));

      // 1. Transaction to prevent multiple devices from running it on the same day
      final checkRef = _db.doc('settings/last_birthday_check');
      final bool shouldRun = await _db.runTransaction((transaction) async {
        final doc = await transaction.get(checkRef);
        if (doc.exists && doc.data()?['lastRunDate'] == todayStr) {
          return false; // Already ran today
        }
        transaction.set(checkRef, {'lastRunDate': todayStr}, SetOptions(merge: true));
        return true;
      });

      if (!shouldRun) return; // Another user already triggered it today

      AppLogger.info('Triggering local birthday check for $todayStr', tag: 'BirthdayService');

      // 2. Query active players
      final playersSnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'jugador')
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _db.batch();
      int operationsCount = 0;

      for (var doc in playersSnapshot.docs) {
        final player = doc.data();
        if (player['birthDate'] == null) continue;

        final birthDate = (player['birthDate'] as Timestamp).toDate();
        final isBirthdayToday = birthDate.day == today.day && birthDate.month == today.month;
        final isNotificationDay = birthDate.day == targetNotificationDate.day && birthDate.month == targetNotificationDate.month;

        final playerName = player['name'] ?? '';
        final playerLastName = player['lastName'] ?? '';
        final playerCategory = player['category'];

        // Posts
        if (isBirthdayToday && enablePosts) {
          final logId = '${doc.id}_$currentYear';
          final logRef = _db.collection('birthday_logs').doc(logId);
          final logDoc = await logRef.get();

          if (!logDoc.exists) {
            final postRef = _db.collection('novedades').doc();
            final postText = textTemplate.replaceAll('{nombre}', '$playerName $playerLastName');

            batch.set(postRef, {
              'title': '¡Feliz Cumpleaños $playerName!',
              'body': postText,
              'type': 'birthday',
              'category': 'all',
              'authorId': 'system',
              'authorName': 'AppClub',
              'authorRole': 'admin',
              'createdAt': FieldValue.serverTimestamp(),
            });

            batch.set(logRef, {
              'playerId': doc.id,
              'year': currentYear,
              'postedAt': FieldValue.serverTimestamp(),
            });

            operationsCount += 2;
          }
        }

        // Notifications
        if (enableNotifications) {
          String message = '';
          if (isNotificationDay && daysPriorToNotify > 0) {
            message = '🎂 Faltan $daysPriorToNotify días para el cumpleaños de $playerName $playerLastName (Cat: ${playerCategory ?? 'N/A'}). No olvides saludarlo.';
          } else if (isBirthdayToday) {
            message = '🎉 Hoy es el cumpleaños de $playerName $playerLastName. ¡No olvides felicitarlo!';
          }

          if (message.isNotEmpty) {
            final notifRef1 = _db.collection('notifications').doc();
            batch.set(notifRef1, {
              'title': 'Aviso de Cumpleaños',
              'body': message,
              'targetRole': 'directivo',
              'type': 'birthday',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
            operationsCount++;

            if (playerCategory != null) {
              final notifRef2 = _db.collection('notifications').doc();
              batch.set(notifRef2, {
                'title': 'Cumpleaños en tu categoría',
                'body': message,
                'targetRole': 'dt',
                'targetCategory': playerCategory,
                'type': 'birthday',
                'createdAt': FieldValue.serverTimestamp(),
                'isRead': false,
              });
              operationsCount++;
            }
          }
        }

        // Firestore limits batch to 500
        if (operationsCount >= 490) {
          await batch.commit();
          operationsCount = 0;
        }
      }

      if (operationsCount > 0) {
        await batch.commit();
      }

      AppLogger.info('Local birthday check completed successfully.', tag: 'BirthdayService');
    } on FirebaseException catch (e) {
      AppLogger.error('Error triggering local birthday check', error: e, tag: 'BirthdayService');
    }
  }
}

final birthdayServiceProvider = Provider<BirthdayService>((ref) {
  return BirthdayService();
});
