import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IotDevice Telemetry & Moisture Threshold Matrix (0% - 100%)', () {
    const threshold = 30; // standard low moisture threshold

    for (int moisture = 0; moisture <= 100; moisture++) {
      test('Moisture evaluation: $moisture% vs threshold ($threshold%)', () {
        final device = IotDevice(
          id: 'dev_matrix_$moisture',
          name: 'Telemetry Probe',
          lowMoistureThreshold: threshold,
          moistureLevel: moisture.toDouble(),
          lowMoistureAlertEnabled: true,
        );

        final isLowMoisture = (device.moistureLevel ?? 0) < device.lowMoistureThreshold;
        if (moisture < threshold) {
          expect(isLowMoisture, isTrue,
              reason: 'Moisture $moisture% should trigger low moisture status');
        } else {
          expect(isLowMoisture, isFalse,
              reason: 'Moisture $moisture% is adequate and should not trigger alert');
        }
      });
    }
  });

  group('IotDevice Battery & Signal RSSI Status Permutations', () {
    final batteryScenarios = [
      {'battery': 100, 'label': 'Full'},
      {'battery': 85, 'label': 'Healthy'},
      {'battery': 50, 'label': 'Moderate'},
      {'battery': 20, 'label': 'Low'},
      {'battery': 10, 'label': 'Warning'},
      {'battery': 4, 'label': 'Critical'},
      {'battery': 0, 'label': 'Depleted'},
    ];

    for (final s in batteryScenarios) {
      test('Battery level ${s['battery']}% (${s['label']}) state handling', () {
        final device = IotDevice(
          id: 'dev_bat_${s['battery']}',
          name: 'Battery Test Device',
          batteryLevel: s['battery'] as int,
        );
        expect(device.batteryLevel, equals(s['battery']));
        expect(device.batteryLevel, inInclusiveRange(0, 100));
      });
    }

    final rssiScenarios = [
      {'rssi': -30, 'rating': 'Excellent'},
      {'rssi': -55, 'rating': 'Good'},
      {'rssi': -70, 'rating': 'Fair'},
      {'rssi': -85, 'rating': 'Weak'},
      {'rssi': -95, 'rating': 'Critical Edge'},
    ];

    for (final s in rssiScenarios) {
      test('Signal strength ${s['rssi']} dBm (${s['rating']}) preservation', () {
        final device = IotDevice(
          id: 'dev_rssi_${s['rssi']}',
          name: 'RSSI Node',
          signalStrength: s['rssi'] as int,
        );
        expect(device.signalStrength, equals(s['rssi']));
        expect(device.signalStrength, lessThanOrEqualTo(0));
      });
    }
  });

  group('IotDevice Snooze & Mute Decision Matrix', () {
    test('Default device has active alerts (not ignored)', () {
      final device = IotDevice(
        id: 'dev_active',
        name: 'Active Sensor',
        lowMoistureAlertEnabled: true,
        lowMoistureAlwaysIgnored: false,
        lowMoistureIgnoredUntil: null,
      );
      expect(device.isLowMoistureAlertIgnored, isFalse);
    });

    test('Globally disabled alerts are marked ignored', () {
      final device = IotDevice(
        id: 'dev_disabled',
        name: 'Disabled Alerts',
        lowMoistureAlertEnabled: false,
      );
      expect(device.isLowMoistureAlertIgnored, isTrue);
    });

    test('Permanently ignored (always ignored) is marked ignored', () {
      final device = IotDevice(
        id: 'dev_always_ignored',
        name: 'Silenced Probe',
        lowMoistureAlertEnabled: true,
        lowMoistureAlwaysIgnored: true,
      );
      expect(device.isLowMoistureAlertIgnored, isTrue);
    });

    final snoozeDurationsHours = [1, 2, 4, 8, 12, 24, 48];
    for (final hours in snoozeDurationsHours) {
      test('Snoozed alert for $hours hours is actively ignored during snooze window', () {
        final now = DateTime.now();
        final device = IotDevice(
          id: 'dev_snooze_$hours',
          name: 'Snoozed $hours h',
          lowMoistureAlertEnabled: true,
          lowMoistureIgnoredUntil: now.add(Duration(hours: hours)),
        );
        expect(device.isLowMoistureAlertIgnored, isTrue);
      });

      test('Expired snooze of $hours hours in the past is no longer ignored', () {
        final now = DateTime.now();
        final device = IotDevice(
          id: 'dev_expired_$hours',
          name: 'Expired $hours h',
          lowMoistureAlertEnabled: true,
          lowMoistureIgnoredUntil: now.subtract(Duration(hours: hours)),
        );
        expect(device.isLowMoistureAlertIgnored, isFalse);
      });
    }
  });

  group('IotDevice Serialization & Deserialization Correctness Matrix', () {
    final testConfigs = [
      {'name': 'Standard Garden Probe', 'thresh': 20, 'auto': false, 'wifi': 'UrbanGreen_Mesh'},
      {'name': 'Bonsai Precision Sensor', 'thresh': 45, 'auto': true, 'wifi': 'Greenhouse_IoT'},
      {'name': 'Orchid Fine Feeder', 'thresh': 60, 'auto': true, 'wifi': 'Botanical_Lab'},
      {'name': 'Cactus Drought Monitor', 'thresh': 12, 'auto': false, 'wifi': 'Desert_Zone'},
      {'name': 'Hydroponic Loop Node', 'thresh': 75, 'auto': true, 'wifi': 'Hydro_System'},
    ];

    for (int i = 0; i < testConfigs.length; i++) {
      final cfg = testConfigs[i];
      test('Roundtrip serialization [Config $i]: ${cfg['name']}', () {
        final original = IotDevice(
          id: 'roundtrip_dev_$i',
          name: cfg['name'] as String,
          lowMoistureThreshold: cfg['thresh'] as int,
          autoWaterEnabled: cfg['auto'] as bool,
          wifiSsid: cfg['wifi'] as String,
          moistureLevel: 42.5,
          batteryLevel: 88,
          signalStrength: -62,
        );

        final map = original.toMap();
        map['id'] = original.id;
        expect(map['name'], equals(cfg['name']));
        expect(map['lowMoistureThreshold'], equals(cfg['thresh']));
        expect(map['autoWaterEnabled'], equals(cfg['auto']));
        expect(map['wifiSsid'], equals(cfg['wifi']));

        final restored = IotDevice.fromMap(map);
        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.lowMoistureThreshold, equals(original.lowMoistureThreshold));
        expect(restored.autoWaterEnabled, equals(original.autoWaterEnabled));
        expect(restored.wifiSsid, equals(original.wifiSsid));
        expect(restored.moistureLevel, equals(42.5));
      });
    }

    test('fromMap gracefully defaults missing or malformed fields', () {
      final emptyMap = <String, dynamic>{};
      final fallbackDevice = IotDevice.fromMap(emptyMap);

      expect(fallbackDevice.id, isNotEmpty);
      expect(fallbackDevice.name, isNotEmpty);
      expect(fallbackDevice.lowMoistureThreshold, equals(25));
      expect(fallbackDevice.batteryLevel, equals(95));
      expect(fallbackDevice.signalStrength, equals(-58));
    });
  });

  group('Plant Model IoT Assignment & Getter Integrity', () {
    test('Unassigned plant reports hasIot false', () {
      final plant = Plant(
        id: 'p_unassigned',
        name: 'Samantha',
        species: 'Monstera Deliciosa',
        imageUrl: 'assets/images/image_1.png',
        iotDeviceId: null,
      );
      expect(plant.hasIot, isFalse);
    });

    test('Plant with empty whitespace iotDeviceId reports hasIot false', () {
      final plant = Plant(
        id: 'p_empty_iot',
        name: 'Samantha',
        species: 'Monstera Deliciosa',
        imageUrl: 'assets/images/image_1.png',
        iotDeviceId: '   ',
      );
      expect(plant.hasIot, isFalse);
    });

    test('Plant with valid device ID reports hasIot true', () {
      final plant = Plant(
        id: 'p_assigned',
        name: 'Samantha',
        species: 'Monstera Deliciosa',
        imageUrl: 'assets/images/image_1.png',
        iotDeviceId: 'iot_esp32_probe_01',
      );
      expect(plant.hasIot, isTrue);
      expect(plant.iotDeviceId, equals('iot_esp32_probe_01'));
    });
  });
}
