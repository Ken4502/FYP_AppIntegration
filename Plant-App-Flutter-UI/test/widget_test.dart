import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';

void main() {
  group('CartModel Tests', () {
    test('Cart starts empty', () {
      final cart = CartModel();
      expect(cart.items.isEmpty, true);
      expect(cart.itemCount, 0);
      expect(cart.totalPrice, 0.0);
    });

    test('Adding an item updates item count and total price', () {
      final cart = CartModel();
      final item = CartItem(
        productId: 'p1',
        name: 'Monstera Deliciosa',
        price: 48.00,
        imageUrl: 'assets/images/image_1.png',
        quantity: 1,
      );

      cart.addItem(item);

      expect(cart.items.length, 1);
      expect(cart.itemCount, 1);
      expect(cart.totalPrice, 48.00);
    });

    test('Adding duplicate item increments quantity without creating duplicate rows', () {
      final cart = CartModel();
      final item1 = CartItem(
        productId: 'p1',
        name: 'Monstera Deliciosa',
        price: 48.00,
      );
      final item2 = CartItem(
        productId: 'p1',
        name: 'Monstera Deliciosa',
        price: 48.00,
      );

      cart.addItem(item1);
      cart.addItem(item2);

      expect(cart.items.length, 1);
      expect(cart.itemCount, 2);
      expect(cart.totalPrice, 96.00);
    });

    test('Decrementing item decreases quantity or leaves at 1', () {
      final cart = CartModel();
      final item = CartItem(
        productId: 'f1',
        name: 'Neem Oil Spray',
        price: 26.50,
        quantity: 2,
      );

      cart.addItem(item);
      cart.decrementItem('f1');

      expect(cart.items.first.quantity, 1);
      expect(cart.totalPrice, 26.50);

      // Decrementing when quantity == 1 stays at 1
      cart.decrementItem('f1');
      expect(cart.items.first.quantity, 1);
    });

    test('Removing item deletes it completely from cart', () {
      final cart = CartModel();
      cart.addItem(CartItem(productId: 'a', name: 'Item A', price: 10.0));
      cart.addItem(CartItem(productId: 'b', name: 'Item B', price: 20.0));

      expect(cart.items.length, 2);
      cart.removeItem('a');

      expect(cart.items.length, 1);
      expect(cart.items.first.productId, 'b');
      expect(cart.totalPrice, 20.0);
    });

    test('Clearing cart removes all items', () {
      final cart = CartModel();
      cart.addItem(CartItem(productId: 'a', name: 'Item A', price: 10.0));
      cart.addItem(CartItem(productId: 'b', name: 'Item B', price: 20.0));

      cart.clearCart();

      expect(cart.items.isEmpty, true);
      expect(cart.itemCount, 0);
      expect(cart.totalPrice, 0.0);
    });

    test('CartItem toJson and fromJson roundtrip for Firebase persistence', () {
      final item = CartItem(
        productId: 'f_test_1',
        name: 'Organic Plant Food',
        price: 34.50,
        imageUrl: 'assets/images/image_2.png',
        quantity: 3,
      );

      final json = item.toJson();
      expect(json['productId'], 'f_test_1');
      expect(json['name'], 'Organic Plant Food');
      expect(json['price'], 34.50);
      expect(json['imageUrl'], 'assets/images/image_2.png');
      expect(json['quantity'], 3);

      final reconstructed = CartItem.fromJson(json);
      expect(reconstructed.productId, item.productId);
      expect(reconstructed.name, item.name);
      expect(reconstructed.price, item.price);
      expect(reconstructed.imageUrl, item.imageUrl);
      expect(reconstructed.quantity, item.quantity);
    });

    test('CartModel setItemsForTesting updates state and notifies listeners', () {
      final cart = CartModel();
      bool notified = false;
      cart.addListener(() {
        notified = true;
      });

      cart.setItemsForTesting([
        CartItem(productId: 'cloud_1', name: 'Fiddle Leaf Fig', price: 65.0, quantity: 2),
      ]);

      expect(notified, true);
      expect(cart.items.length, 1);
      expect(cart.itemCount, 2);
      expect(cart.totalPrice, 130.0);
    });
  });
}
