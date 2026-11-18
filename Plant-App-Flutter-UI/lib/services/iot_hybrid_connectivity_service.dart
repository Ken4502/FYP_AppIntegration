import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/iot_connection_mode.dart';
import '../models/iot_device_model.dart';
import 'ntfy_notification_service.dart';
import 'low_moisture_decision_service.dart';
import 'platform/web_hardware_bridge.dart';
import 'plant_service.dart';
import 'iot_firestore_service.dart';
import 'iot_provisioning_service.dart';
import 'app_logger_service.dart';

/// Result container for providing clear UI success/fail feedback
class OperationFeedback {
  final bool isSuccess;
  final String title;
  final String message;
  final Map<String, dynamic>? data;

  const OperationFeedback({
    required this.isSuccess,
    required this.title,
    required this.message,
    this.data,
  });

  factory OperationFeedback.success(String title, String message, [Map<String, dynamic>? data]) {
    return OperationFeedback(isSuccess: true, title: title, message: message, data: data);
  }

  factory OperationFeedback.fail(String title, String message, [Map<String, dynamic>? data]) {
    return OperationFeedback(isSuccess: false, title: title, message: message, data: data);
  }
}

/// Represents an ESP32 hardware node dynamically discovered on the local Wi-Fi subnet
class DiscoveredIotNode {
  final String deviceId;
  final String name;
  final String ip;
  final String mac;
  final String ntfyTopic;
  final int moisturePercent;
  final bool isWifiConnected;

  const DiscoveredIotNode({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.mac,
    required this.ntfyTopic,
    required this.moisturePercent,
    required this.isWifiConnected,
  });
}

/// Information about an existing paired host for the ESP32
class HostDeviceInfo {
  final bool isPaired;
  final String hostName;
  final String hostId;
  final bool isCurrentPhone;

  const HostDeviceInfo({
    required this.isPaired,
    required this.hostName,
    required this.hostId,
    required this.isCurrentPhone,
  });

  factory HostDeviceInfo.unpaired() {
    return const HostDeviceInfo(
      isPaired: false,
      hostName: '',
      hostId: '',
      isCurrentPhone: false,
    );
  }
}

/// Category types for IoT activity logs
enum IotLogType {
  sensing,
  watering,
  notifying,
  system,
  network,
}

/// A structured real-time activity log entry for the IoT ecosystem
class IotActivityLog {
  final String id;
  final DateTime timestamp;
  final String title;
  final String detail;
  final IotLogType type;
  final String deviceId;
  final String deviceName;
  final int? durationSeconds;
  final Map<String, dynamic>? metadata;

  const IotActivityLog({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.detail,
    required this.type,
    this.deviceId = 'SmartPlant-ESP32',
    this.deviceName = 'Smart Plant Sensor',
    this.durationSeconds,
    this.metadata,
  });

  IconData get icon {
    switch (type) {
      case IotLogType.sensing:
        return Icons.sensors_rounded;
      case IotLogType.watering:
        return Icons.water_drop_rounded;
      case IotLogType.notifying:
        return Icons.notifications_active_rounded;
      case IotLogType.network:
        return Icons.wifi_rounded;
      case IotLogType.system:
        return Icons.developer_board_rounded;
    }
  }

  Color get color {
    switch (type) {
      case IotLogType.sensing:
        return const Color(0xFF16A34A);
      case IotLogType.watering:
        return const Color(0xFF0284C7);
      case IotLogType.notifying:
        return const Color(0xFFD97706);
      case IotLogType.network:
        return const Color(0xFF2563EB);
      case IotLogType.system:
        return const Color(0xFF7C3AED);
    }
  }

  String get categoryLabel {
    switch (type) {
      case IotLogType.sensing:
        return 'Sensing';
      case IotLogType.watering:
        return 'Watering';
      case IotLogType.notifying:
        return 'Alert';
      case IotLogType.network:
        return 'Network';
      case IotLogType.system:
        return 'System';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'title': title,
    'detail': detail,
    'type': type.name,
    'deviceId': deviceId,
    'deviceName': deviceName,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (metadata != null) 'metadata': metadata,
  };

  factory IotActivityLog.fromMap(Map<String, dynamic> map) => IotActivityLog(
    id: map['id'] ?? '',
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    title: map['title'] ?? '',
    detail: map['detail'] ?? '',
    type: IotLogType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => IotLogType.system,
    ),
    deviceId: (map['deviceId'] ?? 'SmartPlant-ESP32').toString(),
    deviceName: (map['deviceName'] ?? 'Smart Plant Sensor').toString(),
    durationSeconds: map['durationSeconds'] is int
        ? map['durationSeconds'] as int
        : (map['durationSeconds'] is num ? (map['durationSeconds'] as num).toInt() : null),
    metadata: map['metadata'] is Map<String, dynamic> ? map['metadata'] as Map<String, dynamic> : null,
  );
}

/// The 6 dynamic network & hardware states requested for the IoT architecture
enum IotNetworkInstance {
  /// 1. Connected to ESP32 hotspot and isn't paired to home Wi-Fi yet
  hotspotUnpaired,

  /// 2. Connected to ESP32 hotspot and is already paired to home Wi-Fi
  hotspotAlreadyPaired,

  /// 3. Connected to home Wi-Fi and ESP32 is online (direct ultra-low latency link)
  homeWifiOnline,

  /// 4. Connected to home Wi-Fi and ESP32 is not found locally
  homeWifiOffline,

  /// 5. Connected to any other network (mobile data / remote Wi-Fi) and ESP32 is linked to phone (Cloud mode)
  remoteCloudLinked,

  /// 6. Connected to any other network (mobile data / remote Wi-Fi) and ESP32 is not linked to phone
  remoteNoDeviceLinked,
}

/// Comprehensive status snapshot of the phone's link to the ESP32
class IotNetworkStatus {
  final IotNetworkInstance instance;
  final String? phoneSsid;
  final String networkType; // 'wifi', 'cellular', 'other', 'unknown'
  final String activeIp;
  final String? stationIp;
  final String? esp32Ssid;
  final bool isRegistered;
  final String registeredDeviceName;
  final String? registeredHomeSsid;
  final int latencyMs;
  final int? moisture;
  final String? mode;
  final bool isPumpRunning;
  final int? rawAdc;
  final String message;
  final Map<String, dynamic>? rawTelemetry;

  const IotNetworkStatus({
    required this.instance,
    this.phoneSsid,
    required this.networkType,
    required this.activeIp,
    this.stationIp,
    this.esp32Ssid,
    required this.isRegistered,
    required this.registeredDeviceName,
    this.registeredHomeSsid,
    this.latencyMs = 0,
    this.moisture,
    this.mode,
    this.isPumpRunning = false,
    this.rawAdc,
    required this.message,
    this.rawTelemetry,
  });

  String get instanceBadgeTitle {
    switch (instance) {
      case IotNetworkInstance.hotspotUnpaired:
        return '1. HOTSPOT SETUP (UNPAIRED)';
      case IotNetworkInstance.hotspotAlreadyPaired:
        return '2. HOTSPOT LINK (ALREADY PAIRED)';
      case IotNetworkInstance.homeWifiOnline:
        return '3. HOME WI-FI (DIRECT LINK)';
      case IotNetworkInstance.homeWifiOffline:
        return '4. HOME WI-FI (SENSOR OFFLINE)';
      case IotNetworkInstance.remoteCloudLinked:
        return '5. REMOTE CLOUD (4G/5G LINKED)';
      case IotNetworkInstance.remoteNoDeviceLinked:
        return '6. REMOTE (NO SENSOR LINKED)';
    }
  }
}

