import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/user_model.dart';
import 'package:urbangreen/screens/address/address_screen.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/shop/checkout_screen.dart';
import 'package:urbangreen/services/auth_service.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';
import 'package:urbangreen/services/plant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UrbanGreen Guest Mode & Storage Flag Tests', () {
    test('Guest mode defaults to false or empty', () {
      WebHardwareBridge.saveStorage('is_guest_mode', 'false');
      expect(AuthService.isGuestMode, false);
    });

    test('AuthService.setGuestMode toggles flag in persistent storage', () {
      AuthService.setGuestMode(true);
      expect(AuthService.isGuestMode, true);
      expect(WebHardwareBridge.loadStorage('is_guest_mode'), 'true');

      AuthService.setGuestMode(false);
      expect(AuthService.isGuestMode, false);
      expect(WebHardwareBridge.loadStorage('is_guest_mode'), 'false');
    });

    test('CartModel operates smoothly without authenticated user in Guest Mode', () {
      final cart = CartModel();
      expect(cart.items, isEmpty);
      expect(cart.totalPrice, 0.0);
      expect(cart.itemCount, 0);

      // Guest adds items to cart
      final item = CartItem(
        productId: 'guest_probe_1',
        name: 'Smart Soil Moisture Sensor V2',
        price: 24.50,
        quantity: 1,
        imageUrl: 'assets/images/image_1.png',
      );
      cart.addItem(item);

      expect(cart.itemCount, 1);
      expect(cart.totalPrice, 24.50);
      expect(cart.items.first.name, 'Smart Soil Moisture Sensor V2');

      // Clear cart
      cart.clearCart();
      expect(cart.items, isEmpty);
    });

    test('PlantService adds and manages specimens in Guest Mode without Firebase Auth', () {
      final plantService = PlantService();
      final initialCount = plantService.myPlants.length;

      final testGuestPlant = Plant(
        id: 'guest_plant_999',
        name: 'Pandan Heritage',
        species: 'Pandan',
        description: 'Fragrant Pandan specimen in guest mode.',
        imageUrl: 'assets/images/pandan.png',
        soilType: 'Loamy',
      );

      plantService.addPlant(testGuestPlant);
      expect(plantService.myPlants.length, initialCount + 1);
      expect(plantService.getPlantById('guest_plant_999')?.name, 'Pandan Heritage');

      // Clean up
      plantService.deletePlant('guest_plant_999');
      expect(plantService.getPlantById('guest_plant_999'), isNull);
    });
  });

  group('UrbanGreen UserModel & Address Architecture Tests', () {
    test('UserModel serializes and deserializes correctly', () {
      final user = UserModel(
        uid: 'ug_test_uid_777',
        email: 'botanist@urbangreen.com',
        username: 'UrbanBotanist',
        photoUrl: 'https://storage.urbangreen.com/profiles/ug_test_uid_777.jpg',
      );

      final map = user.toMap();
      expect(map['uid'], 'ug_test_uid_777');
      expect(map['email'], 'botanist@urbangreen.com');
      expect(map['username'], 'UrbanBotanist');
      expect(map['photoUrl'], contains('ug_test_uid_777.jpg'));

      final reconstructed = UserModel.fromMap(map, 'ug_test_uid_777');
      expect(reconstructed.uid, 'ug_test_uid_777');
      expect(reconstructed.username, 'UrbanBotanist');
      expect(reconstructed.email, 'botanist@urbangreen.com');
    });

    test('Address model serializes and handles default address flags', () {
      final address = Address(
        id: 'addr_1',
        street: 'No. 12 Jalan Daun Pandan',
        city: 'Kuala Lumpur',
        state: 'Wilayah Persekutuan',
        zipCode: '50000',
        isDefault: true,
      );

      final map = address.toMap();
      expect(map['street'], 'No. 12 Jalan Daun Pandan');
      expect(map['city'], 'Kuala Lumpur');
      expect(map['isDefault'], true);
      expect(map['state'], 'Wilayah Persekutuan');

      final reconstructed = Address.fromMap(map, 'addr_1');
      expect(reconstructed.id, 'addr_1');
      expect(reconstructed.street, 'No. 12 Jalan Daun Pandan');
      expect(reconstructed.zipCode, '50000');
    });
  });

  group('UrbanGreen Account Deletion Validation Tests', () {
    test('AuthService.deleteAccount throws when no user session is active', () async {
      final authService = AuthService();
      // In unit test without mock user signed in, currentUser is null
      expect(
        () async => await authService.deleteAccount(),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'no-current-user',
        )),
      );
    });
  });

  group('UrbanGreen Guest UI Navigation & Prompts Widget Tests', () {
    testWidgets('LoginScreen renders "Continue as Guest" and "Sign In" buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Sign In to UrbanGreen'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Autofill Demo Test Account'), findsOneWidget);
    });

    testWidgets('CheckoutScreen displays account required card for unauthenticated guest', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<CartModel>(
          create: (_) => CartModel(),
          child: const MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );

      expect(find.text('Account Required for Checkout'), findsOneWidget);
      expect(find.text('Sign In or Register'), findsOneWidget);
    });

    testWidgets('AddressScreen displays account required card for unauthenticated guest', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddressScreen(),
        ),
      );

      expect(find.text('Account Required'), findsOneWidget);
      expect(find.text('Sign In or Register'), findsOneWidget);
    });
  });
}
