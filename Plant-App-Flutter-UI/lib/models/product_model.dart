import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String type;
  final List<String> categories;
  final String description;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.type = 'Plant',
    this.categories = const [],
    this.description = '',
    this.stock = 10,
  });

  bool get isSoldOut => stock <= 0;
  bool get isAvailable => stock > 0;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Product(
      id: doc.id,
      name: (data['name'] ?? 'Botanical Specimen').toString(),
      price: double.tryParse((data['price'] ?? 0).toString()) ?? 0.0,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      type: (data['type'] ?? 'Plant').toString(),
      categories: (data['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      description: (data['description'] ?? '').toString(),
      stock: int.tryParse((data['stock'] ?? 0).toString()) ?? 0,
    );
  }
}