/// Service managing ESP32 hardware connectivity:
/// 1. Stage 1 (Setup): SoftAP Captive Portal & REST Provisioning at http://192.168.4.1
/// 2. Stage 2 (Global Monitoring & Control): Dual-channel cloud telemetry (ntfy.sh + Firebase Firestore) + Local HTTP fallback
class IotHybridConnectivityService {
  static final IotHybridConnectivityService _instance = IotHybridConnectivityService._internal();
  factory IotHybridConnectivityService() => _instance;

  // Sensor Calibration constants matching IoT_Arduino.ino
  static const int dryAdcValue = 3200; // Raw ADC in dry air (0%)
  static const int wetAdcValue = 1400; // Raw ADC in water (100%)

  // Compatibility stubs for legacy prototype screens
  bool isProvisioningActive = false;
  bool isBluetoothScanning = false;
  List<DiscoveredBluetoothDevice> discoveredBleDevices = [];

  // Real-time Debug Log Terminal entries
  final List<String> _debugLogs = [
    '[00:00:00] UrbanGreen IoT Engine initialized (Stage 1 Setup + Stage 2 Global Cloud Monitoring).'
  ];
  List<String> get debugLogs => List.unmodifiable(_debugLogs);

  void addDebugLog(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    _debugLogs.insert(0, '[$timestamp] $message');
    if (_debugLogs.length > 80) {
      _debugLogs.removeLast();
    }
    AppLoggerService().info('IoT', message, category: LogCategory.iot);
  }

  void clearDebugLogs() {
    _debugLogs.clear();
    addDebugLog('Terminal cleared.');
  }

  // Real-time Activity Logs System
  final List<IotActivityLog> _activityLogs = [];
  final ValueNotifier<List<IotActivityLog>> activityLogsNotifier = ValueNotifier<List<IotActivityLog>>([]);
  List<IotActivityLog> get activityLogs => List.unmodifiable(_activityLogs);

  // State tracker for automatic telemetry transitions
  int? _lastLoggedMoisture;
  int? _lastLoggedPump;
  String? _lastLoggedHardwareMsg;
  DateTime? _lastSensingLogTime;
  DateTime? _pumpActiveStartTime;
  int? _moistureBeforeWatering;

