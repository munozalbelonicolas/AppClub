import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final String? imageUrl;
  final bool isVisible;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    this.imageUrl,
    this.isVisible = true,
    this.createdAt,
  });

  bool get isOutOfStock => stock <= 0;

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      category: map['category'] ?? 'otros',
      imageUrl: map['imageUrl'],
      isVisible: map['isVisible'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
      'imageUrl': imageUrl,
      'isVisible': isVisible,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
