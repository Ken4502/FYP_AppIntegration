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
    if (uid == null || uid.isEmpty) {
      return Stream.value([]);
    }

    // Listen to all devices where linkedUserIds contains current user
    return _devicesCol
        .where('linkedUserIds', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<IotDevice> list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return IotDevice.fromMap(data);
      }).toList();

      // Check legacy devices where userId == uid but not yet in linkedUserIds array
      try {
        final legacySnap = await _devicesCol
            .where('userId', isEqualTo: uid)
            .limit(10)
            .get();
        for (final doc in legacySnap.docs) {
          if (!list.any((d) => d.id == doc.id)) {
            final data = doc.data();
            data['id'] = doc.id;
            final dev = IotDevice.fromMap(data);
            list.add(dev);
            // Self-heal/migrate in background
            doc.reference.update({
              'linkedUserIds': FieldValue.arrayUnion([uid]),
            }).catchError((_) {});
          }
        }
      } catch (_) {}

      return _deduplicateDevices(list);
    });
  }

  /// Deduplicates device lists in memory and cleans up any ghost/legacy placeholder documents.
  /// 1. Removes documents with identical IDs.
  /// 2. If a canonical hardware device (MAC-based, e.g. SmartPlant-20FB3F) exists, any generic
  ///    placeholder ("SmartPlant-ESP32") is discarded and cleaned up from Firestore.
  /// 3. If two records share the same local station IP, keeps the freshest authoritative one.
  List<IotDevice> _deduplicateDevices(List<IotDevice> rawList) {
    if (rawList.isEmpty) return [];

    // Step 1: Deduplicate by exact device ID
    final Map<String, IotDevice> byId = {};
    for (final dev in rawList) {
      byId[dev.id] = dev;
    }

    final List<IotDevice> uniqueList = byId.values.toList();
    final bool hasCanonicalHardware = uniqueList.any((d) => _isCanonicalHardwareId(d.id));

    // Step 2: Purge generic prototype "SmartPlant-ESP32" if real hardware exists
    if (hasCanonicalHardware) {
      uniqueList.removeWhere((d) {
        if (d.id == 'SmartPlant-ESP32') {
          // Clean up orphaned legacy doc in background
          _devicesCol.doc('SmartPlant-ESP32').delete().catchError((_) {});
          return true;
        }
        return false;
      });
    }

    // Step 3: Deduplicate by Station IP (same physical board on same local subnet)
    final Map<String, IotDevice> byIp = {};
    final List<IotDevice> result = [];

    for (final dev in uniqueList) {
      final ip = dev.stationIp?.trim();
      if (ip != null && ip.isNotEmpty && ip != '0.0.0.0' && ip != '192.168.4.1') {
        if (byIp.containsKey(ip)) {
          final existing = byIp[ip]!;
          final bool replaceExisting = (!_isCanonicalHardwareId(existing.id) && _isCanonicalHardwareId(dev.id)) ||
              dev.lastSeen.isAfter(existing.lastSeen);

          if (replaceExisting) {
            result.remove(existing);
            result.add(dev);
            byIp[ip] = dev;
            if (existing.id == 'SmartPlant-ESP32') {
              _devicesCol.doc(existing.id).delete().catchError((_) {});
            }
          }
        } else {
          byIp[ip] = dev;
          result.add(dev);
        }
      } else {
        result.add(dev);
      }
    }

    return result;
  }

  bool _isCanonicalHardwareId(String id) {
    return RegExp(r'^SmartPlant-[A-Fa-f0-9]{4,12}$').hasMatch(id);
  }

  /// Single fetch of all user devices
  Future<List<IotDevice>> getUserDevices([String? targetUserId]) async {
    final uid = targetUserId ?? currentUserId;
    if (uid == null || uid.isEmpty) return [];

    try {
      final query = await _devicesCol.where('linkedUserIds', arrayContains: uid).get();
      final list = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return IotDevice.fromMap(data);
      }).toList();

      // Also include legacy records if any
      final legacySnap = await _devicesCol.where('userId', isEqualTo: uid).limit(10).get();
      for (final doc in legacySnap.docs) {
        if (!list.any((d) => d.id == doc.id)) {
          final data = doc.data();
          data['id'] = doc.id;
          list.add(IotDevice.fromMap(data));
        }
      }

      return _deduplicateDevices(list);
    } catch (_) {
      return [];
    }
  }

  /// Links a user account to an existing IoT device (e.g. found on the same local Wi-Fi)
  Future<void> linkUserToDevice(String deviceId, [String? targetUserId]) async {
    final uid = targetUserId ?? currentUserId;
    if (uid == null || uid.isEmpty) {
      throw Exception('Authentication required to link device.');
    }

    await _devicesCol.doc(deviceId).set({
      'linkedUserIds': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'User Linked Device',
      detail: 'Account ($uid) was linked to this probe over Wi-Fi network.',
      type: IotLogType.network,
    );
  }

  /// Unlinks a specific user account from the device (does NOT reset hardware or erase for other users)
  Future<void> unlinkUserFromDevice(String deviceId, [String? targetUserId]) async {
    final uid = targetUserId ?? currentUserId;
    if (uid == null || uid.isEmpty) return;

    await _devicesCol.doc(deviceId).update({
      'linkedUserIds': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addDeviceLog(
      deviceId,
      title: 'User Unlinked Device',
      detail: 'Account ($uid) unlinked probe from their mobile view.',
      type: IotLogType.network,
    );
  }

  /// Find online devices on the same Wi-Fi network that can be linked by any account
  Future<List<IotDevice>> discoverOnlineDevicesOnWifi({String? wifiSsid}) async {
    try {
      Query<Map<String, dynamic>> query = _devicesCol;
      if (wifiSsid != null && wifiSsid.trim().isNotEmpty) {
        query = query.where('wifiSsid', isEqualTo: wifiSsid.trim());
      }
      final snap = await query.limit(20).get();
      final now = DateTime.now();
      final List<IotDevice> results = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final dev = IotDevice.fromMap(data);
        // Include devices with wifi connected or seen within 30 minutes
        if (dev.isWifiConnected || now.difference(dev.lastSeen).inMinutes < 30) {
          results.add(dev);
        }
      }
      return results;
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

  /// Updates systemState and stateReason on an IoT device document
  Future<void> setDeviceSystemState(
    String deviceId,
    String systemState,
    String reason,
  ) async {
    try {
      await _devicesCol.doc(deviceId).set({
        'systemState': systemState,
        'stateReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Mark device as offline when heartbeat times out
  Future<void> markDeviceOffline(String deviceId, [String reason = 'Heartbeat timeout']) async {
    try {
      await _devicesCol.doc(deviceId).set({
        'systemState': 'OFFLINE',
        'stateReason': reason,
        'isWifiConnected': false,
        'wifiConnected': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await addDeviceLog(
        deviceId,
        title: 'Device Offline',
        detail: reason,
        type: IotLogType.network,
      );
    } catch (_) {}
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

  /// Strict 1-to-1 Plant linking.
  /// Changing or assigning a specimen completely purges previous logs and restores
  /// device functionalities to clean default configurations calibrated for the specimen.
  Future<void> linkPlant(
    String deviceId, {
    required String plantId,
    required String plantName,
    String? plantImage,
    int? optimalMinMoisture,
    int? optimalMaxMoisture,
  }) async {
    // 1. Completely purge historical logs from the previous plant
    await clearDeviceLogs(deviceId);

    // 2. Reset device functionalities to safe factory defaults for the new plant
    final low = optimalMinMoisture ?? 25;
    final high = optimalMaxMoisture ?? 45;

    await _devicesCol.doc(deviceId).set({
      'linkedPlantId': plantId,
      'linkedPlantName': plantName,
      'linkedPlantImage': plantImage,
      'mode': 'MANUAL',
      'autoWaterEnabled': false,
      'isPumpRunning': false,
      'lowThreshold': low,
      'lowMoistureThreshold': low,
      'highThreshold': high,
      'highMoistureThreshold': high,
      'isLowMoistureAlertIgnored': false,
      'lowMoistureAlwaysIgnored': false,
      'lowMoistureIgnoredUntil': null,
      'lastAlertSentAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Add clean initial log for the newly linked plant
    await addDeviceLog(
      deviceId,
      title: 'Specimen Assigned: $plantName',
      detail: 'Probe linked. Previous logs wiped and functionalities reset to default manual care ($low% - $high%).',
      type: IotLogType.system,
    );
  }

  /// Unlink current plant.
  /// Completely purges all previous logs and restores device functionalities to clean defaults.
  Future<void> unlinkPlant(String deviceId) async {
    // 1. Purge all previous logs
    await clearDeviceLogs(deviceId);

    // 2. Revert device functionalities to clean defaults
    await _devicesCol.doc(deviceId).set({
      'linkedPlantId': null,
      'linkedPlantName': null,
      'linkedPlantImage': null,
      'mode': 'MANUAL',
      'autoWaterEnabled': false,
      'isPumpRunning': false,
      'lowThreshold': 25,
      'lowMoistureThreshold': 25,
      'highThreshold': 45,
      'highMoistureThreshold': 45,
      'isLowMoistureAlertIgnored': false,
      'lowMoistureAlwaysIgnored': false,
      'lowMoistureIgnoredUntil': null,
      'lastAlertSentAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addDeviceLog(
      deviceId,
      title: 'Plant Unlinked',
      detail: 'Specimen unlinked. All previous logs cleared and functionalities reverted to default configuration.',
      type: IotLogType.system,
    );
  }

  /// Delete all activity and watering logs in `iot_devices/{deviceId}/logs`
  Future<void> clearDeviceLogs(String deviceId) async {
    try {
      final logsSnapshot = await _devicesCol.doc(deviceId).collection('logs').get();
      final batch = _firestore.batch();
      for (final doc in logsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
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

  /// Delete / Unpair device from Cloud Firestore (Wiping all data & logs)
  Future<void> deleteDevice(String deviceId) async {
    try {
      // 1. Attempt to dispatch FACTORY_RESET command first if device document exists
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
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}

    // 2. Completely delete all subcollection activity logs
    await clearDeviceLogs(deviceId);

    // 3. Delete the root device document
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
