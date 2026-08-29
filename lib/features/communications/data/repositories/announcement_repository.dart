import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of all announcements ordered by date
  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _db
        .collection('announcements')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Stream of announcements filtered by user categories (supports multiple categories)
  Stream<List<Map<String, dynamic>>> getAnnouncementsForUser({
    required List<String> categories,
    required bool isAdmin,
  }) {
    return _db.collection('announcements').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort in memory by date (descending) or createdAt
      list.sort((a, b) {
        final aVal = a['date']?.toString() ?? '';
        final bVal = b['date']?.toString() ?? '';
        return bVal.compareTo(aVal);
      });

      if (isAdmin) return list;

      final lowerCategories = categories.map((c) => c.toLowerCase().trim()).where((c) => c.isNotEmpty).toSet();

      return list.where((ann) {
        final cat = ann['category']?.toString().toLowerCase().trim();
        final eventCat = ann['eventCategory']?.toString().toLowerCase().trim();

        if (cat == null ||
            cat.isEmpty ||
            cat == 'todos' ||
            cat == 'all' ||
            cat == 'general' ||
            cat == 'deportivo' ||
            cat == 'administrativo') {
          return true;
        }

        if (lowerCategories.contains(cat)) {
          return true;
        }

        if (eventCat != null && lowerCategories.contains(eventCat)) {
          return true;
        }

        return false;
      }).toList();
    });
  }

  /// Create a new announcement
  Future<void> addAnnouncement(Map<String, dynamic> announcementData) async {
    await _db.collection('announcements').add({
      ...announcementData,
      'createdAt': FieldValue.serverTimestamp(),
      'comments': [],
      'seenBy': [],
    });
  }

  /// Delete an announcement
  Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
  }

  /// Add comment to an announcement
  Future<void> addCommentToAnnouncement(
    String announcementId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('announcements').doc(announcementId).update({
      'comments': FieldValue.arrayUnion([commentData]),
    });
  }

  /// Delete a comment from an announcement
  Future<void> deleteCommentFromAnnouncement(
    String announcementId,
    Map<String, dynamic> commentData,
  ) async {
    await _db.collection('announcements').doc(announcementId).update({
      'comments': FieldValue.arrayRemove([commentData]),
    });
  }

  /// Enable or disable comments for an announcement
  Future<void> toggleAnnouncementComments(
    String announcementId,
    bool isEnabled,
  ) async {
    await _db.collection('announcements').doc(announcementId).update({
      'commentsEnabled': isEnabled,
    });
  }

  /// Mark an announcement as seen by a user
  Future<void> markAnnouncementAsSeen(
    String announcementId,
    dynamic sessionUser,
  ) async {
    try {
      if (sessionUser == null || (sessionUser.id ?? '').toString().isEmpty) return;
      final docRef = _db.collection('announcements').doc(announcementId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final rawList = docSnap.data()?['seenBy'] as List? ?? [];
      final bool alreadySeen = rawList.any((e) {
        if (e is Map) return e['userId'] == sessionUser.id;
        if (e is String) return e == sessionUser.id;
        return false;
      });
      if (alreadySeen) return;

      final viewData = {
        'userId': sessionUser.id,
        'userName': '${sessionUser.name} ${sessionUser.lastName}'.trim(),
        'userRole': sessionUser.role ?? '',
        'timestamp': Timestamp.now(),
      };
      await docRef.update({
        'seenBy': FieldValue.arrayUnion([viewData]),
      });
    } catch (e) {
      debugPrint('Error marking announcement as seen: $e');
    }
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

class UserAnnouncementQuery {
  final List<String> categories;
  final bool isAdmin;

  UserAnnouncementQuery({required this.categories, required this.isAdmin});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAnnouncementQuery &&
          runtimeType == other.runtimeType &&
          listEquals(categories, other.categories) &&
          isAdmin == other.isAdmin;

  @override
  int get hashCode => Object.hash(Object.hashAll(categories), isAdmin);
}

final announcementsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(announcementRepositoryProvider).getAnnouncements();
});

final userAnnouncementsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, UserAnnouncementQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(announcementRepositoryProvider)
          .getAnnouncementsForUser(
            categories: query.categories,
            isAdmin: query.isAdmin,
          );
    });

/// Provider for unread announcements count matching the user's role and categories
final unreadAnnouncementsCountProvider = StreamProvider<int>((ref) {
  final sessionUser = ref.watch(currentUserProvider);
  if (sessionUser == null || sessionUser.id.isEmpty) {
    return Stream.value(0);
  }

  final List<String> userCategories = [];
  if (sessionUser.role == 'dt') {
    if (sessionUser.assignedCategories != null && sessionUser.assignedCategories!.isNotEmpty) {
      userCategories.addAll(sessionUser.assignedCategories!);
    } else if (sessionUser.category != null) {
      userCategories.add(sessionUser.category!);
    }
  } else if (sessionUser.role == 'tutor') {
    final tutorChildren = ref.watch(tutorPlayersStreamProvider(sessionUser.id)).valueOrNull ?? [];
    for (final child in tutorChildren) {
      final cat = child['category']?.toString();
      if (cat != null && cat.isNotEmpty) {
        userCategories.add(cat);
      }
    }
    if (sessionUser.category != null) {
      userCategories.add(sessionUser.category!);
    }
  } else {
    if (sessionUser.category != null && sessionUser.category!.isNotEmpty) {
      userCategories.add(sessionUser.category!);
    }
  }

  return ref
      .watch(announcementRepositoryProvider)
      .getAnnouncementsForUser(
        categories: userCategories,
        isAdmin: sessionUser.isAdmin,
      )
      .map((announcements) {
        int unreadCount = 0;
        for (final ann in announcements) {
          final seenBy = ann['seenBy'] as List? ?? [];
          final hasSeen = seenBy.any((e) {
            if (e is Map) return e['userId'] == sessionUser.id;
            if (e is String) return e == sessionUser.id;
            return false;
          });
          if (!hasSeen) {
            unreadCount++;
          }
        }
        return unreadCount;
      });
});