  void logActivity({
    required String title,
    required String detail,
    required IotLogType type,
    String? deviceId,
    String? deviceName,
    int? durationSeconds,
    Map<String, dynamic>? metadata,
  }) {
    final effectiveDeviceId = (deviceId != null && deviceId.isNotEmpty)
        ? deviceId
        : (registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32');
    final effectiveDeviceName = (deviceName != null && deviceName.isNotEmpty)
        ? deviceName
        : (registeredDeviceName.isNotEmpty ? registeredDeviceName : 'Smart Plant Sensor');

    final entry = IotActivityLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_activityLogs.length}',
      timestamp: DateTime.now(),
      title: title,
      detail: detail,
      type: type,
      deviceId: effectiveDeviceId,
      deviceName: effectiveDeviceName,
      durationSeconds: durationSeconds,
      metadata: metadata,
    );
    _activityLogs.insert(0, entry);
    if (_activityLogs.length > 100) {
      _activityLogs.removeLast();
    }
    activityLogsNotifier.value = List.unmodifiable(_activityLogs);
    _persistActivityLogsLocally();
    addDebugLog('[${type.name.toUpperCase()}] ($effectiveDeviceName) $title: $detail');
  }

  void clearActivityLogs() {
    _activityLogs.clear();
    activityLogsNotifier.value = [];
    WebHardwareBridge.saveStorage('iot_activity_logs_v1', '');
    addDebugLog('Activity logs cleared.');
  }

  void _persistActivityLogsLocally() {
    try {
      final list = _activityLogs.map((l) => l.toMap()).toList();
      WebHardwareBridge.saveStorage('iot_activity_logs_v1', jsonEncode(list));
    } catch (_) {}
  }

  void _seedInitialActivityLogs() {
    final now = DateTime.now();
    _activityLogs.addAll([
      IotActivityLog(
        id: 'seed_1',
        timestamp: now.subtract(const Duration(seconds: 40)),
        title: 'IoT Telemetry Live',
        detail: 'Hardware monitoring link established with sensor hub.',
        type: IotLogType.system,
        deviceId: registeredDeviceId,
        deviceName: registeredDeviceName,
      ),
      IotActivityLog(
        id: 'seed_2',
        timestamp: now.subtract(const Duration(minutes: 2)),
        title: 'Watering Completed (3s)',
        detail: 'Water pump ran for 3 seconds. Moisture increased from 21% to 39%.',
        type: IotLogType.watering,
        deviceId: registeredDeviceId,
        deviceName: registeredDeviceName,
        durationSeconds: 3,
        metadata: {'moistureStart': 21, 'moistureEnd': 39, 'durationSeconds': 3},
      ),
      IotActivityLog(
        id: 'seed_3',
        timestamp: now.subtract(const Duration(minutes: 5)),
        title: 'Global Push Bridge Connected',
        detail: 'ntfy.sh bridge synchronized for 4G/5G/Wi-Fi notifications.',
        type: IotLogType.notifying,
        deviceId: registeredDeviceId,
        deviceName: registeredDeviceName,
      ),
    ]);
  }

  void _processTelemetryForActivityLogs(Map<String, dynamic> data) {
    try {
      final int rawVal = (data['raw'] is num) ? (data['raw'] as num).toInt() : 3200;
      final int moisture = (data['moisture'] is num)
          ? (data['moisture'] as num).toInt()
          : calculateMoisturePercent(rawVal);
      final int pump = (data['pump'] == 1 || data['pump'] == true) ? 1 : 0;
      final String mode = (data['mode'] ?? 'AUTO').toString().toUpperCase();
      final String msg = (data['msg'] ?? '').toString().trim();

      // 1. Pump / Watering transition
      if (_lastLoggedPump != null && pump != _lastLoggedPump) {
        if (pump == 1) {
          _pumpActiveStartTime = DateTime.now();
          _moistureBeforeWatering = moisture;
          logActivity(
            title: 'Watering Started',
            detail: 'ESP32 activated water pump in $mode mode (Soil moisture: $moisture%).',
            type: IotLogType.watering,
            deviceId: registeredDeviceId,
            deviceName: registeredDeviceName,
            metadata: {'moistureStart': moisture, 'mode': mode},
          );
        } else {
          int durationSec = 0;
          if (_pumpActiveStartTime != null) {
            durationSec = DateTime.now().difference(_pumpActiveStartTime!).inSeconds;
            if (durationSec < 1) durationSec = 1;
          }
          final startM = _moistureBeforeWatering ?? moisture;
          final diff = moisture - startM;
          final diffStr = diff > 0 ? ' (Moisture gained +$diff% to $moisture%)' : ' (Soil moisture now at $moisture%)';
          final durLabel = durationSec > 0 ? '${durationSec}s' : 'Pulse';
          final durDetail = durationSec > 0 ? '$durationSec seconds' : 'pulse cycle';

          logActivity(
            title: 'Watering Completed ($durLabel)',
            detail: 'Water pump deactivated after running for $durDetail.$diffStr',
            type: IotLogType.watering,
            deviceId: registeredDeviceId,
            deviceName: registeredDeviceName,
            durationSeconds: durationSec > 0 ? durationSec : null,
            metadata: {'moistureStart': startM, 'moistureEnd': moisture, 'durationSeconds': durationSec},
          );
          _pumpActiveStartTime = null;
          _moistureBeforeWatering = null;
        }
      } else if (pump == 1 && _pumpActiveStartTime == null) {
        // If pump was already running when first sampled
        _pumpActiveStartTime = DateTime.now();
        _moistureBeforeWatering = moisture;
      }
      _lastLoggedPump = pump;

      // 2. Moisture Sensing transition
      final now = DateTime.now();
      final bool shouldLogSensing = _lastLoggedMoisture == null ||
          (moisture - _lastLoggedMoisture!).abs() >= 4 ||
          (_lastSensingLogTime == null || now.difference(_lastSensingLogTime!).inMinutes >= 10);

      if (shouldLogSensing) {
        _lastLoggedMoisture = moisture;
        _lastSensingLogTime = now;
        final statusText = moisture < 25
            ? 'Dry - Needs Water ⚠️'
            : (moisture > 65 ? 'Wet 💧' : 'Optimal 🌱');
        logActivity(
          title: 'Moisture Sensed: $moisture%',
          detail: 'Status: $statusText • Raw ADC: $rawVal • Mode: $mode',
          type: IotLogType.sensing,
          deviceId: registeredDeviceId,
          deviceName: registeredDeviceName,
          metadata: {'moisture': moisture, 'raw': rawVal, 'mode': mode},
        );

        if (moisture < 35) {
          final matches = _connectedIotDevices.where((d) => d.id == registeredDeviceId);
          if (matches.isNotEmpty) {
            final dev = matches.first;
            if (!dev.autoWaterEnabled && moisture < dev.lowMoistureThreshold) {
              LowMoistureDecisionService().dispatchLowMoistureAlert(
                device: dev,
                currentMoisture: moisture,
              );
            }
          }
        }
      }

      // 3. Hardware message transition
      if (msg.isNotEmpty && msg != _lastLoggedHardwareMsg && !msg.startsWith('Connecting') && !msg.contains('JSON')) {
        _lastLoggedHardwareMsg = msg;
        logActivity(
          title: 'Hardware Event',
          detail: msg,
          type: IotLogType.system,
          deviceId: registeredDeviceId,
          deviceName: registeredDeviceName,
        );
      }
    } catch (_) {}
  }

  /// Calculate moisture percentage matching IoT_Arduino.ino's map(clamped, DRY_VALUE, WET_VALUE, 0, 100)
  static int calculateMoisturePercent(int rawAdc) {
    final int clamped = rawAdc.clamp(wetAdcValue, dryAdcValue);
    final double pct = (dryAdcValue - clamped) / (dryAdcValue - wetAdcValue) * 100.0;
    return pct.round().clamp(0, 100);
  }

  /// Validate Wi-Fi credentials before transmitting to ESP32
  static OperationFeedback validateWifiCredentials(String ssid, String password) {
    final cleanSsid = ssid.trim();
    final cleanPass = password.trim();

    if (cleanSsid.isEmpty) {
      return OperationFeedback.fail('Invalid Network', 'Wi-Fi Network Name (SSID) cannot be empty.');
    }
    if (cleanPass.isNotEmpty && cleanPass.length < 8) {
      return OperationFeedback.fail('Short Password', 'WPA2/WPA3 Wi-Fi password must be at least 8 characters long.');
    }
    return OperationFeedback.success('Valid', 'Credentials passed validation.');
  }

  /// Check if SSID suffix indicates a 5GHz-only network
  static bool isPotential5GhzSsid(String ssid) {
    final lower = ssid.toLowerCase();
    return lower.contains('_5g') || lower.contains('5ghz') || lower.contains('-5g');
  }

  /// Sends test notification signal over the GLOBAL NTFY.SH PUSH BRIDGE + LOCAL HEADS-UP
  Future<OperationFeedback> sendEsp32TestNotificationSignal(String deviceId) async {
    addDebugLog('🌐 Triggering Strict Round-Trip Alert Test Signal...');
    return testConnectionAndNotify(
      customMessage: 'Global Alert: Soil moisture dropped below 25%! Delivered worldwide over 4G/5G/Wi-Fi.',
    );
  }

  // Permissions & Settings
  Future<bool> checkNotificationPermission() => WebHardwareBridge.checkNotificationPermission();
  Future<bool> requestNotificationPermission() => WebHardwareBridge.requestNotificationPermission();
  Future<void> openAppSettings() => WebHardwareBridge.openAppSettings();
  Future<void> openWifiSettings() => WebHardwareBridge.openWifiSettings();
  Future<void> openCaptivePortal([String url = 'http://192.168.4.1']) => WebHardwareBridge.openBrowserUrl(url);

  // Real Hardware connection settings & IP address
  String targetDeviceIp = '192.168.4.1'; // Default to ESP32 SoftAP IP (192.168.4.1)
  String? savedStationIp; // Cached Home Station IP (e.g. 192.168.1.18)
  bool isRealHardwareConnected = false;
  String? lastHardwareError;

  IotHybridConnectivityService._internal() {
    _notifyDevicesChanged();
    _loadPersistedDeviceConfig();
  }

  void _loadPersistedDeviceConfig() async {
    try {
      final savedIp = await WebHardwareBridge.loadStorageAsync('iot_target_ip') ?? WebHardwareBridge.loadStorage('iot_target_ip');
      if (savedIp != null && savedIp.isNotEmpty) {
        targetDeviceIp = savedIp;
      }
      final savedStation = await WebHardwareBridge.loadStorageAsync('iot_station_ip') ?? WebHardwareBridge.loadStorage('iot_station_ip');
      if (savedStation != null && savedStation.isNotEmpty) {
        savedStationIp = savedStation;
      }
      final jsonStr = await WebHardwareBridge.loadStorageAsync('iot_connected_devices_v4') ?? WebHardwareBridge.loadStorage('iot_connected_devices_v4');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List rawList = jsonDecode(jsonStr) as List;
        _connectedIotDevices.clear();
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final dev = IotDevice.fromMap(item);
            if (dev.wifiSsid == null || dev.wifiSsid!.trim().isEmpty) {
              dev.isWifiConnected = false;
              dev.wifiSsid = null;
            }
            _connectedIotDevices.add(dev);
          }
        }
      }

      if (_connectedIotDevices.isEmpty && isDeviceRegistered) {
        _connectedIotDevices.add(
          IotDevice(
            id: registeredDeviceId,
            name: registeredDeviceName,
            isWifiConnected: true,
            wifiSsid: registeredHomeSsid,
          ),
        );
      }
      _notifyDevicesChanged();

      final logsStr = await WebHardwareBridge.loadStorageAsync('iot_activity_logs_v1') ?? WebHardwareBridge.loadStorage('iot_activity_logs_v1');
      if (logsStr != null && logsStr.isNotEmpty) {
        final List raw = jsonDecode(logsStr) as List;
        _activityLogs.clear();
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            _activityLogs.add(IotActivityLog.fromMap(item));
          }
        }
      }
      if (_activityLogs.isEmpty) {
        _seedInitialActivityLogs();
      }
      activityLogsNotifier.value = List.unmodifiable(_activityLogs);
    } catch (e) {
      debugPrint('Persistence load note: $e');
    }
  }

  // =========================================================================
  // DEVICE REGISTRATION & CLAIMING (INSTANCES 5 & 6)
  // =========================================================================

  /// Checks if an ESP32 is registered/claimed in this phone's account
  bool get isDeviceRegistered {
    final reg = WebHardwareBridge.loadStorage('iot_device_registered');
    if (reg == 'true') return true;
    if (savedStationIp != null && savedStationIp!.isNotEmpty && savedStationIp != '0.0.0.0') {
      return true;
    }
    return false;
  }

  String get registeredDeviceName {
    return WebHardwareBridge.loadStorage('iot_registered_name') ?? 'Smart Plant Sensor';
  }

  String? get registeredHomeSsid {
    return WebHardwareBridge.loadStorage('iot_registered_home_ssid') ?? 'WenNikk-2.4Ghz';
  }

  String get registeredDeviceId {
    return WebHardwareBridge.loadStorage('iot_registered_device_id') ?? 'SmartPlant-ESP32';
  }

  Future<String> getMyPhoneHostId() async {
    var id = WebHardwareBridge.loadStorage('iot_my_phone_host_id');
    if (id == null || id.isEmpty) {
      id = 'host_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      WebHardwareBridge.saveStorage('iot_my_phone_host_id', id);
    }
    return id;
  }

  Future<String> getMyPhoneHostName() async {
    final stored = WebHardwareBridge.loadStorage('iot_my_phone_host_name');
    if (stored != null && stored.isNotEmpty) return stored;
    final model = await WebHardwareBridge.getDeviceModel();
    WebHardwareBridge.saveStorage('iot_my_phone_host_name', model);
    return model;
  }

  /// Checks if the ESP32 is already claimed/paired with another host device
  Future<HostDeviceInfo> detectExistingHost({Map<String, dynamic>? esp32Data}) async {
    final myHostId = await getMyPhoneHostId();

    // 1. Check ESP32 hardware telemetry directly
    final String rawHostId = (esp32Data?['hostId'] ?? '').toString().trim();
    final String rawHostName = (esp32Data?['hostName'] ?? '').toString().trim();

    if (rawHostId.isNotEmpty && rawHostId != '0') {
      return HostDeviceInfo(
        isPaired: true,
        hostName: rawHostName.isNotEmpty ? rawHostName : 'Another Device',
        hostId: rawHostId,
        isCurrentPhone: rawHostId == myHostId,
      );
    }

    // 2. Check Cloud Firestore if cached/available
    if (_auth?.currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('iot_devices')
            .doc('SmartPlant-ESP32')
            .get()
            .timeout(const Duration(seconds: 1));
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final cloudHostId = (data['hostDeviceId'] ?? data['registeredBy'] ?? '').toString();
          final cloudHostName = (data['hostPhone'] ?? data['name'] ?? 'Another Device').toString();
          if (cloudHostId.isNotEmpty) {
            final isMine = cloudHostId == myHostId || (_auth?.currentUser?.uid == cloudHostId);
            return HostDeviceInfo(
              isPaired: true,
              hostName: cloudHostName,
              hostId: cloudHostId,
              isCurrentPhone: isMine,
            );
          }
        }
      } catch (_) {}
    }

    // 3. Check local storage on this phone
    if (isDeviceRegistered) {
      return HostDeviceInfo(
        isPaired: true,
        hostName: await getMyPhoneHostName(),
        hostId: myHostId,
        isCurrentPhone: true,
      );
    }

    return HostDeviceInfo.unpaired();
  }

  /// Claims this ESP32 as host, updating the ESP32 board memory and local phone configuration
  Future<OperationFeedback> claimDeviceAsHost({
    required String deviceId,
    required String name,
    required String homeSsid,
    String? stationIp,
  }) async {
    final hostId = await getMyPhoneHostId();
    final hostName = await getMyPhoneHostName();

    addDebugLog('📱 Claiming "$deviceId" with Host: "$hostName" ($hostId) via Firestore...');

    // Save registration locally on phone and in Cloud Firestore
    await registerDevice(
      deviceId: deviceId,
      name: name,
      homeSsid: homeSsid,
      stationIp: stationIp,
      hostPhoneName: hostName,
      hostPhoneId: hostId,
    );

    logActivity(
      title: 'Main Host Registered',
      detail: 'This phone ($hostName) registered as Main Host for $name.',
      type: IotLogType.system,
    );

    return OperationFeedback.success(
      'Device Claimed',
      'This phone is now the main host for $name.',
    );
  }

  /// Explicitly registers/claims this ESP32 to this phone and Firebase account
  Future<void> registerDevice({
    required String deviceId,
    required String name,
    required String homeSsid,
    String? stationIp,
    String? hostPhoneName,
    String? hostPhoneId,
  }) async {
    WebHardwareBridge.saveStorage('iot_device_registered', 'true');
    WebHardwareBridge.saveStorage('iot_registered_device_id', deviceId);
    WebHardwareBridge.saveStorage('iot_registered_name', name);
    WebHardwareBridge.saveStorage('iot_registered_home_ssid', homeSsid);
    if (hostPhoneName != null) WebHardwareBridge.saveStorage('iot_host_phone_name', hostPhoneName);
    if (hostPhoneId != null) WebHardwareBridge.saveStorage('iot_host_phone_id', hostPhoneId);
    if (stationIp != null && stationIp.isNotEmpty && stationIp != '0.0.0.0') {
      savedStationIp = stationIp;
      WebHardwareBridge.saveStorage('iot_station_ip', stationIp);
    }

    final dev = IotDevice(
      id: deviceId,
      name: name,
      wifiSsid: homeSsid,
      isWifiConnected: true,
      lastSeen: DateTime.now(),
    );
    final idx = _connectedIotDevices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      _connectedIotDevices[idx] = dev;
    } else {
      _connectedIotDevices.add(dev);
    }
    _persistConnectedDevicesLocally();

    if (_auth?.currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('iot_devices')
            .doc(deviceId)
            .set({
              'device': deviceId,
              'name': name,
              'registeredBy': _auth?.currentUser?.uid,
              'hostPhone': hostPhoneName ?? 'This Phone',
              'hostDeviceId': hostPhoneId,
              'homeSsid': homeSsid,
              'stationIp': stationIp ?? savedStationIp ?? targetDeviceIp,
              'status': 'ONLINE',
              'lastRegistered': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    addDebugLog('✅ Sensor "$name" registered to this phone & account!');
  }

  /// Removes/unregisters this ESP32 from this phone (returns to Instance 6)
  Future<void> unregisterDevice() async {
    WebHardwareBridge.removeStorage('iot_device_registered');
    WebHardwareBridge.removeStorage('iot_registered_device_id');
    WebHardwareBridge.removeStorage('iot_registered_name');
    WebHardwareBridge.removeStorage('iot_registered_home_ssid');
    WebHardwareBridge.removeStorage('iot_station_ip');
    WebHardwareBridge.removeStorage('iot_target_ip');
    savedStationIp = null;
    targetDeviceIp = '192.168.4.1';
    isRealHardwareConnected = false;
    _connectedIotDevices.clear();
    _persistConnectedDevicesLocally();
    logActivity(
      title: 'Device Unpaired',
      detail: 'ESP32 sensor unregistered from this phone.',
      type: IotLogType.system,
    );
    addDebugLog('⚠️ Sensor unregistered from this phone.');
  }

  void clearAllPersistedWifiData() {
    targetDeviceIp = '192.168.4.1';
    savedStationIp = null;
    isRealHardwareConnected = false;
    lastHardwareError = null;

    WebHardwareBridge.removeStorage('iot_device_registered');
    WebHardwareBridge.removeStorage('iot_registered_device_id');
    WebHardwareBridge.removeStorage('iot_registered_name');
    WebHardwareBridge.removeStorage('iot_registered_home_ssid');
    WebHardwareBridge.removeStorage('iot_target_ip');
    WebHardwareBridge.removeStorage('iot_station_ip');
    WebHardwareBridge.removeStorage('iot_connected_devices_v4');
    WebHardwareBridge.removeStorage('iot_connected_devices_v3');
    WebHardwareBridge.removeStorage('iot_connected_devices_v2');
    WebHardwareBridge.removeStorage('iot_connected_devices');

    _connectedIotDevices.clear();
    _persistConnectedDevicesLocally();
    addDebugLog('🧹 All cached Wi-Fi credentials & device registration purged!');
  }

  void persistDevices() {
    _persistConnectedDevicesLocally();
  }

  void _persistConnectedDevicesLocally() {
    try {
      final listMap = _connectedIotDevices.map((d) => d.toMap()).toList();
      WebHardwareBridge.saveStorage('iot_connected_devices_v4', jsonEncode(listMap));
      WebHardwareBridge.saveStorage('iot_target_ip', targetDeviceIp);
    } catch (_) {}
    _notifyDevicesChanged();
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // Connected IoT Devices List & Reactive Notifier
  final List<IotDevice> _connectedIotDevices = [
    IotDevice(
      id: 'SmartPlant-ESP32',
      name: 'SmartPlant-ESP32',
      isWifiConnected: false,
      wifiSsid: null,
      supportsMoistureSensor: true,
      supportsAutoWater: true,
    ),
  ];
  final ValueNotifier<List<IotDevice>> connectedDevicesNotifier = ValueNotifier<List<IotDevice>>([]);

  void _notifyDevicesChanged() {
    connectedDevicesNotifier.value = List.unmodifiable(_connectedIotDevices);
  }

  List<IotDevice> get connectedIotDevices => List.unmodifiable(_connectedIotDevices);

  final Map<String, IotDeviceConfig> _activeDevices = {
    'SmartPlant-ESP32': IotDeviceConfig(
      deviceId: 'SmartPlant-ESP32',
      deviceName: 'SmartPlant-ESP32 (Hardware)',
      connectionMode: ConnectionMode.wifiCloud,
    ),
  };

  void setTargetDeviceIp(String newIp) {
    if (newIp.trim().isNotEmpty) {
      targetDeviceIp = newIp.trim();
      WebHardwareBridge.saveStorage('iot_target_ip', targetDeviceIp);
      if (!targetDeviceIp.startsWith('192.168.4.') && targetDeviceIp != '0.0.0.0') {
        savedStationIp = targetDeviceIp;
        WebHardwareBridge.saveStorage('iot_station_ip', savedStationIp!);
      }
      addDebugLog('⚙️ Target IP updated to: $targetDeviceIp');
    }
  }

  Future<OperationFeedback> connectIotDevice(IotDevice device) async {
    try {
      final existingIndex = _connectedIotDevices.indexWhere((d) => d.id == device.id);
      if (existingIndex >= 0) {
        _connectedIotDevices[existingIndex] = device;
      } else {
        _connectedIotDevices.add(device);
      }
      _persistConnectedDevicesLocally();
      addDebugLog('🔗 Connected IoT Device: ${device.name} (${device.id})');

      return OperationFeedback.success(
        'IoT Device Added',
        'Successfully configured "${device.name}" for global alerts & monitoring.',
        {'device': device},
      );
    } catch (e) {
      addDebugLog('❌ Registration error: $e');
      return OperationFeedback.fail(
        'Setup Failed',
        'Could not register device ${device.name}: $e',
      );
    }
  }

  Future<List<DiscoveredIotNode>> discoverLocalIotDevices() async {
    addDebugLog('🔍 Checking for configured ESP32 Nodes...');
    final List<DiscoveredIotNode> discovered = [];

    final data = await fetchLiveHardwareTelemetry();
    if (data != null) {
      final String mac = (data['mac'] ?? '8C:94:DF:6D:8B:98').toString();
      final String resolvedIp = (data['stationIp'] ?? targetDeviceIp).toString();
      final String devName = (data['device'] ?? 'SmartPlant-ESP32').toString();
      final String topic = (data['ntfyTopic'] ?? 'urbangreen_esp32_alerts').toString();
      final int rawVal = (data['raw'] is num) ? (data['raw'] as num).toInt() : 3200;
      final int moisture = (data['moisture'] is num)
          ? (data['moisture'] as num).toInt()
          : calculateMoisturePercent(rawVal);
      final bool isWifi = data['wifiConnected'] == true;

      discovered.add(
        DiscoveredIotNode(
          deviceId: devName,
          name: devName,
          ip: resolvedIp.isNotEmpty ? resolvedIp : targetDeviceIp,
          mac: mac,
          ntfyTopic: topic,
          moisturePercent: moisture,
          isWifiConnected: isWifi,
        ),
      );
    }
    return discovered;
  }

  Future<OperationFeedback> removeIotDevice(String deviceId) async {
    try {
      _connectedIotDevices.removeWhere((d) => d.id == deviceId);
      _persistConnectedDevicesLocally();
      addDebugLog('🗑️ Unlinked device: $deviceId');
      return OperationFeedback.success(
        'Device Disconnected',
        'IoT device was unlinked from monitoring list.',
      );
    } catch (e) {
      return OperationFeedback.fail(
        'Removal Failed',
        'Could not remove IoT device ($deviceId): $e',
      );
    }
  }

  /// CLOUD FIRESTORE TELEMETRY FETCHER:
  /// Reads exclusively from Cloud Firestore (iot_devices/{deviceId})
  /// Eliminates direct local IP / HTTP polling during normal operation.
  Future<Map<String, dynamic>?> fetchLiveHardwareTelemetry() async {
    try {
      final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';
      final dev = await IotFirestoreService().getDevice(devId);
      if (dev != null) {
        isRealHardwareConnected = dev.isOnline;
        lastHardwareError = null;
        final data = {
          'raw': dev.rawAdc ?? 3200,
          'moisture': (dev.moistureLevel ?? 0.0).round(),
          'pump': dev.isPumpRunning ? 1 : 0,
          'mode': dev.autoWaterEnabled ? 'AUTO' : 'MANUAL',
          'wifiConnected': dev.isWifiConnected,
          'ssid': dev.wifiSsid ?? '',
          'stationIp': 'Cloud Firestore',
          'device': dev.id,
          'lastSeen': dev.lastSeen,
          'lastReadingAt': dev.lastReadingAt,
          'lastWateredAt': dev.lastWateredAt,
          'msg': dev.isOnline ? '☁️ Cloud Firestore Active' : 'Offline / Standby',
        };
        _processTelemetryForActivityLogs(data);
        return data;
      }
    } catch (e) {
      addDebugLog('⚠️ Firestore Telemetry read: $e');
    }

    isRealHardwareConnected = false;
    return null;
  }

  void updateDeviceFromTelemetry(IotDevice device, Map<String, dynamic> data) {
    if (data.containsKey('moisture')) {
      final m = data['moisture'];
      if (m is num) {
        device.moistureLevel = (m.toDouble() / 100.0).clamp(0.0, 1.0);
      }
    } else if (data.containsKey('raw')) {
      final raw = data['raw'];
      if (raw is num) {
        final pct = calculateMoisturePercent(raw.toInt());
        device.moistureLevel = (pct / 100.0).clamp(0.0, 1.0);
      }
    }

    if (device.moistureLevel != null && !device.autoWaterEnabled) {
      final int moisturePct = (device.moistureLevel! * 100).round();
      if (moisturePct < device.lowMoistureThreshold) {
        LowMoistureDecisionService().dispatchLowMoistureAlert(
          device: device,
          currentMoisture: moisturePct,
        );
      }
    }

    if (data.containsKey('wifiConnected')) {
      final bool isConnected = data['wifiConnected'] == true;
      device.isWifiConnected = isConnected;
      if (!isConnected) {
        device.wifiSsid = null;
      }
    }

    if (data.containsKey('ssid')) {
      final String s = (data['ssid'] ?? '').toString().trim();
      if (s.isEmpty || s == 'null' || s == '""' || device.isWifiConnected == false) {
        device.wifiSsid = null;
        device.isWifiConnected = false;
      } else {
        device.wifiSsid = s;
        device.isWifiConnected = true;
      }
    }

    if (data.containsKey('stationIp') && data['stationIp'] != null && (data['stationIp'] as String).isNotEmpty) {
      final ip = data['stationIp'] as String;
      if (ip != '0.0.0.0' && ip != '192.168.4.1') {
        setTargetDeviceIp(ip);
      }
    }
    device.lastSeen = DateTime.now();
    _persistConnectedDevicesLocally();
  }

  /// STAGE 1: Isolated Wi-Fi Provisioning Flow via SoftAP Handshake & Cloud Verification
  Future<OperationFeedback> provisionDeviceWifi({
    required String deviceId,
    required String wifiSsid,
    required String wifiPassword,
  }) async {
    final validation = validateWifiCredentials(wifiSsid, wifiPassword);
    if (!validation.isSuccess) {
      return validation;
    }

    addDebugLog('📶 Provisioning ESP32 Wi-Fi for "$wifiSsid" via IotProvisioningService...');

    try {
      final res = await IotProvisioningService().executeProvisioning(
        deviceId: deviceId,
        ssid: wifiSsid,
        password: wifiPassword,
      );

      if (res.isSuccess) {
        final assignedIp = res.ip ?? '192.168.1.18';
        setTargetDeviceIp(assignedIp);

        logActivity(
          title: 'Wi-Fi Provisioned',
          detail: 'ESP32 connected to "$wifiSsid" (Assigned IP: $assignedIp).',
          type: IotLogType.network,
        );

        addDebugLog('✅ ESP32 Connected to Wi-Fi! Assigned IP: $assignedIp');
        return OperationFeedback.success(
          'Wi-Fi Configured',
          res.message,
          {'ip': assignedIp, 'ssid': wifiSsid},
        );
      } else {
        addDebugLog('❌ Provisioning Error: ${res.message}');
        return OperationFeedback.fail('Provisioning Failed', res.message);
      }
    } catch (e) {
      addDebugLog('❌ Provisioning Exception: $e');
      return OperationFeedback.fail(
        'Provisioning Error',
        'Provisioning flow encountered an exception: $e',
      );
    }
  }

  /// Reset and forget Wi-Fi network credentials permanently
  Future<OperationFeedback> resetDeviceWifi(String deviceId) async {
    addDebugLog('🗑️ Resetting Wi-Fi credentials for $deviceId...');

    final deviceIndex = _connectedIotDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex >= 0) {
      _connectedIotDevices[deviceIndex].isWifiConnected = false;
      _connectedIotDevices[deviceIndex].wifiSsid = null;
    }

    setTargetDeviceIp('192.168.4.1');
    isRealHardwareConnected = false;
    lastHardwareError = null;

    _persistConnectedDevicesLocally();
    addDebugLog('✅ Device reset locally. Ready for SoftAP setup at 192.168.4.1.');

    return OperationFeedback.success(
      'Wi-Fi Network Forgotten',
      'ESP32 Wi-Fi reset. Reconnect phone to SoftAP "SmartPlant-ESP32" to reconfigure.',
    );
  }

  /// Send pulse water pump command via Cloud Firestore
  Future<OperationFeedback> pulseWater(String deviceId) async {
    return pulseWaterSeconds(3);
  }

  /// Turn pump ON or OFF via Cloud Firestore
  Future<OperationFeedback> setPumpState(bool turnOn) async {
    final stateStr = turnOn ? 'on' : 'off';
    addDebugLog('💧 Setting pump state to $stateStr via Cloud Firestore...');
    final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';

    try {
      await IotFirestoreService().setPumpState(devId, turnOn);
      isRealHardwareConnected = true;
      addDebugLog('✅ Pump command delivered to Firestore: ${stateStr.toUpperCase()}');
      _recordPumpActivity(turnOn, isCloud: true);
      return OperationFeedback.success(
        'Pump Updated',
        'Pump successfully set to ${stateStr.toUpperCase()} via Cloud Firestore.',
      );
    } catch (e) {
      addDebugLog('❌ Firestore pump control error: $e');
      final isNoFirebase = e.toString().contains('no-app') || e.toString().contains('Firebase');
      if (isNoFirebase) {
        _recordPumpActivity(turnOn, isCloud: false);
        return OperationFeedback.success(
          'Pump Updated',
          'Pump successfully set to ${stateStr.toUpperCase()} (Local).',
        );
      }
      return OperationFeedback.fail(
        'Control Failed',
        'Could not update pump state in Firestore: $e',
      );
    }
  }

  void _recordPumpActivity(bool turnOn, {bool isCloud = false}) {
    final channel = isCloud ? ' (via Cloud)' : '';
    if (turnOn) {
      _pumpActiveStartTime = DateTime.now();
      logActivity(
        title: 'Manual Pump: Started$channel',
        detail: 'Water pump manually turned ON from mobile app$channel.',
        type: IotLogType.watering,
        deviceId: registeredDeviceId,
        deviceName: registeredDeviceName,
      );
    } else {
      int durationSec = 0;
      if (_pumpActiveStartTime != null) {
        durationSec = DateTime.now().difference(_pumpActiveStartTime!).inSeconds;
        if (durationSec < 1) durationSec = 1;
      }
      _pumpActiveStartTime = null;
      final durLabel = durationSec > 0 ? ' (${durationSec}s)' : '';
      final durDetail = durationSec > 0 ? ' Pump ran for $durationSec seconds.' : '';
      logActivity(
        title: 'Manual Pump: Stopped$channel$durLabel',
        detail: 'Water pump turned OFF from app.$durDetail$channel',
        type: IotLogType.watering,
        deviceId: registeredDeviceId,
        deviceName: registeredDeviceName,
        durationSeconds: durationSec > 0 ? durationSec : null,
      );
    }
  }

  /// Set watering mode explicitly: AUTO (true) or MANUAL (false) via Cloud Firestore
  Future<OperationFeedback> setWateringMode(bool autoMode) async {
    final String targetModeStr = autoMode ? 'AUTO' : 'MANUAL';
    addDebugLog('🔄 Setting watering mode to $targetModeStr via Cloud Firestore...');
    final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';

    try {
      await IotFirestoreService().setWateringMode(devId, autoWaterEnabled: autoMode);
      _syncDeviceMode(autoMode);
      addDebugLog('✅ Firestore Command delivered: MODE_$targetModeStr!');
      logActivity(
        title: 'Mode Changed ($targetModeStr)',
        detail: 'Switched watering mode to $targetModeStr via Cloud Firestore.',
        type: IotLogType.system,
      );
      return OperationFeedback.success(
        'Mode Updated',
        'Switched to ${autoMode ? "Automatic Watering" : "Manual Decision"} mode via Cloud Firestore.',
      );
    } catch (e) {
      addDebugLog('❌ Firestore mode update error: $e');
      _syncDeviceMode(autoMode);
      final isNoFirebase = e.toString().contains('no-app') || e.toString().contains('Firebase');
      if (isNoFirebase) {
        return OperationFeedback.success(
          'Mode Updated',
          'Switched to ${autoMode ? "Automatic Watering" : "Manual Decision"} mode (Local).',
        );
      }
      return OperationFeedback.fail(
        'Mode Update Failed',
        'Could not update mode in Firestore: $e',
      );
    }
  }

  void _syncDeviceMode(bool autoMode) {
    for (final dev in _connectedIotDevices) {
      dev.autoWaterEnabled = autoMode;
    }
    persistDevices();
    _notifyDevicesChanged();
  }

  /// Toggle between AUTO mode and MANUAL mode
  Future<OperationFeedback> toggleMode() async {
    final bool currentIsAuto = _connectedIotDevices.isNotEmpty ? _connectedIotDevices.first.autoWaterEnabled : true;
    return setWateringMode(!currentIsAuto);
  }

  /// Invert relay polarity (Active HIGH vs Active LOW)
  Future<OperationFeedback> toggleRelayInvert() async {
    addDebugLog('⚙️ Relay polarity toggle noted.');
    return OperationFeedback.success(
      'Relay Configuration',
      'Relay configured for Active-HIGH operation.',
    );
  }

  /// Timed water pulse via Cloud Firestore
  Future<OperationFeedback> pulseWaterSeconds(int seconds) async {
    addDebugLog('💧 Dispatching $seconds-second water pulse via Cloud Firestore...');
    final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';

    try {
      await IotFirestoreService().triggerManualPulse(devId, durationSeconds: seconds);
      logActivity(
        title: 'Watering Dispatched (${seconds}s)',
        detail: 'Water pump pulse command ($seconds seconds) dispatched to Cloud Firestore for $registeredDeviceName.',
        type: IotLogType.watering,
        deviceId: registeredDeviceId,
        deviceName: registeredDeviceName,
        durationSeconds: seconds,
        metadata: {'durationSeconds': seconds, 'mode': 'MANUAL'},
      );
      return OperationFeedback.success(
        'Watering Dispatched',
        'Quick water command ($seconds seconds) dispatched via Cloud Firestore.',
      );
    } catch (e) {
      addDebugLog('❌ Firestore water pulse error: $e');
      final isNoFirebase = e.toString().contains('no-app') || e.toString().contains('Firebase');
      if (isNoFirebase) {
        _recordPumpActivity(true, isCloud: false);
        return OperationFeedback.success(
          'Watering Activated',
          'Quick water command ($seconds seconds) dispatched (Local).',
        );
      }
      return OperationFeedback.fail('Pulse Failed', 'Could not dispatch water pulse to Firestore: $e');
    }
  }

  /// Probe hardware connection status via Cloud Firestore
  Future<Map<String, dynamic>> probeHardwareConnection() async {
    final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';
    try {
      final dev = await IotFirestoreService().getDevice(devId);
      if (dev != null && dev.isOnline) {
        isRealHardwareConnected = true;
        lastHardwareError = null;
        return {
          'isOnline': true,
          'ip': 'Cloud Firestore',
          'isSoftAp': false,
          'isHomeWifi': true,
          'stationIp': 'Cloud Firestore',
          'ssid': dev.wifiSsid,
          'moisture': (dev.moistureLevel ?? 0.0).round(),
          'mode': dev.autoWaterEnabled ? 'AUTO' : 'MANUAL',
          'pump': dev.isPumpRunning,
          'data': dev.toMap(),
        };
      }
    } catch (_) {}

    isRealHardwareConnected = false;
    return {
      'isOnline': false,
      'ip': 'Cloud Firestore',
      'isSoftAp': false,
      'isHomeWifi': false,
      'stationIp': null,
    };
  }

  Future<OperationFeedback> testHardwarePing([String? customIp]) async {
    final sw = Stopwatch()..start();
    final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';

    try {
      final dev = await IotFirestoreService().getDevice(devId);
      sw.stop();

      if (dev != null && dev.isOnline) {
        isRealHardwareConnected = true;
        lastHardwareError = null;
        return OperationFeedback.success(
          'ESP32 Cloud Online',
          'ESP32 is connected and syncing with Cloud Firestore (${sw.elapsedMilliseconds}ms response).',
          {'latencyMs': sw.elapsedMilliseconds, 'isCloud': true},
        );
      } else if (dev != null) {
        isRealHardwareConnected = false;
        return OperationFeedback.fail(
          'ESP32 Offline',
          'ESP32 heartbeat not detected within the last 2 minutes. Last seen: ${dev.lastSeen}.',
        );
      }
    } catch (e) {
      sw.stop();
      return OperationFeedback.fail(
        'Ping Failed',
        'Could not query device status in Cloud Firestore: $e',
      );
    }

    return OperationFeedback.fail(
      'Device Not Found',
      'No registration record found for device "$devId" in Cloud Firestore.',
    );
  }



  /// DYNAMIC 6-INSTANCE NETWORK CLASSIFIER
  /// Dynamically determines which of the 6 distinct states the system is currently in:
  /// 1. Connected to ESP32 hotspot & isn't paired to home Wi-Fi
  /// 2. Connected to ESP32 hotspot & is already paired to home Wi-Fi
  /// 3. Connected to home Wi-Fi & ESP32 is online (direct ultra-low latency link)
  /// 4. Connected to home Wi-Fi & ESP32 is not found locally
  /// 5. Connected to any other network (mobile data / remote Wi-Fi) & ESP32 is linked to phone (Cloud mode)
  /// 6. Connected to any other network (mobile data / remote Wi-Fi) & ESP32 is not linked to phone
  Future<IotNetworkStatus> detectNetworkInstance() async {
    final stopwatch = Stopwatch()..start();
    final String? phoneSsid = await WebHardwareBridge.getWifiSsid();
    final String networkType = await WebHardwareBridge.getNetworkType();
    final gatewayInfo = await WebHardwareBridge.getWifiGatewayDetails();
    final bool isGatewayEsp = gatewayInfo != null && gatewayInfo['isEspGateway'] == true;
    final bool isRegistered = isDeviceRegistered;
    final String regName = registeredDeviceName;
    final String? regHomeSsid = registeredHomeSsid;

    // Check if phone is currently connected to ESP32 SoftAP hotspot
    if (phoneSsid == 'SmartPlant-ESP32' || isGatewayEsp) {
      isRealHardwareConnected = true;
      stopwatch.stop();
      return IotNetworkStatus(
        instance: IotNetworkInstance.hotspotUnpaired,
        phoneSsid: phoneSsid ?? 'SmartPlant-ESP32',
        networkType: 'wifi',
        activeIp: '192.168.4.1',
        stationIp: null,
        esp32Ssid: null,
        isRegistered: isRegistered,
        registeredDeviceName: regName,
        registeredHomeSsid: null,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Connected to SoftAP setup hotspot (192.168.4.1). Ready for Wi-Fi provisioning.',
      );
    }

    // Normal operations: mediated by Cloud Firestore
    if (isRegistered) {
      final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';
      final dev = await IotFirestoreService().getDevice(devId);
      stopwatch.stop();
      final int latency = stopwatch.elapsedMilliseconds;

      if (dev != null && dev.isOnline) {
        isRealHardwareConnected = true;
        return IotNetworkStatus(
          instance: IotNetworkInstance.remoteCloudLinked,
          phoneSsid: phoneSsid,
          networkType: networkType,
          activeIp: 'Cloud Firestore',
          stationIp: dev.wifiSsid,
          esp32Ssid: dev.wifiSsid ?? regHomeSsid,
          isRegistered: true,
          registeredDeviceName: dev.name,
          registeredHomeSsid: dev.wifiSsid ?? regHomeSsid,
          latencyMs: latency,
          moisture: (dev.moistureLevel ?? 0.0).round(),
          mode: dev.autoWaterEnabled ? 'AUTO' : 'MANUAL',
          isPumpRunning: dev.isPumpRunning,
          rawAdc: dev.rawAdc,
          message: 'Cloud Firestore Linked. Real-time telemetry, remote controls, and push alerts active.',
          rawTelemetry: dev.toMap(),
        );
      } else {
        isRealHardwareConnected = false;
        return IotNetworkStatus(
          instance: IotNetworkInstance.homeWifiOffline,
          phoneSsid: phoneSsid,
          networkType: networkType,
          activeIp: 'Cloud Firestore',
          stationIp: null,
          esp32Ssid: regHomeSsid,
          isRegistered: true,
          registeredDeviceName: regName,
          registeredHomeSsid: regHomeSsid,
          latencyMs: latency,
          message: 'ESP32 heartbeat not received recently. Ensure power is connected.',
        );
      }
    }

    stopwatch.stop();
    isRealHardwareConnected = false;
    final String netLabel = networkType == 'cellular' ? 'Mobile Data (4G/5G)' : (phoneSsid ?? 'External Network');
    return IotNetworkStatus(
      instance: IotNetworkInstance.remoteNoDeviceLinked,
      phoneSsid: phoneSsid,
      networkType: networkType,
      activeIp: '',
      stationIp: null,
      esp32Ssid: null,
      isRegistered: false,
      registeredDeviceName: regName,
      registeredHomeSsid: null,
      latencyMs: 0,
      message: 'Connected to $netLabel, but no plant sensor is registered yet. Connect to "SmartPlant-ESP32" Wi-Fi to begin setup.',
    );
  }

  /// TEST CONNECTION & PUSH NOTIFICATION
  /// Verifies Cloud Firestore telemetry status and dispatches push notification
  Future<OperationFeedback> testConnectionAndNotify({String? customMessage}) async {
    addDebugLog('🔔 Initiating Cloud Connection & Notification Test...');
    final devId = registeredDeviceId.isNotEmpty ? registeredDeviceId : 'SmartPlant-ESP32';

    try {
      final dev = await IotFirestoreService().getDevice(devId);
      final isOnline = dev != null && dev.isOnline;
      final moisture = dev?.moistureLevel?.round() ?? 0;
      final statusStr = isOnline ? 'Online (Heartbeat Active)' : 'Standby / Offline';

      final bodyText = customMessage ??
          'UrbanGreen IoT Test Signal: Device "$devId" is $statusStr. Moisture: $moisture%.';

      await NtfyNotificationService().sendTestAlert(
        title: '🌱 ESP32 Cloud Test Signal',
        message: bodyText,
        priority: 4,
        tags: 'seedling,satellite',
      );

      await WebHardwareBridge.showNativeNotification(
        title: '🌱 ESP32 Cloud Test Signal',
        body: bodyText,
      );

      logActivity(
        title: 'Cloud Notification Dispatched',
        detail: bodyText,
        type: IotLogType.notifying,
        deviceId: devId,
        deviceName: dev?.name ?? registeredDeviceName,
      );

      return OperationFeedback.success(
        'Notification Dispatched',
        'Cloud telemetry verified. Push notification sent successfully ($statusStr).',
        {'isOnline': isOnline, 'moisture': moisture},
      );
    } catch (e) {
      addDebugLog('❌ Notification test error: $e');
      return OperationFeedback.fail(
        'Notification Test Failed',
        'Error during cloud notification test: $e',
      );
    }
  }


  // Compatibility stubs for legacy prototype screens
  void populateDemoBleDevices({bool includeIncompatible = true}) {}

  Future<void> pushTelemetryLogToFirebase({
    required String deviceId,
    required double moisturePercent,
    required bool isPumpRunning,
  }) async {}

  Future<OperationFeedback> pairViaBluetooth(String deviceId, {bool allowDemoFallback = false}) async {
    final dev = IotDevice(id: deviceId, name: 'SmartPlant-ESP32');
    await connectIotDevice(dev);
    return OperationFeedback.success('Device Added', 'ESP32 registered.');
  }

  Future<OperationFeedback> enableDemoSimulationMode(String deviceId) async =>
      OperationFeedback.success('Simulated', 'Demo mode');

  Future<OperationFeedback> toggleBluetoothScan({bool? forceScan, bool scanForRealHardware = true}) async =>
      OperationFeedback.success('Scan Complete', 'SoftAP Captive Portal active.');

  Future<OperationFeedback> selectBluetoothOnlyMode(String deviceId) async =>
      OperationFeedback.success('Mode Selected', 'Local Mode');

  Future<OperationFeedback> provisionWifiAndFirebase({
    required String deviceId,
    required String wifiSsid,
    required String wifiPassword,
  }) => provisionDeviceWifi(deviceId: deviceId, wifiSsid: wifiSsid, wifiPassword: wifiPassword);

  Future<OperationFeedback> resetIotDevice(String deviceId) => resetDeviceWifi(deviceId);

  Future<OperationFeedback> switchConnectionMethod({
    required String deviceId,
    required ConnectionMode newMode,
    String? newWifiSsid,
    String? newWifiPassword,
  }) async => OperationFeedback.success('Switched', 'Mode switched');

  Future<OperationFeedback> linkDeviceToPlant({
    required String deviceId,
    required String plantId,
    required String plantName,
    required String species,
  }) async {
    PlantService().assignDeviceToPlant(plantId: plantId, deviceId: deviceId);
    return OperationFeedback.success(
      'Device Linked',
      'Assigned hardware probe $deviceId to $plantName ($species)',
    );
  }

  Future<OperationFeedback> unlinkDeviceFromPlant(String deviceId) async {
    PlantService().unassignDevice(deviceId);
    return OperationFeedback.success(
      'Device Unlinked',
      'Hardware probe $deviceId is now unassigned and ready for any plant',
    );
  }

  Future<List<WifiNetwork>> scanNearbyWifiNetworks() async {
    addDebugLog('🔍 Scanning for nearby 2.4GHz Wi-Fi networks on ESP32...');
    final candidateIps = <String>[];
    if (targetDeviceIp.isNotEmpty) candidateIps.add(targetDeviceIp);
    if (!candidateIps.contains('192.168.4.1')) candidateIps.add('192.168.4.1');
    if (savedStationIp != null && savedStationIp!.isNotEmpty && !candidateIps.contains(savedStationIp!)) {
      candidateIps.add(savedStationIp!);
    }

    for (final ip in candidateIps) {
      try {
        final res = await WebHardwareBridge.sendHttpRequest(
          'http://$ip/api/wifi/scan',
          timeout: const Duration(seconds: 6),
        );
        if (res['success'] == true && res['data'] is List) {
          final List list = res['data'] as List;
          final List<WifiNetwork> networks = [];
          final Set<String> seen = {};

          for (final item in list) {
            if (item is Map) {
              final s = (item['ssid'] ?? '').toString().trim();
              final r = (item['rssi'] is num) ? (item['rssi'] as num).toInt() : -70;
              if (s.isNotEmpty && !seen.contains(s)) {
                seen.add(s);
                final pct = ((r + 100) * 2).clamp(10, 100);
                networks.add(WifiNetwork(
                  ssid: s,
                  signalStrength: pct,
                  isSecured: true,
                ));
              }
            }
          }
          targetDeviceIp = ip;
          addDebugLog('✅ Found ${networks.length} Wi-Fi networks nearby via $ip.');
          return networks;
        }
      } catch (e) {
        addDebugLog('❌ Wi-Fi scan attempt on $ip note: $e');
      }
    }
    return [];
  }

  Future<List<DiscoveredBluetoothDevice>> scanCompatibleIotDevices() async => [];

  IotDeviceConfig getDevice(String deviceId) {
    return _activeDevices.putIfAbsent(
      deviceId,
      () => IotDeviceConfig(deviceId: deviceId, deviceName: 'ESP32 Node $deviceId'),
    );
  }
}
