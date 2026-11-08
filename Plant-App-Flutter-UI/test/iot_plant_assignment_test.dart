import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/low_moisture_decision_service.dart';
import 'package:urbangreen/services/plant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plant Model 1-to-1 IoT Link & Botanical Care Tests', () {
    test('Plant model preserves iotDeviceId in toJson and fromJson', () {
      final plant = Plant(
        id: 'test-1',
        name: 'Monstera Test',
        species: 'Monstera deliciosa',
        imageUrl: 'assets/images/image_1.png',
        description: 'Test description',
        iotDeviceId: 'SmartPlant-ESP32',
      );

      final json = plant.toJson();
      expect(json['iotDeviceId'], 'SmartPlant-ESP32');
      expect(plant.hasIot, isTrue);

      final reconstructed = Plant.fromJson(json);
      expect(reconstructed.id, 'test-1');
      expect(reconstructed.name, 'Monstera Test');
      expect(reconstructed.iotDeviceId, 'SmartPlant-ESP32');
      expect(reconstructed.hasIot, isTrue);
    });

    test('Plant without IoT correctly reflects hasIot == false and generic defaults', () {
      final cactus = Plant(
        id: 'cactus-1',
        name: 'Prickly Pear',
        species: 'Opuntia Cactus',
        imageUrl: 'assets/images/image_1.png',
      );

      expect(cactus.hasIot, isFalse);
      expect(cactus.iotDeviceId, isNull);
      expect(cactus.reminderEnabled, isFalse);
      expect(cactus.reminderStatusText, 'No notification setup');
      expect(cactus.nextWateringDate, isNull);
      expect(cactus.isWateringDue, isFalse);
      expect(cactus.wateringScheduleSummary, 'No reminder set');
      // Cactus default interval is 14 days
      expect(cactus.wateringIntervalDays, 14);
      expect(cactus.sunlight.toLowerCase().contains('sun'), isTrue);
      expect(cactus.petToxicity.isNotEmpty, isTrue);
      expect(cactus.soilType.toLowerCase().contains('cactus'), isTrue);
    });

    test('Plant copyWith handles iotDeviceId, clearIotDevice and reminder configuration', () {
      final plant = Plant(
        id: 'test-2',
        name: 'Ficus',
        species: 'Ficus lyrata',
        imageUrl: 'assets/images/image_2.png',
        iotDeviceId: 'SmartPlant-ESP32',
        wateringIntervalDays: 7,
      );

      expect(plant.hasIot, isTrue);

      // Reassign to new device
      final updated = plant.copyWith(iotDeviceId: 'ESP32-PROBE-02');
      expect(updated.iotDeviceId, 'ESP32-PROBE-02');
      expect(updated.hasIot, isTrue);

      // Clear device -> hasIot must be FALSE immediately
      final cleared = updated.copyWith(clearIotDevice: true);
      expect(cleared.iotDeviceId, isNull);
      expect(cleared.hasIot, isFalse);

      // Set customized reminder
      final withReminder = cleared.copyWith(
        wateringIntervalDays: 3,
        reminderTime: '10:30 AM',
        reminderEnabled: true,
        lastWatered: DateTime.now(),
      );
      expect(withReminder.wateringIntervalDays, 3);
      expect(withReminder.reminderTime, '10:30 AM');
      expect(withReminder.reminderEnabled, isTrue);
      expect(withReminder.hasIot, isFalse);
    });

    test('Watering schedule calculations for nextWateringDate and isWateringDue', () {
      final now = DateTime.now();
      // Plant watered 8 days ago with a 4-day interval and reminder enabled is OVERDUE
      final overduePlant = Plant(
        id: 'overdue-1',
        name: 'Wilting Fern',
        species: 'Boston Fern',
        imageUrl: 'assets/images/image_2.png',
        wateringIntervalDays: 4,
        lastWatered: now.subtract(const Duration(days: 8)),
        reminderEnabled: true,
      );

      expect(overduePlant.isWateringDue, isTrue);
      expect(overduePlant.wateringScheduleSummary.contains('Overdue'), isTrue);

      // Plant watered today with 5-day interval and reminder enabled is NOT due
      final freshPlant = Plant(
        id: 'fresh-1',
        name: 'Fresh Pothos',
        species: 'Epipremnum aureum',
        imageUrl: 'assets/images/image_3.png',
        wateringIntervalDays: 5,
        lastWatered: now,
        reminderEnabled: true,
      );

      expect(freshPlant.isWateringDue, isFalse);
      expect(freshPlant.wateringScheduleSummary.contains('Due in'), isTrue);
    });
  });

  group('PlantService Strict 1-to-1 IoT Assignment Invariant Tests', () {
    final plantService = PlantService();

    setUp(() {
      // Clean test plants
      final plants = plantService.myPlants;
      for (final p in plants) {
        plantService.unassignDeviceFromPlant(p.id);
      }
    });

    test('assignDeviceToPlant enforces exactly 1 device to 1 plant', () {
      final plants = plantService.myPlants;
      expect(plants.length, greaterThanOrEqualTo(2));

      final plant1 = plants[0];
      final plant2 = plants[1];
      const deviceId = 'SmartPlant-ESP32';

      // Step 1: Assign deviceId to Plant 1
      plantService.assignDeviceToPlant(plantId: plant1.id, deviceId: deviceId);
      expect(plantService.getPlantForDevice(deviceId)?.id, plant1.id);
      expect(plantService.getPlantById(plant1.id)?.iotDeviceId, deviceId);
      expect(plantService.getPlantById(plant1.id)?.hasIot, isTrue);
      expect(plantService.getPlantById(plant2.id)?.iotDeviceId, isNull);
      expect(plantService.getPlantById(plant2.id)?.hasIot, isFalse);
      expect(plantService.isDeviceAssigned(deviceId), isTrue);

      // Step 2: Now assign the SAME deviceId to Plant 2
      // Plant 1 MUST be automatically unassigned!
      plantService.assignDeviceToPlant(plantId: plant2.id, deviceId: deviceId);
      expect(plantService.getPlantForDevice(deviceId)?.id, plant2.id);
      expect(plantService.getPlantById(plant2.id)?.iotDeviceId, deviceId);
      expect(plantService.getPlantById(plant2.id)?.hasIot, isTrue);
      expect(plantService.getPlantById(plant1.id)?.iotDeviceId, isNull,
          reason: 'Plant 1 must have its probe revoked when probe is assigned to Plant 2');
      expect(plantService.getPlantById(plant1.id)?.hasIot, isFalse);

      // Step 3: Unassign device from Plant 2 -> IoT feature removed
      plantService.unassignDeviceFromPlant(plant2.id);
      expect(plantService.getPlantForDevice(deviceId), isNull);
      expect(plantService.getPlantById(plant2.id)?.iotDeviceId, isNull);
      expect(plantService.getPlantById(plant2.id)?.hasIot, isFalse);
      expect(plantService.isDeviceAssigned(deviceId), isFalse);
    });

    test('unassignDevice clears probe from whatever plant holds it', () {
      final plants = plantService.myPlants;
      final plant1 = plants[0];
      const deviceId = 'ESP32-NODE-SPECIAL';

      plantService.assignDeviceToPlant(plantId: plant1.id, deviceId: deviceId);
      expect(plantService.getPlantById(plant1.id)?.iotDeviceId, deviceId);
      expect(plantService.getPlantById(plant1.id)?.hasIot, isTrue);

      plantService.unassignDevice(deviceId);
      expect(plantService.getPlantById(plant1.id)?.iotDeviceId, isNull);
      expect(plantService.getPlantById(plant1.id)?.hasIot, isFalse);
      expect(plantService.getPlantForDevice(deviceId), isNull);
    });

    test('monitoredPlantsCount accurately counts monitored specimens', () {
      final plants = plantService.myPlants;
      expect(plants.length, greaterThanOrEqualTo(3));

      expect(plantService.monitoredPlantsCount, 0);

      plantService.assignDeviceToPlant(plantId: plants[0].id, deviceId: 'DEV-1');
      expect(plantService.monitoredPlantsCount, 1);

      plantService.assignDeviceToPlant(plantId: plants[1].id, deviceId: 'DEV-2');
      expect(plantService.monitoredPlantsCount, 2);

      // Reassigning DEV-1 to plants[2] doesn't increase count because DEV-1 moves from plants[0]
      plantService.assignDeviceToPlant(plantId: plants[2].id, deviceId: 'DEV-1');
      expect(plantService.monitoredPlantsCount, 2);
      expect(plantService.getPlantById(plants[0].id)?.iotDeviceId, isNull);
      expect(plantService.getPlantById(plants[2].id)?.iotDeviceId, 'DEV-1');
    });

    test('added plant persists across app restart in init()', () async {
      final cactus = Plant(
        id: 'cactus-999',
        name: 'My Golden Barrel Cactus',
        species: 'Echinocactus grusonii',
        imageUrl: 'assets/images/image_1.png',
        description: 'Desert succulent requiring sparse watering and full sunlight.',
        wateringIntervalDays: 14,
      );

      plantService.addPlant(cactus);
      expect(plantService.myPlants.any((p) => p.id == 'cactus-999'), isTrue);

      // Simulate re-init / app reboot
      await plantService.init();
      expect(plantService.myPlants.any((p) => p.id == 'cactus-999'), isTrue);
      final retrieved = plantService.getPlantById('cactus-999');
      expect(retrieved?.name, 'My Golden Barrel Cactus');
      expect(retrieved?.species, 'Echinocactus grusonii');
      expect(retrieved?.hasIot, isFalse);
      expect(retrieved?.wateringIntervalDays, 14);
    });
  });

  group('Low Moisture Alerts & Ignore Decision Tests', () {
    test('IotDevice low moisture notification defaults and serialization roundtrip', () {
      final device = IotDevice(
        id: 'ESP32-TEST-1',
        name: 'Hydro Probe 1',
        moistureLevel: 0.18,
      );

      expect(device.lowMoistureAlertEnabled, isTrue);
      expect(device.lowMoistureThreshold, 25);
      expect(device.lowMoistureIgnoredUntil, isNull);
      expect(device.lowMoistureAlwaysIgnored, isFalse);
      expect(device.isLowMoistureAlertIgnored, isFalse);
      expect(device.lowMoistureIgnoreStatusText.contains('Active'), isTrue);

      final map = device.toMap();
      expect(map['lowMoistureAlertEnabled'], isTrue);
      expect(map['lowMoistureThreshold'], 25);

      final reconstructed = IotDevice.fromMap(map);
      expect(reconstructed.id, 'ESP32-TEST-1');
      expect(reconstructed.lowMoistureAlertEnabled, isTrue);
      expect(reconstructed.lowMoistureThreshold, 25);
      expect(reconstructed.isLowMoistureAlertIgnored, isFalse);
    });

    test('IotDevice ignore options: 1 hour, 1 day, 1 week, 1 month, always', () {
      final device = IotDevice(id: 'ESP32-SNOOZE', name: 'Snooze Device');

      // 1 Hour
      device.ignoreAlertFor(const Duration(hours: 1));
      expect(device.isLowMoistureAlertIgnored, isTrue);
      expect(device.lowMoistureAlwaysIgnored, isFalse);
      expect(device.lowMoistureIgnoredUntil != null, isTrue);
      expect(device.lowMoistureIgnoreStatusText.contains('Ignored for'), isTrue);

      // 1 Day
      device.ignoreAlertFor(const Duration(days: 1));
      expect(device.isLowMoistureAlertIgnored, isTrue);
      expect(device.lowMoistureIgnoreStatusText.contains('1d'), isTrue);

      // 1 Week
      device.ignoreAlertFor(const Duration(days: 7));
      expect(device.isLowMoistureAlertIgnored, isTrue);
      expect(device.lowMoistureIgnoreStatusText.contains('1w'), isTrue);

      // 1 Month
      device.ignoreAlertFor(const Duration(days: 30));
      expect(device.isLowMoistureAlertIgnored, isTrue);
      expect(device.lowMoistureIgnoreStatusText.contains('w'), isTrue);

      // Always
      device.ignoreAlertAlways();
      expect(device.lowMoistureAlwaysIgnored, isTrue);
      expect(device.lowMoistureIgnoredUntil, isNull);
      expect(device.isLowMoistureAlertIgnored, isTrue);
      expect(device.lowMoistureIgnoreStatusText.contains('Always Ignored'), isTrue);

      // Reset
      device.resetAlertIgnore();
      expect(device.lowMoistureAlwaysIgnored, isFalse);
      expect(device.lowMoistureIgnoredUntil, isNull);
      expect(device.isLowMoistureAlertIgnored, isFalse);
      expect(device.lowMoistureIgnoreStatusText.contains('Active'), isTrue);
    });

    test('Low moisture alerts do NOT apply in Auto Watering mode, only in Manual mode', () async {
      final autoDevice = IotDevice(
        id: 'ESP32-AUTO',
        name: 'Auto Water Probe',
        autoWaterEnabled: true,
        lowMoistureAlertEnabled: true,
        lowMoistureThreshold: 25,
      );

      final decisionService = LowMoistureDecisionService();
      decisionService.activeAlertNotifier.value = null;

      // In Auto mode: does not trigger decision alert
      await decisionService.dispatchLowMoistureAlert(
        device: autoDevice,
        currentMoisture: 15,
      );
      expect(decisionService.activeAlertNotifier.value, isNull);

      // In Manual mode with alert disabled: does not trigger
      final manualDisabledDevice = IotDevice(
        id: 'ESP32-MANUAL-OFF',
        name: 'Manual Disabled Probe',
        autoWaterEnabled: false,
        lowMoistureAlertEnabled: false,
        lowMoistureThreshold: 25,
      );
      await decisionService.dispatchLowMoistureAlert(
        device: manualDisabledDevice,
        currentMoisture: 15,
      );
      expect(decisionService.activeAlertNotifier.value, isNull);

      // In Manual mode with alert enabled: triggers decision alert!
      final manualEnabledDevice = IotDevice(
        id: 'ESP32-MANUAL-ON',
        name: 'Manual Enabled Probe',
        autoWaterEnabled: false,
        lowMoistureAlertEnabled: true,
        lowMoistureThreshold: 25,
      );
      await decisionService.dispatchLowMoistureAlert(
        device: manualEnabledDevice,
        currentMoisture: 15,
        force: true,
      );
      expect(decisionService.activeAlertNotifier.value != null, isTrue);
      expect(decisionService.activeAlertNotifier.value?.moisture, 15);
      expect(decisionService.activeAlertNotifier.value?.device.id, 'ESP32-MANUAL-ON');
    });
  });

  group('Devices & Hub Hub List & Details Network Configuration Tests', () {
    test('IotHybridConnectivityService manages connected devices and notifies listeners', () async {
      final service = IotHybridConnectivityService();

      final testDevice = IotDevice(
        id: 'ESP32-NEW-PROBE',
        name: 'Balcony Orchid Probe',
        isWifiConnected: false,
        wifiSsid: null,
      );

      bool notified = false;
      void listener() {
        notified = true;
      }

      service.connectedDevicesNotifier.addListener(listener);

      await service.connectIotDevice(testDevice);

      expect(service.connectedIotDevices.any((d) => d.id == 'ESP32-NEW-PROBE'), isTrue);
      expect(notified, isTrue);

      // Verify network update in details configuration
      testDevice.wifiSsid = 'Orchid-Garden-2.4G';
      testDevice.isWifiConnected = true;
      await service.connectIotDevice(testDevice);

      final updated = service.connectedIotDevices.firstWhere((d) => d.id == 'ESP32-NEW-PROBE');
      expect(updated.isWifiConnected, isTrue);
      expect(updated.wifiSsid, 'Orchid-Garden-2.4G');

      // Unlink
      await service.removeIotDevice('ESP32-NEW-PROBE');
      expect(service.connectedIotDevices.any((d) => d.id == 'ESP32-NEW-PROBE'), isFalse);

      service.connectedDevicesNotifier.removeListener(listener);
    });

    test('IotDevice handles Wi-Fi credentials validation properly', () {
      final valid = IotHybridConnectivityService.validateWifiCredentials('HomeNetwork', '12345678');
      expect(valid.isSuccess, isTrue);

      final emptySsid = IotHybridConnectivityService.validateWifiCredentials('', '12345678');
      expect(emptySsid.isSuccess, isFalse);
      expect(emptySsid.message.contains('empty'), isTrue);

      final shortPass = IotHybridConnectivityService.validateWifiCredentials('HomeNetwork', '1234');
      expect(shortPass.isSuccess, isFalse);
      expect(shortPass.message.contains('8 characters'), isTrue);
    });

    test('IotHybridConnectivityService switches watering mode and syncs device state', () async {
      final service = IotHybridConnectivityService();

      // Set to manual mode
      final manualRes = await service.setWateringMode(false);
      expect(manualRes.isSuccess, isTrue);
      expect(service.connectedIotDevices.every((d) => !d.autoWaterEnabled), isTrue);

      // Set to auto mode
      final autoRes = await service.setWateringMode(true);
      expect(autoRes.isSuccess, isTrue);
      expect(service.connectedIotDevices.every((d) => d.autoWaterEnabled), isTrue);

      // Toggle mode
      final toggleRes = await service.toggleMode();
      expect(toggleRes.isSuccess, isTrue);
      expect(service.connectedIotDevices.every((d) => !d.autoWaterEnabled), isTrue);
    });
  });
}
