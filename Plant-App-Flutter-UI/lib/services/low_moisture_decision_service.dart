import 'dart:async';
import 'package:flutter/material.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/iot/low_moisture_decision_screen.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/plant_service.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';

class LowMoistureAlertEvent {
  final IotDevice device;
  final Plant plant;
  final int moisture;
  final DateTime timestamp;

  LowMoistureAlertEvent({
    required this.device,
    required this.plant,
    required this.moisture,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class LowMoistureDecisionService {
  static final LowMoistureDecisionService _instance = LowMoistureDecisionService._internal();
  factory LowMoistureDecisionService() => _instance;

  final Map<String, DateTime> _lastAlertTimes = {};
  final ValueNotifier<LowMoistureAlertEvent?> activeAlertNotifier = ValueNotifier(null);

  GlobalKey<NavigatorState>? navigatorKey;

  LowMoistureDecisionService._internal();

  void init(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;

    // Register native notification click callback
    WebHardwareBridge.setNotificationTapCallback((payload) {
      final deviceId = payload['deviceId']?.toString() ?? '';
      final plantId = payload['plantId']?.toString() ?? '';
      _handleNotificationTap(deviceId: deviceId, plantId: plantId);
    });

    // Check if the app was launched by tapping a notification
    _checkPendingIntent();
  }

  void _checkPendingIntent() async {
    final payload = await WebHardwareBridge.getPendingNotificationPayload();
    if (payload != null) {
      final deviceId = payload['deviceId']?.toString() ?? '';
      final plantId = payload['plantId']?.toString() ?? '';
      _handleNotificationTap(deviceId: deviceId, plantId: plantId);
    }
  }

  void _handleNotificationTap({required String deviceId, required String plantId}) {
    final iotService = IotHybridConnectivityService();
    final plantService = PlantService();

    IotDevice device;
    if (deviceId.isNotEmpty) {
      final matches = iotService.connectedIotDevices.where((d) => d.id == deviceId);
      if (matches.isNotEmpty) {
        device = matches.first;
      } else {
        device = iotService.connectedIotDevices.isNotEmpty
            ? iotService.connectedIotDevices.first
            : IotDevice(id: 'SmartPlant-ESP32', name: 'SmartPlant-ESP32');
      }
    } else {
      device = iotService.connectedIotDevices.isNotEmpty
          ? iotService.connectedIotDevices.first
          : IotDevice(id: 'SmartPlant-ESP32', name: 'SmartPlant-ESP32');
    }

    Plant? plant;
    if (plantId.isNotEmpty) {
      final matches = plantService.myPlants.where((p) => p.id == plantId);
      if (matches.isNotEmpty) {
        plant = matches.first;
      }
    }
    if (plant == null) {
      final matches = plantService.myPlants.where((p) => p.iotDeviceId == device.id);
      if (matches.isNotEmpty) {
        plant = matches.first;
      }
    }
    plant ??= plantService.myPlants.isNotEmpty
        ? plantService.myPlants.first
        : Plant(
            id: 'specimen_1',
            name: 'Monstera Deliciosa',
            species: 'Monstera Deliciosa',
            imageUrl: 'assets/images/image_1.png',
            iotDeviceId: device.id,
          );

    openDecisionScreen(device: device, plant: plant);
  }

  Future<void> dispatchLowMoistureAlert({
    required IotDevice device,
    required int currentMoisture,
    bool force = false,
  }) async {
    // 0. Auto watering mode check: if set to auto watering, manual decision alerts do NOT apply!
    if (device.autoWaterEnabled && !force) {
      return;
    }

    // 1. Check if disabled or ignored
    if (!device.lowMoistureAlertEnabled && !force) {
      return;
    }
    if (device.isLowMoistureAlertIgnored && !force) {
      return;
    }

    // 2. Check threshold
    if (currentMoisture >= device.lowMoistureThreshold && !force) {
      return;
    }

    // 3. Cooldown check (prevent notification spam within 15 mins unless forced)
    final now = DateTime.now();
    final lastTime = _lastAlertTimes[device.id];
    if (!force && lastTime != null && now.difference(lastTime).inMinutes < 15) {
      return;
    }
    _lastAlertTimes[device.id] = now;

    // 4. Resolve associated plant
    final plantService = PlantService();
    Plant? plant;
    final matches = plantService.myPlants.where((p) => p.iotDeviceId == device.id);
    if (matches.isNotEmpty) {
      plant = matches.first;
    } else {
      plant = plantService.myPlants.isNotEmpty ? plantService.myPlants.first : null;
    }

    plant ??= Plant(
      id: 'specimen_1',
      name: device.name,
      species: 'Monitored Specimen',
      imageUrl: 'assets/images/image_1.png',
      iotDeviceId: device.id,
    );

    final plantName = plant.name;
    final threshold = device.lowMoistureThreshold;

    // 5. Fire native heads-up system notification (sound & banner)
    await WebHardwareBridge.showNativeNotification(
      title: '⚠️ Low Soil Moisture Alert: $plantName',
      body: 'Soil moisture is down to $currentMoisture% (Threshold: $threshold%). Tap to decide whether to water or ignore.',
      deviceId: device.id,
      plantId: plant.id,
    );

    // 6. Broadcast event for in-app floating banner
    final event = LowMoistureAlertEvent(
      device: device,
      plant: plant,
      moisture: currentMoisture,
    );
    activeAlertNotifier.value = event;
  }

  void openDecisionScreen({
    required IotDevice device,
    Plant? plant,
    BuildContext? context,
  }) {
    // Dismiss active in-app banner
    activeAlertNotifier.value = null;

    final plantService = PlantService();
    final targetPlant = plant ??
        plantService.myPlants.firstWhere(
          (p) => p.iotDeviceId == device.id,
          orElse: () => plantService.myPlants.isNotEmpty
              ? plantService.myPlants.first
              : Plant(
                  id: 'specimen_1',
                  name: device.name,
                  species: 'Smart Houseplant',
                  imageUrl: 'assets/images/image_1.png',
                  iotDeviceId: device.id,
                ),
        );

    final targetContext = context ?? navigatorKey?.currentContext;
    if (targetContext != null) {
      Navigator.push(
        targetContext,
        MaterialPageRoute(
          builder: (_) => LowMoistureDecisionScreen(
            device: device,
            plant: targetPlant,
          ),
        ),
      );
    } else if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => LowMoistureDecisionScreen(
            device: device,
            plant: targetPlant,
          ),
        ),
      );
    }
  }

  void setIgnoreDuration({
    required String deviceId,
    required Duration? duration,
    required bool always,
  }) {
    final iotService = IotHybridConnectivityService();
    final matches = iotService.connectedIotDevices.where((d) => d.id == deviceId);
    if (matches.isNotEmpty) {
      final device = matches.first;
      if (always) {
        device.ignoreAlertAlways();
      } else if (duration != null) {
        device.ignoreAlertFor(duration);
      }
      iotService.persistDevices();
    }
  }

  void resetIgnore({required String deviceId}) {
    final iotService = IotHybridConnectivityService();
    final matches = iotService.connectedIotDevices.where((d) => d.id == deviceId);
    if (matches.isNotEmpty) {
      final device = matches.first;
      device.resetAlertIgnore();
      iotService.persistDevices();
    }
  }

  void updateDeviceAlertConfig({
    required String deviceId,
    required bool enabled,
    required int threshold,
  }) {
    final iotService = IotHybridConnectivityService();
    final matches = iotService.connectedIotDevices.where((d) => d.id == deviceId);
    if (matches.isNotEmpty) {
      final device = matches.first;
      device.lowMoistureAlertEnabled = enabled;
      device.lowMoistureThreshold = threshold;
      iotService.persistDevices();
    }
  }
}
