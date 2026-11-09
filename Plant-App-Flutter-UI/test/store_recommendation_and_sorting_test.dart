import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/screens/shop/plant_ecommerce_screen.dart';
import 'package:urbangreen/services/recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product Model Stock & Availability Tests', () {
    test('isAvailable and isSoldOut reflect stock count accurately', () {
      final inStockProduct = Product(
        id: 'p1',
        name: 'Monstera Deliciosa',
        price: 48.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        stock: 5,
      );
      expect(inStockProduct.isAvailable, isTrue);
      expect(inStockProduct.isSoldOut, isFalse);

      final outOfStockProduct = Product(
        id: 'p2',
        name: 'Variegated Monstera Albo',
        price: 188.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        stock: 0,
      );
      expect(outOfStockProduct.isAvailable, isFalse);
      expect(outOfStockProduct.isSoldOut, isTrue);

      final negativeStockProduct = Product(
        id: 'p3',
        name: 'Negative Stock Item',
        price: 10.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        stock: -1,
      );
      expect(negativeStockProduct.isAvailable, isFalse);
      expect(negativeStockProduct.isSoldOut, isTrue);
    });
  });

  group('RecommendationService Engine Tests', () {
    late RecommendationService recService;

    final mockProducts = [
      Product(
        id: 'p_monstera',
        name: 'Monstera Deliciosa',
        price: 48.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        categories: ['Indoor', 'Tropical Foliage'],
        stock: 10,
      ),
      Product(
        id: 'p_soldout_albo',
        name: 'Monstera Albo',
        price: 200.0,
        imageUrl: 'assets/images/image_1.png',
        type: 'Plant',
        categories: ['Rare Specimen'],
        stock: 0,
      ),
      Product(
        id: 'e_can',
        name: 'Nordic Watering Can',
        price: 46.0,
        imageUrl: 'assets/images/img.png',
        type: 'Tool',
        categories: ['Watering'],
        stock: 8,
      ),
      Product(
        id: 'e_pot',
        name: 'Minimalist Ceramic Pot',
        price: 39.0,
        imageUrl: 'assets/images/image_2.png',
        type: 'Pots & Planters',
        categories: ['Planters'],
        stock: 12,
      ),
      Product(
        id: 'f_seaweed',
        name: 'Seaweed Fertilizer Booster',
        price: 34.0,
        imageUrl: 'assets/images/image_2.png',
        type: 'Fertilizer',
        categories: ['Organic Feeds'],
        stock: 15,
      ),
      Product(
        id: 'f_neem',
        name: 'Cold-Pressed Neem Oil Spray',
        price: 26.5,
        imageUrl: 'assets/images/image_3.png',
        type: 'Pest Control',
        categories: ['Biocontrol'],
        stock: 14,
      ),
      Product(
        id: 'i_probe',
        name: 'Soil Hydration & pH Probe',
        price: 29.0,
        imageUrl: 'assets/images/image_3.png',
        type: 'Accessories',
        categories: ['Monitoring'],
        stock: 6,
      ),
    ];

    setUp(() {
      recService = RecommendationService();
      recService.clearInteractions();
    });

    test('Available products are strictly placed ahead of sold-out products', () {
      final recs = recService.getRecommendations(
        allProducts: mockProducts,
        userPlants: [],
        cartItems: [],
        onlyAvailable: false,
      );

      expect(recs.isNotEmpty, isTrue);

      // Verify that all available items appear before any sold-out item
      bool foundSoldOut = false;
      for (final rec in recs) {
        if (rec.product.isSoldOut) {
          foundSoldOut = true;
        } else {
          // If we encounter an available item AFTER finding a sold-out one, fail
          expect(foundSoldOut, isFalse,
              reason: 'Available item ${rec.product.name} appeared after sold-out item');
        }
      }
    });

    test('onlyAvailable filter completely excludes out-of-stock items', () {
      final recs = recService.getRecommendations(
        allProducts: mockProducts,
        userPlants: [],
        cartItems: [],
        onlyAvailable: true,
      );

      expect(recs.any((r) => r.product.isSoldOut), isFalse);
      expect(recs.any((r) => r.product.id == 'p_soldout_albo'), isFalse);
    });

    test('Recommends IoT sensor upgrades when user has unmonitored garden specimens', () {
      final userPlants = [
        Plant(
          id: 'plant_1',
          name: 'Snake Plant',
          species: 'Sansevieria trifasciata',
          imageUrl: 'assets/images/image_2.png',
          iotDeviceId: null, // Unmonitored specimen
        ),
      ];

      final recs = recService.getRecommendations(
        allProducts: mockProducts,
        userPlants: userPlants,
        cartItems: [],
      );

      final iotRec = recs.firstWhere((r) => r.product.id == 'i_probe');
      expect(iotRec.badge, equals('IoT Upgrade'));
      expect(iotRec.reason, contains('Snake Plant'));
    });

    test('Recommends ceramic pots and fertilizers when cart contains plants', () {
      final cartItems = [
        CartItem(
          productId: 'p_monstera',
          name: 'Monstera Deliciosa',
          price: 48.0,
          imageUrl: 'assets/images/image_1.png',
        ),
      ];

      final recs = recService.getRecommendations(
        allProducts: mockProducts,
        userPlants: [],
        cartItems: cartItems,
      );

      final potRec = recs.firstWhere((r) => r.product.id == 'e_pot');
      expect(potRec.badge, equals('Pairs with Cart'));
      expect(potRec.reason, contains('cart'));
    });

    test('Records user interactions and boosts matching categories', () {
      recService.recordInteraction(
        type: 'Fertilizer',
        categories: ['Organic Feeds'],
        speciesName: 'Seaweed Fertilizer Booster',
        action: 'view',
      );

      final interactions = recService.getRecentInteractions();
      expect(interactions.isNotEmpty, isTrue);
      expect(interactions.first['type'], equals('Fertilizer'));

      final recs = recService.getRecommendations(
        allProducts: mockProducts,
        userPlants: [],
        cartItems: [],
      );

      final fertilizerRec = recs.firstWhere((r) => r.product.id == 'f_seaweed');
      expect(fertilizerRec.score, greaterThan(80.0));
    });
  });

  group('UrbanGreen Store Screen Widget Tests', () {
    testWidgets('Renders UrbanGreen Store with 5 tabs including Recommended',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartModel(),
          child: const MaterialApp(
            home: PlantEcommerceScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify Title
      expect(find.text('UrbanGreen Store'), findsOneWidget);

      // Verify the 5 Capsule Tabs
      expect(find.textContaining('Recommended'), findsOneWidget);
      expect(find.textContaining('Plants'), findsOneWidget);
      expect(find.textContaining('Tools'), findsOneWidget);
      expect(find.textContaining('Care'), findsOneWidget);
      expect(find.textContaining('Grow Tech'), findsOneWidget);

      // Verify Stock toggle filter
      expect(find.textContaining('Available First'), findsOneWidget);

      // Tap filter toggle chip to switch to In-Stock Only
      await tester.tap(find.textContaining('Available First'));
      await tester.pumpAndSettle();

      expect(find.text('In-Stock Only'), findsOneWidget);
    });
  });
}
