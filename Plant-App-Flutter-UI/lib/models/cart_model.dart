import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/services/cart_service.dart';

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _currentUserId;
  CartService? _cartService;
  StreamSubscription<List<CartItem>>? _cloudCartSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isLoading = false;

  CartModel({
    CartService? cartService,
    FirebaseAuth? auth,
    bool autoSync = true,
  }) {
    if (autoSync && Firebase.apps.isNotEmpty) {
      _cartService = cartService ?? CartService();
      _initAuthListener(auth: auth);
    }
  }

  List<CartItem> get items => _items;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  bool get isLoading => _isLoading;

  String? get currentUserId => _currentUserId;

  /// Initializes real-time synchronization with Firebase Auth and Firestore
  void _initAuthListener({FirebaseAuth? auth}) {
    final authInstance = auth ?? FirebaseAuth.instance;

    // Check if a user is already signed in upon startup
    final currentUser = authInstance.currentUser;
    if (currentUser != null) {
      _onUserLoggedIn(currentUser.uid);
    }

    // Listen to sign in and sign out events in real-time
    _authSubscription = authInstance.authStateChanges().listen((user) {
      if (user != null) {
        if (_currentUserId != user.uid) {
          _onUserLoggedIn(user.uid);
        }
      } else {
        _onUserLoggedOut();
      }
    });
  }

  /// Called when a user logs in (or upon startup if already logged in)
  Future<void> _onUserLoggedIn(String userId) async {
    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      if (_items.isNotEmpty) {
        // User had items in their cart before logging in -> merge with cloud
        final merged = await _cartService?.mergeCart(
          userId: userId,
          localItems: List.from(_items),
        );
        if (merged != null) {
          _items.clear();
          _items.addAll(merged);
        }
      } else {
        // Load existing cloud cart from Firebase
        final cloudItems = await _cartService?.getCart(userId);
        if (cloudItems != null && cloudItems.isNotEmpty) {
          _items.clear();
          _items.addAll(cloudItems);
        }
      }
    } catch (e) {
      debugPrint('[CartModel] Error loading cart for user $userId: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Subscribe to cloud cart stream for real-time updates across devices
    _cloudCartSubscription?.cancel();
    _cloudCartSubscription = _cartService?.getCartStream(userId).listen((cloudItems) {
      if (!_areItemsEqual(_items, cloudItems)) {
        _items.clear();
        _items.addAll(cloudItems);
        notifyListeners();
      }
    });
  }

  /// Called when a user logs out
  void _onUserLoggedOut() {
    _cloudCartSubscription?.cancel();
    _cloudCartSubscription = null;
    _currentUserId = null;
    _items.clear();
    notifyListeners();
  }

  /// Add item to cart with immediate optimistic local UI update and cloud sync
  void addItem(CartItem item) {
    int existingIndex =
        _items.indexWhere((element) => element.productId == item.productId);

    if (existingIndex != -1) {
      _items[existingIndex].incrementQuantity();
    } else {
      _items.add(item);
    }
    notifyListeners();
    _syncToFirebase();
  }

  /// Remove item completely from cart
  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
    _syncToFirebase();
  }

  /// Decrement item quantity (minimum 1)
  void decrementItem(String productId) {
    int existingIndex =
        _items.indexWhere((element) => element.productId == productId);

    if (existingIndex != -1) {
      _items[existingIndex].decrementQuantity();
      notifyListeners();
      _syncToFirebase();
    }
  }

  /// Clear all items from cart (e.g. on order placed or user clear)
  void clearCart() {
    _items.clear();
    notifyListeners();
    if (_currentUserId != null) {
      _cartService?.clearCart(_currentUserId!);
    }
  }

  /// Helper to push current cart state to Firebase asynchronously
  void _syncToFirebase() {
    if (_currentUserId != null && _cartService != null) {
      _cartService!.saveCart(
        userId: _currentUserId!,
        items: List.from(_items),
      );
    }
  }

  /// Manually set items (for testing)
  @visibleForTesting
  void setItemsForTesting(List<CartItem> newItems) {
    _items.clear();
    _items.addAll(newItems);
    notifyListeners();
  }

  bool _areItemsEqual(List<CartItem> a, List<CartItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].productId != b[i].productId ||
          a[i].quantity != b[i].quantity ||
          a[i].price != b[i].price) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _cloudCartSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
