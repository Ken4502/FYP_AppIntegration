import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:urbangreen/models/cart_item_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final Map<String, dynamic> shippingAddress;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.shippingAddress,
    required this.paymentMethod,
    this.status = 'Pending',
    this.createdAt,
  });

  int get totalItemCount => items.fold(0, (acc, item) => acc + item.quantity);

  String get formattedAddress {
    final street = (shippingAddress['street'] ?? '').toString();
    final city = (shippingAddress['city'] ?? '').toString();
    final state = (shippingAddress['state'] ?? '').toString();
    final zip = (shippingAddress['zipCode'] ?? '').toString();

    final parts = [street, city, state, zip].where((s) => s.trim().isNotEmpty).toList();
    if (parts.isEmpty) return 'No address provided';
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'totalAmount': totalAmount,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'totalAmount': totalAmount,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> data) {
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String);
    }

    return OrderModel(
      id: (data['id'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      items: itemsList,
      subtotal: double.tryParse((data['subtotal'] ?? 0).toString()) ?? 0.0,
      deliveryFee: double.tryParse((data['deliveryFee'] ?? 0).toString()) ?? 0.0,
      totalAmount: double.tryParse((data['totalAmount'] ?? 0).toString()) ?? 0.0,
      shippingAddress: Map<String, dynamic>.from(data['shippingAddress'] as Map? ?? {}),
      paymentMethod: (data['paymentMethod'] ?? 'Cash on Delivery').toString(),
      status: (data['status'] ?? 'Processing').toString(),
      createdAt: created,
    );
  }

  factory OrderModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final merged = Map<String, dynamic>.from(data);
    merged['id'] = doc.id;
    return OrderModel.fromJson(merged);
  }
}
