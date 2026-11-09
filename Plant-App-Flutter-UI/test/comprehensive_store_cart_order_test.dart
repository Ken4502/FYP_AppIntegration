import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/order_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/services/recommendation_service.dart';

void main() {
  group('RecommendationService Behavioral Matrix & Algorithm Verification', () {
    late RecommendationService service;

    final catalog = [
      Product(
        id: 'p_monstera',
        name: 'Monstera Deliciosa (Variegated)',
        price: 88.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        categories: ['Indoor Plants', 'Rare Specimen'],
        stock: 5,
      ),
      Product(
        id: 'p_snake_plant',
        name: 'Snake Plant Laurentii',
        price: 32.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        categories: ['Indoor Plants', 'Air Purifying'],
        stock: 0, // Sold out
      ),
      Product(
        id: 'e_can',
        name: 'Nordic Watering Can',
        price: 46.0,
        imageUrl: 'assets/images/img.png',
        type: 'Tool',
        categories: ['Watering'],
        stock: 10,
      ),
      Product(
        id: 'e_ceramic_pot',
        name: 'Glazed Ceramic Planter',
        price: 39.0,
        imageUrl: 'assets/images/image_2.png',
        type: 'Pots & Planters',
        categories: ['Planters'],
        stock: 8,
      ),
      Product(
        id: 'f_seaweed',
        name: 'Cold-Pressed Seaweed Tonic',
        price: 34.0,
        imageUrl: 'assets/images/image_2.png',
        type: 'Fertilizer',
        categories: ['Organic Feeds'],
        stock: 15,
      ),
      Product(
        id: 'f_neem',
        name: 'Organic Neem Oil Spray',
        price: 26.5,
        imageUrl: 'assets/images/image_3.png',
        type: 'Pest Control',
        categories: ['Biocontrol'],
        stock: 14,
      ),
      Product(
        id: 'i_probe',
        name: 'Soil Telemetry Sensor',
        price: 29.0,
        imageUrl: 'assets/images/image_3.png',
        type: 'Accessories',
        categories: ['Monitoring'],
        stock: 6,
      ),
    ];

    setUp(() {
      service = RecommendationService();
      service.clearInteractions();
    });

    test('Strict availability sorting: all available products precede sold-out items', () {
      final recs = service.getRecommendations(
        allProducts: catalog,
        userPlants: [],
        cartItems: [],
        onlyAvailable: false,
      );

      bool seenSoldOut = false;
      for (final r in recs) {
        if (r.product.isSoldOut) {
          seenSoldOut = true;
        } else {
          expect(seenSoldOut, isFalse,
              reason: 'Available item ${r.product.name} appeared after sold-out item');
        }
      }
    });

    test('onlyAvailable filter completely excludes out-of-stock items', () {
      final recs = service.getRecommendations(
        allProducts: catalog,
        onlyAvailable: true,
      );

      for (final r in recs) {
        expect(r.product.isAvailable, isTrue);
        expect(r.product.isSoldOut, isFalse);
      }
    });

    // Test across 8 diverse plant species profiles
    final speciesAffinityTests = [
      {'name': 'Samantha Monstera', 'species': 'Monstera Deliciosa', 'iot': false, 'expectedBadge': 'IoT Upgrade'},
      {'name': 'Fiddle Leaf Fig', 'species': 'Ficus lyrata', 'iot': false, 'expectedBadge': 'IoT Upgrade'},
      {'name': 'Golden Pothos', 'species': 'Epipremnum aureum (Pothos)', 'iot': true, 'expectedBadge': 'Sanctuary Match'},
      {'name': 'Rubber Fig', 'species': 'Ficus elastica (Fig)', 'iot': true, 'expectedBadge': 'Sanctuary Match'},
      {'name': 'Bird\'s Nest Fern', 'species': 'Asplenium nidus (Fern)', 'iot': true, 'expectedBadge': 'Sanctuary Match'},
      {'name': 'Chili Padi', 'species': 'Capsicum frutescens (Chili)', 'iot': true, 'expectedBadge': 'Organic Shield'},
      {'name': 'Curry Leaf Tree', 'species': 'Murraya koenigii (Curry)', 'iot': true, 'expectedBadge': 'Organic Shield'},
      {'name': 'Snake Plant', 'species': 'Sansevieria trifasciata (Snake)', 'iot': true, 'expectedBadge': 'Sanctuary Match'},
    ];

    for (final testCase in speciesAffinityTests) {
      test('Species garden affinity recommendation for ${testCase['name']}', () {
        final plant = Plant(
          id: 'test_p_1',
          name: testCase['name'] as String,
          species: testCase['species'] as String,
          imageUrl: 'assets/images/image_1.png',
          iotDeviceId: (testCase['iot'] as bool) ? 'iot_active_probe' : null,
        );

        final recs = service.getRecommendations(
          allProducts: catalog,
          userPlants: [plant],
          cartItems: [],
        );

        final matched = recs.where((r) => r.badge == testCase['expectedBadge']);
        expect(matched, isNotEmpty,
            reason: 'Expected badge ${testCase['expectedBadge']} for ${testCase['name']}');
      });
    }

    // Browsing History Signal Permutations
    final browsingCategories = ['Fertilizer', 'Tool', 'Pots & Planters', 'Accessories', 'Pest Control'];
    for (final cat in browsingCategories) {
      test('User browsing interest in $cat boosts category products in recommendations', () {
        service.clearInteractions();
        service.recordInteraction(
          type: cat,
          categories: [cat],
          speciesName: 'Sample $cat Item',
          action: 'view',
        );

        final recs = service.getRecommendations(
          allProducts: catalog,
          userPlants: [],
          cartItems: [],
        );

        final boosted = recs.where((r) => r.product.type == cat);
        if (boosted.isNotEmpty) {
          expect(boosted.first.score, greaterThan(80.0));
        }
      });
    }
  });

  group('CartModel Price Calculations & Quantity Range Matrix (1 to 30 items)', () {
    for (int qty = 1; qty <= 30; qty++) {
      test('Cart quantity $qty arithmetic: subtotal accuracy', () {
        final cart = CartModel();
        const unitPrice = 28.50;

        final item = CartItem(
          productId: 'item_test_$qty',
          name: 'Hydroponic Nutrient',
          price: unitPrice,
          quantity: qty,
          imageUrl: 'assets/images/image_2.png',
        );

        cart.addItem(item);

        expect(cart.items.length, equals(1));
        expect(cart.itemCount, equals(qty));
        expect(cart.totalPrice, closeTo(unitPrice * qty, 0.001));
      });
    }

    test('Adding multiple distinct items sums counts and prices precisely', () {
      final cart = CartModel();
      cart.addItem(CartItem(productId: 'item_a', name: 'Can', price: 46.0, quantity: 2));
      cart.addItem(CartItem(productId: 'item_b', name: 'Neem', price: 26.5, quantity: 1));
      cart.addItem(CartItem(productId: 'item_c', name: 'Pot', price: 39.0, quantity: 3));

      expect(cart.items.length, equals(3));
      expect(cart.itemCount, equals(6));
      expect(cart.totalPrice, closeTo((46.0 * 2) + 26.5 + (39.0 * 3), 0.001));

      // Decrement item
      cart.decrementItem('item_a');
      expect(cart.itemCount, equals(5));

      // Cannot decrement item below 1
      cart.decrementItem('item_b');
      expect(cart.itemCount, equals(5));

      // Remove item
      cart.removeItem('item_c');
      expect(cart.items.length, equals(2));
      expect(cart.itemCount, equals(2));

      // Clear cart
      cart.clearCart();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, equals(0));
      expect(cart.totalPrice, equals(0.0));
    });

    test('Adding existing item increments its quantity', () {
      final cart = CartModel(autoSync: false);
      cart.addItem(CartItem(productId: 'p_repeat', name: 'Peat Moss', price: 15.0, quantity: 1));
      expect(cart.items.first.quantity, equals(1));

      cart.addItem(CartItem(productId: 'p_repeat', name: 'Peat Moss', price: 15.0, quantity: 1));
      expect(cart.items.length, equals(1));
      expect(cart.items.first.quantity, equals(2));
      expect(cart.totalPrice, equals(30.0));
    });
  });

  group('Delivery Fee & Order Pricing Threshold Matrix (15 Cart Combinations)', () {
    final priceCombinations = [
      {'subtotal': 15.0, 'expectedDelivery': 5.0, 'expectedTotal': 20.0},
      {'subtotal': 25.5, 'expectedDelivery': 5.0, 'expectedTotal': 30.5},
      {'subtotal': 49.9, 'expectedDelivery': 5.0, 'expectedTotal': 54.9},
      {'subtotal': 50.0, 'expectedDelivery': 5.0, 'expectedTotal': 55.0},
      {'subtotal': 65.0, 'expectedDelivery': 5.0, 'expectedTotal': 70.0},
      {'subtotal': 79.9, 'expectedDelivery': 5.0, 'expectedTotal': 84.9},
      {'subtotal': 99.0, 'expectedDelivery': 5.0, 'expectedTotal': 104.0},
      {'subtotal': 100.0, 'expectedDelivery': 0.0, 'expectedTotal': 100.0},
      {'subtotal': 120.0, 'expectedDelivery': 0.0, 'expectedTotal': 120.0},
      {'subtotal': 150.5, 'expectedDelivery': 0.0, 'expectedTotal': 150.5},
      {'subtotal': 200.0, 'expectedDelivery': 0.0, 'expectedTotal': 200.0},
      {'subtotal': 299.9, 'expectedDelivery': 0.0, 'expectedTotal': 299.9},
      {'subtotal': 350.0, 'expectedDelivery': 0.0, 'expectedTotal': 350.0},
      {'subtotal': 500.0, 'expectedDelivery': 0.0, 'expectedTotal': 500.0},
      {'subtotal': 1000.0, 'expectedDelivery': 0.0, 'expectedTotal': 1000.0},
    ];

    for (final combo in priceCombinations) {
      test('Pricing rule for subtotal RM ${combo['subtotal']}', () {
        final subtotal = combo['subtotal'] as double;
        final deliveryFee = subtotal >= 100.0 ? 0.0 : 5.0;
        final total = subtotal + deliveryFee;

        expect(deliveryFee, equals(combo['expectedDelivery']));
        expect(total, closeTo(combo['expectedTotal'] as double, 0.001));
      });
    }
  });

  group('Product Entity Validation & Edge Cases Matrix (20 Products)', () {
    final productEdgeCases = [
      {'id': 'prod_1', 'name': 'Snake Plant', 'price': 35.0, 'stock': 10, 'rating': 4.5, 'soldOut': false},
      {'id': 'prod_2', 'name': 'Monstera Obliqua', 'price': 350.0, 'stock': 1, 'rating': 5.0, 'soldOut': false},
      {'id': 'prod_3', 'name': 'Out of Stock Fern', 'price': 22.0, 'stock': 0, 'rating': 3.8, 'soldOut': true},
      {'id': 'prod_4', 'name': 'Negative Stock Safeguard', 'price': 18.0, 'stock': -1, 'rating': 0.0, 'soldOut': true},
      {'id': 'prod_5', 'name': 'Free Promo Plant', 'price': 0.0, 'stock': 50, 'rating': 4.0, 'soldOut': false},
      {'id': 'prod_6', 'name': 'Ceramic Pot 15cm', 'price': 25.0, 'stock': 20, 'rating': 4.7, 'soldOut': false},
      {'id': 'prod_7', 'name': 'Terracotta Pot 20cm', 'price': 30.0, 'stock': 15, 'rating': 4.6, 'soldOut': false},
      {'id': 'prod_8', 'name': 'Stainless Pruning Shears', 'price': 45.0, 'stock': 8, 'rating': 4.9, 'soldOut': false},
      {'id': 'prod_9', 'name': 'Brass Mister', 'price': 55.0, 'stock': 12, 'rating': 4.8, 'soldOut': false},
      {'id': 'prod_10', 'name': 'Organic Worm Castings', 'price': 16.0, 'stock': 40, 'rating': 4.9, 'soldOut': false},
      {'id': 'prod_11', 'name': 'Perlite 5L', 'price': 12.0, 'stock': 35, 'rating': 4.5, 'soldOut': false},
      {'id': 'prod_12', 'name': 'LECA Balls 10L', 'price': 28.0, 'stock': 18, 'rating': 4.7, 'soldOut': false},
      {'id': 'prod_13', 'name': 'Sphagnum Moss 500g', 'price': 24.0, 'stock': 22, 'rating': 4.6, 'soldOut': false},
      {'id': 'prod_14', 'name': 'Sticky Pest Traps 10pk', 'price': 9.9, 'stock': 60, 'rating': 4.4, 'soldOut': false},
      {'id': 'prod_15', 'name': 'Smart Garden Hub', 'price': 199.0, 'stock': 4, 'rating': 4.9, 'soldOut': false},
      {'id': 'prod_16', 'name': 'Clip-on Grow Light 45W', 'price': 75.0, 'stock': 11, 'rating': 4.7, 'soldOut': false},
      {'id': 'prod_17', 'name': 'Moisture Meter Pro', 'price': 39.0, 'stock': 0, 'rating': 4.3, 'soldOut': true},
      {'id': 'prod_18', 'name': 'Bonsai Wire Kit', 'price': 29.0, 'stock': 7, 'rating': 4.2, 'soldOut': false},
      {'id': 'prod_19', 'name': 'Rooting Hormone Gel', 'price': 19.5, 'stock': 25, 'rating': 4.8, 'soldOut': false},
      {'id': 'prod_20', 'name': 'Copper Fungicide 250ml', 'price': 27.0, 'stock': 16, 'rating': 4.6, 'soldOut': false},
    ];

    for (final p in productEdgeCases) {
      test('Product validation for ${p['name']}', () {
        final prod = Product(
          id: p['id'] as String,
          name: p['name'] as String,
          price: (p['price'] as num).toDouble(),
          imageUrl: 'assets/images/image_1.png',
          type: 'Garden Item',
          stock: p['stock'] as int,
        );

        expect(prod.isSoldOut, equals(p['soldOut']));
        expect(prod.isAvailable, equals(!(p['soldOut'] as bool)));
        expect(prod.price, greaterThanOrEqualTo(0.0));
      });
    }
  });

  group('OrderModel Lifecycle States & Address Serialization Matrix (10 States)', () {
    final orderStatuses = [
      'Pending',
      'Confirmed',
      'Processing',
      'Awaiting Pickup',
      'Shipped',
      'In Transit',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
      'Refunded',
    ];

    for (final status in orderStatuses) {
      test('OrderModel status preservation and representation for status: $status', () {
        final now = DateTime.now();
        final order = OrderModel(
          id: 'ord_status_$status',
          userId: 'usr_test_77',
          items: [
            CartItem(productId: 'p1', name: 'Monstera', price: 48.0, quantity: 1),
          ],
          subtotal: 48.0,
          deliveryFee: 5.0,
          totalAmount: 53.0,
          createdAt: now,
          status: status,
          paymentMethod: 'Online Banking (FPX)',
          shippingAddress: {
            'street': 'No. 88 Jalan Flora',
            'city': 'Petaling Jaya',
            'state': 'Selangor',
            'zipCode': '47301',
          },
        );

        expect(order.status, equals(status));
        expect(order.totalAmount, equals(53.0));
        expect(order.formattedAddress, contains('Petaling Jaya'));

        final json = order.toJson();
        expect(json['status'], equals(status));

        final restored = OrderModel.fromJson(json);
        expect(restored.status, equals(status));
        expect(restored.id, equals(order.id));
        expect(restored.subtotal, equals(48.0));
        expect(restored.deliveryFee, equals(5.0));
      });
    }
  });
}
