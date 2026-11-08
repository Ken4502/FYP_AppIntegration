import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/order_model.dart';

class OrderService {
  final FirebaseFirestore? _customFirestore;

  OrderService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Translates raw Firestore or network exceptions into understandable user explanations
  static String formatDatabaseError(dynamic error, [String? queryPath]) {
    final str = error.toString().toLowerCase();
    final pathInfo = queryPath != null ? ' on [$queryPath]' : '';
    if (str.contains('permission-denied') || str.contains('permission_denied')) {
      return 'Cloud Firestore permission denied$pathInfo. Please ensure you are logged into your registered UrbanGreen account.';
    } else if (str.contains('failed-precondition') || str.contains('index')) {
      return 'Cloud Firestore requires an index$pathInfo. Querying in un-indexed fallback mode.';
    } else if (str.contains('unavailable') || str.contains('network') || str.contains('socket') || str.contains('timeout')) {
      return 'Unable to reach Firebase servers. Please verify your mobile data or Wi-Fi internet connection.';
    } else if (str.contains('unauthenticated')) {
      return 'Authentication expired. Please log in again to access your orders from Firebase.';
    } else if (str.contains('not-found')) {
      return 'Order record not found in Firebase Firestore$pathInfo.';
    } else {
      return 'Firebase database error: $error';
    }
  }

  /// Places a customer order directly into Firebase Cloud Firestore
  Future<String> placeOrder({
    required String userId,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required Map<String, dynamic> shippingAddress,
    required String paymentMethod,
    String status = 'Processing',
  }) async {
    if (userId.isEmpty) {
      throw Exception('Cannot place order: User is not authenticated. Please log in first.');
    }
    if (items.isEmpty) {
      throw Exception('Cannot place order: Cart is empty.');
    }

    // Generate readable order ID e.g., UG-748291
    final randomDigits = Random().nextInt(900000) + 100000;
    final orderId = 'UG-$randomDigits';

    final order = OrderModel(
      id: orderId,
      userId: userId,
      items: List.from(items),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      totalAmount: totalAmount,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      status: status,
      createdAt: DateTime.now(),
    );

    final orderMap = order.toMap();

    final fs = _firestore;
    if (fs == null) {
      debugPrint('Notice: Running in environment without initialized Firebase: generated order $orderId');
      return orderId;
    }

    // 1. Write directly to user's orders subcollection in Firebase Firestore
    await fs
        .collection('users')
        .doc(userId)
        .collection('orders')
        .doc(orderId)
        .set(orderMap);

    // 2. Dual-write to root orders collection for global auditing (best effort)
    try {
      await fs.collection('orders').doc(orderId).set(orderMap);
    } catch (e) {
      debugPrint('Notice: Global order write failed: $e');
    }

    // 3. Best-effort decrement stock in plant_supplies in Firestore
    for (final item in items) {
      if (item.productId.isNotEmpty && !item.productId.startsWith('fb_')) {
        try {
          await fs.collection('plant_supplies').doc(item.productId).update({
            'stock': FieldValue.increment(-item.quantity),
          });
        } catch (_) {}
      }
    }

    return orderId;
  }

  /// Creates a sample starter order directly in Firebase Cloud Firestore
  Future<String> createSampleOrder(String userId) async {
    if (userId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in before generating an order in Firebase.');
      }
      userId = user.uid;
    }

    final sampleItems = [
      CartItem(
        productId: 'supply_01',
        name: 'Organic Neem Oil Pest Spray',
        price: 24.50,
        imageUrl: 'assets/images/image_1.png',
        quantity: 1,
      ),
      CartItem(
        productId: 'supply_02',
        name: 'Smart Plant Moisture Sensor Probe',
        price: 45.00,
        imageUrl: 'assets/images/image_2.png',
        quantity: 1,
      ),
    ];

    return await placeOrder(
      userId: userId,
      items: sampleItems,
      subtotal: 69.50,
      deliveryFee: 0.0,
      totalAmount: 69.50,
      shippingAddress: {
        'name': 'Home Delivery',
        'phone': '+60 12-345 6789',
        'street': '7, Jalan Botanika 3',
        'city': 'Cyberjaya',
        'state': 'Selangor',
        'zipCode': '63000',
      },
      paymentMethod: 'Credit / Debit Card',
      status: 'Shipped',
    );
  }

  /// Real-time stream of orders queried directly from Firebase Cloud Firestore
  Stream<List<OrderModel>> getUserOrdersStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    final fs = _firestore;
    if (fs == null) {
      return Stream.value([]);
    }

    // Direct real-time stream from Firebase Firestore subcollection
    return fs
        .collection('users')
        .doc(userId)
        .collection('orders')
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map((doc) => OrderModel.fromDocument(doc)).toList();
          orders.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2020);
            final bTime = b.createdAt ?? DateTime(2020);
            return bTime.compareTo(aTime);
          });
          return orders;
        });
  }

  /// Fetch a single order by ID directly from Firebase Cloud Firestore
  Future<OrderModel?> getOrderById(String orderId, {String? userId}) async {
    final fs = _firestore;
    if (fs == null) return null;

    final effectiveUid = userId ?? FirebaseAuth.instance.currentUser?.uid;

    // 1. Try user's personal orders subcollection in Firestore
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      try {
        final userDoc = await fs
            .collection('users')
            .doc(effectiveUid)
            .collection('orders')
            .doc(orderId)
            .get();
        if (userDoc.exists) {
          return OrderModel.fromDocument(userDoc);
        }
      } catch (e) {
        debugPrint('Error fetching order from user subcollection: $e');
      }
    }

    // 2. Try global orders collection in Firestore
    try {
      final doc = await fs.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return OrderModel.fromDocument(doc);
      }
    } catch (e) {
      debugPrint('Error fetching order from global collection: $e');
    }

    return null;
  }

  /// Cancel an order directly in Firebase Cloud Firestore
  Future<void> cancelOrder(String orderId, String userId) async {
    if (userId.isEmpty) {
      throw Exception('User authentication required to cancel order.');
    }

    final fs = _firestore;
    if (fs == null) return;

    final cancelData = {
      'status': 'Cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    };

    // 1. Update user's order in Firestore
    await fs
        .collection('users')
        .doc(userId)
        .collection('orders')
        .doc(orderId)
        .update(cancelData);

    // 2. Best-effort update root orders collection in Firestore
    try {
      await fs.collection('orders').doc(orderId).update(cancelData);
    } catch (_) {}

    // 3. Best-effort restore inventory in plant_supplies
    try {
      final orderDoc = await fs
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .get();
      if (orderDoc.exists) {
        final order = OrderModel.fromDocument(orderDoc);
        for (final item in order.items) {
          if (item.productId.isNotEmpty && !item.productId.startsWith('fb_')) {
            try {
              await fs.collection('plant_supplies').doc(item.productId).update({
                'stock': FieldValue.increment(item.quantity),
              });
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
