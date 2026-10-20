import 'package:flutter/material.dart';
import 'package:urbangreen/models/cart_item_model.dart';

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  void addItem(CartItem item) {
    int existingIndex =
        _items.indexWhere((element) => element.productId == item.productId);

    if (existingIndex != -1) {
      _items[existingIndex].incrementQuantity();
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void decrementItem(String productId) {
    int existingIndex =
        _items.indexWhere((element) => element.productId == productId);

    if (existingIndex != -1) {
      _items[existingIndex].decrementQuantity();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
