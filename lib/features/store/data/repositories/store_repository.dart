import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/store_config.dart';

class StoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<StoreConfig> watchStoreConfig() {
    return _db.doc('settings/store_config').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return StoreConfig.fromMap(doc.data()!);
      }
      return StoreConfig(isStoreEnabled: true);
    });
  }

  Stream<List<Product>> watchProducts({String filter = 'todos'}) {
    var query = _db
        .collection('store_products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (filter != 'todos') {
      query = _db
          .collection('store_products')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: filter)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

final storeConfigProvider = StreamProvider<StoreConfig>((ref) {
  return ref.watch(storeRepositoryProvider).watchStoreConfig();
});

// Since the filter is dynamic in the UI, we can use a family provider
final storeProductsProvider = StreamProvider.family<List<Product>, String>((ref, filter) {
  return ref.watch(storeRepositoryProvider).watchProducts(filter: filter);
});
