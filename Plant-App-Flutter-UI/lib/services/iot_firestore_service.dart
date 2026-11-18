import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/iot_device_model.dart';
import 'iot_hybrid_connectivity_service.dart' show IotActivityLog, IotLogType;

class IotFirestoreService {
  static final IotFirestoreService _instance = IotFirestoreService._internal();
  factory IotFirestoreService() => _instance;
  IotFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _devicesCol =>
      _firestore.collection('iot_devices');

  /// Dynamic computation of device online/offline status based on lastSeen heartbeat
  bool isDeviceOnline(DateTime? lastSeen, {Duration timeout = const Duration(minutes: 2)}) {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen) <= timeout;
  }

  /// Real-time stream of a specific IoT device document
  Stream<IotDevice?> streamDevice(String deviceId) {
    return _devicesCol.doc(deviceId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data()!;
      data['id'] = snapshot.id;
      return IotDevice.fromMap(data);
    });
  }

  /// Single fetch of a specific IoT device
  Future<IotDevice?> getDevice(String deviceId) async {
    try {
      final doc = await _devicesCol.doc(deviceId).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return IotDevice.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  /// Real-time stream of all devices registered to the given user or current user
  Stream<List<IotDevice>> streamUserDevices([String? targetUserId]) {
    final uid = targetUserId ?? currentUserId;
    if (uid == null) {
      return Stream.value([]);
    }

    // Listen to all devices where userId or registeredBy matches
    return _devicesCol
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return IotDevice.fromMap(data);
      }).toList();
    });
  }

  /// Single fetch of all user devices
  Future<List<IotDevice>> getUserDevices([String? targetUserId]) async {
    final uid = targetUserId ?? currentUserId;
    if (uid == null) return [];

    try {
      final query = await _devicesCol.where('userId', isEqualTo: uid).get();
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return IotDevice.fromMap(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Update soil moisture thresholds in Firestore
  Future<void> updateThresholds(
    String deviceId, {
    required int lowThreshold,
    required int highThreshold,
  }) async {
    await _devicesCol.doc(deviceId).set({
      'lowThreshold': lowThreshold,
      'lowMoistureThreshold': lowThreshold,
      'highThreshold': highThreshold,
      'highMoistureThreshold': highThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Thresholds Updated',
      detail: 'Moisture target configured to $lowThreshold% - $highThreshold%.',
      type: IotLogType.system,
    );
  }

  /// Switch between Automatic Watering and Manual Decision mode
  Future<void> setWateringMode(String deviceId, {required bool autoWaterEnabled}) async {
    final modeStr = autoWaterEnabled ? 'AUTO' : 'MANUAL';
    await _devicesCol.doc(deviceId).set({
      'mode': modeStr,
      'autoWaterEnabled': autoWaterEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Watering Mode Changed',
      detail: 'Switched to ${autoWaterEnabled ? "Automatic Watering" : "Manual Decision"} mode.',
      type: IotLogType.system,
    );
  }

  /// Trigger a manual water pulse (e.g. 3 to 5 seconds) via pendingCommand in Firestore
  Future<void> triggerManualPulse(String deviceId, {int durationSeconds = 3}) async {
    final cmdId = 'cmd_${DateTime.now().millisecondsSinceEpoch}';
    await _devicesCol.doc(deviceId).set({
      'pendingCommand': {
        'command': 'PULSE',
        'commandId': cmdId,
        'durationSeconds': durationSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'executed': false,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Manual Watering Triggered',
      detail: 'Quick water command ($durationSeconds seconds) dispatched via Cloud Firestore.',
      type: IotLogType.watering,
      durationSeconds: durationSeconds,
    );
  }

  /// Set pump state (START/STOP)
  Future<void> setPumpState(String deviceId, bool isRunning) async {
    final cmdId = 'cmd_${DateTime.now().millisecondsSinceEpoch}';
    await _devicesCol.doc(deviceId).set({
      'pendingCommand': {
        'command': isRunning ? 'PUMP_ON' : 'PUMP_OFF',
        'commandId': cmdId,
        'timestamp': FieldValue.serverTimestamp(),
        'executed': false,
      },
      'isPumpRunning': isRunning,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: isRunning ? 'Pump Activated' : 'Pump Deactivated',
      detail: isRunning ? 'Emergency/Manual pump started.' : 'Pump stopped.',
      type: IotLogType.watering,
    );
  }

  /// Strict 1-to-1 Plant linking
  Future<void> linkPlant(
    String deviceId, {
    required String plantId,
    required String plantName,
    String? plantImage,
  }) async {
    await _devicesCol.doc(deviceId).set({
      'linkedPlantId': plantId,
      'linkedPlantName': plantName,
      'linkedPlantImage': plantImage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Plant Linked',
      detail: 'Sensor paired to specimen "$plantName".',
      type: IotLogType.system,
    );
  }

  /// Unlink current plant
  Future<void> unlinkPlant(String deviceId) async {
    await _devicesCol.doc(deviceId).set({
      'linkedPlantId': null,
      'linkedPlantName': null,
      'linkedPlantImage': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Plant Unlinked',
      detail: 'Sensor specimen unlinked.',
      type: IotLogType.system,
    );
  }

  /// Rename device
  Future<void> renameDevice(String deviceId, String newName) async {
    await _devicesCol.doc(deviceId).set({
      'name': newName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Dispatches a remote FACTORY_RESET command to the ESP32 via Firestore pendingCommand.
  /// When online, the ESP32 receives this command, wipes its Wi-Fi credentials in NVS,
  /// and restarts cleanly into SoftAP mode (ESP32_Plant_Irrigation) for setup/reconfiguration.
  Future<void> sendResetCommand(String deviceId) async {
    final cmdId = 'cmd_reset_${DateTime.now().millisecondsSinceEpoch}';
    await _devicesCol.doc(deviceId).set({
      'pendingCommand': {
        'command': 'FACTORY_RESET',
        'commandId': cmdId,
        'timestamp': FieldValue.serverTimestamp(),
        'executed': false,
      },
      'systemState': 'FACTORY_RESETTING',
      'stateReason': 'Reboot into setup mode requested for Wi-Fi reconfiguration',
      'isWifiConnected': false,
      'wifiSsid': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Setup Mode Requested',
      detail: 'ESP32 commanded to erase Wi-Fi and reboot into SoftAP setup mode (ESP32_Plant_Irrigation).',
      type: IotLogType.system,
    );
  }

  /// Full Factory Reset & Wipe Cycle:
  /// Dispatches remote FACTORY_RESET command to ESP32 (if online) to wipe NVS preferences,
  /// then removes the device document from Cloud Firestore.
  Future<void> factoryResetDevice(String deviceId) async {
    try {
      // 1. Dispatch FACTORY_RESET remote command so ESP32 clears its NVS
      final cmdId = 'cmd_reset_${DateTime.now().millisecondsSinceEpoch}';
      await _devicesCol.doc(deviceId).set({
        'pendingCommand': {
          'command': 'FACTORY_RESET',
          'commandId': cmdId,
          'timestamp': FieldValue.serverTimestamp(),
          'executed': false,
        },
        'systemState': 'FACTORY_RESETTING',
        'stateReason': 'Factory reset requested from mobile app',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Allow brief window for ESP32 sync cycle if online
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (_) {}

    // 3. Delete the device document from Cloud Firestore
    await deleteDevice(deviceId);
  }

  /// Delete / Unpair device from Cloud Firestore
  Future<void> deleteDevice(String deviceId) async {
    try {
      // Attempt to dispatch FACTORY_RESET command first if device document exists
      final cmdId = 'cmd_wipe_${DateTime.now().millisecondsSinceEpoch}';
      await _devicesCol.doc(deviceId).set({
        'pendingCommand': {
          'command': 'FACTORY_RESET',
          'commandId': cmdId,
          'timestamp': FieldValue.serverTimestamp(),
          'executed': false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {}

    await _devicesCol.doc(deviceId).delete();
  }

  /// Stream real-time activity and watering logs from `iot_devices/{deviceId}/logs`
  Stream<List<IotActivityLog>> streamDeviceLogs(String deviceId, {int limit = 50}) {
    return _devicesCol
        .doc(deviceId)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Parse timestamp if it's a Firestore Timestamp
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        return IotActivityLog.fromMap(data);
      }).toList();
    });
  }

  /// Add an activity / watering log entry to `iot_devices/{deviceId}/logs`
  Future<void> addDeviceLog(
    String deviceId, {
    required String title,
    required String detail,
    required IotLogType type,
    int? durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _devicesCol.doc(deviceId).collection('logs').add({
        'title': title,
        'detail': detail,
        'type': type.name,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (metadata != null) 'metadata': metadata,
      });
    } catch (_) {}
  }
}
