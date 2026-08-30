import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cached_provider_helpers.dart';
import 'app_logger.dart';
import 'cache_service.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retrieves a stream of category names sorted alphabetically, backed by 1-hour cache.
  Stream<List<String>> getCategories() {
    return createCachedStream<List<String>>(
      cacheKey: 'categories',
      ttl: const Duration(hours: 1),
      fetchFn: () async {
        final snapshot = await _db
            .collection('categories')
            .orderBy('name')
            .get();
        return snapshot.docs
            .map((doc) => doc.data()['name'] as String?)
            .whereType<String>()
            .toList();
      },
    );
  }

  /// Adds a new category if it doesn't exist and invalidates cache.
  Future<void> addCategory(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    try {
      final docRef = _db.collection('categories').doc(trimmedName);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        await docRef.set({
          'name': trimmedName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        CacheService().invalidate('categories');
      }
    } catch (e) {
      AppLogger.error('Error adding category: $name', error: e, tag: 'CategoryService');
      rethrow;
    }
  }

  /// Ensures a category exists. Alias for addCategory.
  Future<void> ensureCategoryExists(String name) async {
    await addCategory(name);
  }

  /// Deletes a category and invalidates cache.
  Future<void> deleteCategory(String name) async {
    try {
      await _db.collection('categories').doc(name).delete();
      CacheService().invalidate('categories');
    } catch (e) {
      AppLogger.error('Error deleting category: $name', error: e, tag: 'CategoryService');
      rethrow;
    }
  }
}

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService();
});

final categoriesStreamProvider = StreamProvider<List<String>>((ref) {
  // Keep alive to prevent unnecessary disposal and re-creation
  ref.keepAlive();
  final service = ref.watch(categoryServiceProvider);
  return service.getCategories();
});
