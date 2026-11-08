import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:urbangreen/models/cart_item_model.dart';

class CartService {
  final FirebaseFirestore _firestore;

  CartService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Real-time stream of the user's shopping cart items from Firebase
  Stream<List<CartItem>> getCartStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('carts')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return <CartItem>[];
      }
      final data = snapshot.data()!;
      final rawItems = data['items'];
      if (rawItems is List) {
        return rawItems
            .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return <CartItem>[];
    }).handleError((error) {
      debugPrint('[CartService] Error in cart stream for $userId: $error');
      return <CartItem>[];
    });
  }

  /// Fetch user's cart from Firebase once
  Future<List<CartItem>> getCart(String userId) async {
    if (userId.isEmpty) return [];

    try {
      // 1. Primary dedicated collection: carts/{userId}
      final snapshot = await _firestore.collection('carts').doc(userId).get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final rawItems = data['items'];
        if (rawItems is List && rawItems.isNotEmpty) {
          return rawItems
              .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }

      // 2. User subcollection fallback: users/{userId}/cart/current
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final rawItems = data['items'];
        if (rawItems is List && rawItems.isNotEmpty) {
          return rawItems
              .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[CartService] Failed to load cart from Firebase for $userId: $e');
    }

    return [];
  }

  /// Persists the user's entire cart to Firebase in both:
  /// 1. Primary dedicated collection: carts/{userId}
  /// 2. User subcollection: users/{userId}/cart/current
  Future<void> saveCart({
    required String userId,
    required List<CartItem> items,
  }) async {
    if (userId.isEmpty) return;

    try {
      final cartData = {
        'userId': userId,
        'items': items.map((i) => i.toJson()).toList(),
        'itemCount': items.fold<int>(0, (total, i) => total + i.quantity),
        'totalPrice': items.fold<double>(0.0, (total, i) => total + (i.price * i.quantity)),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Save to primary root collection: carts/{userId}
      await _firestore
          .collection('carts')
          .doc(userId)
          .set(cartData, SetOptions(merge: true));

      // 2. Save to user subcollection: users/{userId}/cart/current
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .set(cartData, SetOptions(merge: true));

      debugPrint('[CartService] Cart synced to Firebase (${items.length} items for $userId)');
    } catch (e) {
      debugPrint('[CartService] Error saving cart to Firebase: $e');
    }
  }

  /// Deletes the cart from Firebase when checkout completes or user clears cart
  Future<void> clearCart(String userId) async {
    if (userId.isEmpty) return;

    try {
      await _firestore.collection('carts').doc(userId).delete();
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .delete();
      debugPrint('[CartService] Cart cleared from Firebase for user: $userId');
    } catch (e) {
      debugPrint('[CartService] Error clearing cart from Firebase: $e');
    }
  }

  /// Merges local cart items with the existing cloud cart items
  Future<List<CartItem>> mergeCart({
    required String userId,
    required List<CartItem> localItems,
  }) async {
    if (userId.isEmpty) return localItems;

    try {
      final cloudItems = await getCart(userId);
      final mergedMap = <String, CartItem>{};

      // Add cloud items first
      for (final item in cloudItems) {
        mergedMap[item.productId] = item;
      }

      // Merge local items
      for (final local in localItems) {
        if (mergedMap.containsKey(local.productId)) {
          mergedMap[local.productId]!.quantity += local.quantity;
        } else {
          mergedMap[local.productId] = local;
        }
      }

      final result = mergedMap.values.toList();
      await saveCart(userId: userId, items: result);
      return result;
    } catch (e) {
      debugPrint('[CartService] Error merging cart: $e');
      return localItems;
    }
  }
}
