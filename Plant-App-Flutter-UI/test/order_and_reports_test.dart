import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/order_model.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/order_service.dart';

void main() {
  group('OrderModel & OrderService Tests (Pure Firebase Cloud Firestore)', () {
    test('OrderModel toJson and fromJson roundtrip correctly', () {
      final now = DateTime.now();
      final order = OrderModel(
        id: 'ord_test_123',
        userId: 'user_456',
        items: [
          CartItem(
            productId: 'item_1',
            name: 'Monstera Deliciosa',
            price: 29.99,
            quantity: 2,
            imageUrl: 'assets/images/image_1.png',
          ),
        ],
        subtotal: 59.98,
        deliveryFee: 5.0,
        totalAmount: 64.98,
        createdAt: now,
        status: 'Processing',
        shippingAddress: {
          'street': '123 Flora Way',
          'city': 'Botanical City',
          'state': 'Selangor',
          'zipCode': '63000',
        },
        paymentMethod: 'Credit Card',
      );

      final json = order.toJson();
      expect(json['id'], 'ord_test_123');
      expect(json['userId'], 'user_456');
      expect(json['totalAmount'], 64.98);
      expect((json['items'] as List).length, 1);
      expect(order.formattedAddress.contains('123 Flora Way'), true);

      final reconstructed = OrderModel.fromJson(json);
      expect(reconstructed.id, 'ord_test_123');
      expect(reconstructed.items.first.name, 'Monstera Deliciosa');
      expect(reconstructed.status, 'Processing');
      expect(reconstructed.totalItemCount, 2);

      final map = reconstructed.toMap();
      expect(map['id'], 'ord_test_123');
      expect(map['userId'], 'user_456');
    });

    test('OrderService creates demo sample order with valid ID', () async {
      final orderService = OrderService();
      final orderId = await orderService.createSampleOrder('test_user');

      expect(orderId.startsWith('UG-'), true);
      expect(orderId.length, greaterThan(5));
    });

    test('OrderService formatDatabaseError provides clear human feedback', () {
      final permError = OrderService.formatDatabaseError('FirebaseException: permission-denied');
      expect(permError.contains('permission denied'), true);

      final networkError = OrderService.formatDatabaseError('SocketException: network unavailable');
      expect(networkError.contains('internet connection'), true);
    });
  });

  group('CareLogService & Hydration Analytics Tests', () {
    test('CareLogService seeds starter logs and calculates total weekly volume', () async {
      final careLogService = CareLogService();
      await careLogService.init();

      expect(careLogService.wateringLogs.isNotEmpty, true);
      final weeklyVol = careLogService.totalWeeklyVolumeMl;
      expect(weeklyVol, greaterThan(0));

      final weeklyDays = careLogService.getWeeklyHydrationByDay();
      expect(weeklyDays.containsKey('Mon'), true);
      expect(weeklyDays.containsKey('Sun'), true);

      final list = careLogService.getWeeklyHydrationList();
      expect(list.length, 7);
    });

    test('CareLogService logWatering adds entry and updates volume immediately', () async {
      final careLogService = CareLogService();
      final initialCount = careLogService.wateringLogs.length;
      final initialVol = careLogService.totalWeeklyVolumeMl;

      await careLogService.logWatering(
        plantId: 'plant_99',
        plantName: 'Test Ficus',
        species: 'Ficus Elastica',
        imageUrl: 'assets/images/image_1.png',
        volumeMl: 300,
        careMode: 'Hardware Pump Pulse',
        moistureBeforePct: 20,
        moistureAfterPct: 70,
        notes: 'Automated test hydration',
      );

      expect(careLogService.wateringLogs.length, initialCount + 1);
      expect(careLogService.totalWeeklyVolumeMl, initialVol + 300);

      final latest = careLogService.lastWateringEvent;
      expect(latest, isNotNull);
      expect(latest!.plantName, 'Test Ficus');
      expect(latest.amountMl, 300);
      expect(latest.mode, 'Hardware Pump Pulse');
      expect(latest.notes, 'Automated test hydration');
    });
  });
}
