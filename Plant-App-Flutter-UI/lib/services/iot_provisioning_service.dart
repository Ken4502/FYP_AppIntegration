import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'weather_service.dart';

enum ProvisioningState {
  initial,
  creatingToken,
  connectingToHotspot,
  sendingCredentials,
  verifyingCloud,
  success,
  failed,
  timeout,
}

class ProvisioningResult {
  final bool isSuccess;
  final String message;
  final String? deviceId;
  final String? ip;
  final String? ssid;

  ProvisioningResult({
    required this.isSuccess,
    required this.message,
    this.deviceId,
    this.ip,
    this.ssid,
  });
}

class IotProvisioningService {
  static final IotProvisioningService _instance = IotProvisioningService._internal();
  factory IotProvisioningService() => _instance;
  IotProvisioningService._internal();

  static const String softApIp = '192.168.4.1';
  static const String provisionEndpoint = 'http://$softApIp/provision';
  static const String statusEndpoint = 'http://$softApIp/status';
  static const String scanEndpoint = 'http://$softApIp/scan';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Detect whether the phone is connected to the ESP32 SoftAP hotspot
  Future<Map<String, dynamic>?> checkHotspotStatus({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final res = await http.get(Uri.parse(statusEndpoint)).timeout(timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Request the ESP32 to scan for nearby 2.4GHz Wi-Fi networks
  Future<List<Map<String, dynamic>>> scanWifiNetworks({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final res = await http.get(Uri.parse(scanEndpoint)).timeout(timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final networks = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // Sort networks by signal strength (RSSI descending)
        networks.sort((a, b) => ((b['rssi'] as num?) ?? -100).compareTo((a['rssi'] as num?) ?? -100));
        return networks;
      }
    } catch (_) {}
    return [];
  }

  String generateSetupToken() {
    final random = Random.secure();
    final values = List<int>.generate(8, (i) => random.nextInt(256));
    final hexString = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'prov_${DateTime.now().millisecondsSinceEpoch}_$hexString';
  }

  /// Step 1: Pre-Setup in Firestore while phone still has internet
  Future<String> createPendingProvisioningSession({
    required String deviceId,
    required String ssid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to provision an IoT device.');
    }

    final setupToken = generateSetupToken();

    await _firestore.collection('provisioning').doc(setupToken).set({
      'setupToken': setupToken,
      'userId': user.uid,
      'deviceId': deviceId,
      'status': 'pending',
      'ssid': ssid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return setupToken;
  }

  /// Full Provisioning Orchestration:
  /// 1. Create pending Firestore record (phone has internet)
  /// 2. Transmit Wi-Fi credentials to ESP32 SoftAP at 192.168.4.1/provision
  /// 3. Verify connection in Cloud Firestore as ESP32 connects and writes status: "connected"
  Future<ProvisioningResult> executeProvisioning({
    required String deviceId,
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      // 1. Pre-setup in Firestore while phone still has internet
      String setupToken;
      try {
        setupToken = await createPendingProvisioningSession(
          deviceId: deviceId,
          ssid: ssid,
        );
      } catch (e) {
        // Fallback: generate local setupToken if internet is already disconnected
        setupToken = generateSetupToken();
      }

      // 2. Deliver credentials to ESP32 SoftAP (192.168.4.1/provision)
      final effectiveDeviceId = await sendCredentialsToSoftAP(
        ssid: ssid,
        password: password,
        setupToken: setupToken,
        deviceId: deviceId,
      );

      // 3. Cloud verification with timeout
      return await verifyConnectionInCloud(
        setupToken: setupToken,
        deviceId: effectiveDeviceId,
        ssid: ssid,
        timeout: timeout,
      );
    } catch (e) {
      return ProvisioningResult(
        isSuccess: false,
        message: e.toString().replaceFirst('Exception: ', ''),
        deviceId: deviceId,
      );
    }
  }


  /// Step 2: Credential Delivery via SoftAP HTTP POST to 192.168.4.1/provision
  /// Returns the canonical hardware deviceId confirmed by the ESP32 (e.g. SmartPlant-20FB3F).
  Future<String> sendCredentialsToSoftAP({
    required String ssid,
    required String password,
    required String setupToken,
    required String deviceId,
  }) async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? 'unknown_user';

    final uri = Uri.parse(provisionEndpoint);
    final payload = jsonEncode({
      'ssid': ssid,
      'pass': password,
      'setupToken': setupToken,
      'userId': userId,
      'deviceId': deviceId,
    });

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String resolvedDeviceId = deviceId;
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['deviceId'] != null && data['deviceId'].toString().trim().isNotEmpty) {
            resolvedDeviceId = data['deviceId'].toString().trim();
          }
        } catch (_) {}
        return resolvedDeviceId;
      } else {
        String errorMsg = 'Wi-Fi connection failed.';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['error'] != null) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } on TimeoutException {
      throw Exception('Connection to ESP32 timed out. Ensure your phone remains connected to "ESP32_Plant_Irrigation".');
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw Exception(msg);
    }
  }

  /// Step 3: Listen to Cloud Firestore for connection confirmation
  /// (with active multi-listener and fast polling fallback while phone switches networks)
  Future<ProvisioningResult> verifyConnectionInCloud({
    required String setupToken,
    required String deviceId,
    String? ssid,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    final provDocRef = _firestore.collection('provisioning').doc(setupToken);
    final devDocRef = _firestore.collection('iot_devices').doc(deviceId);

    final completer = Completer<ProvisioningResult>();
    StreamSubscription<DocumentSnapshot>? provSubscription;
    StreamSubscription<DocumentSnapshot>? devSubscription;
    StreamSubscription<QuerySnapshot>? userQuerySubscription;
    Timer? timeoutTimer;
    Timer? fastPollTimer;

    void cleanup() {
      timeoutTimer?.cancel();
      fastPollTimer?.cancel();
      provSubscription?.cancel();
      devSubscription?.cancel();
      userQuerySubscription?.cancel();
    }

    void handleSuccess({
      required String resolvedDeviceId,
      String? ip,
      String? ssid,
    }) {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(
          ProvisioningResult(
            isSuccess: true,
            message: 'ESP32 successfully connected to Wi-Fi and synced with Cloud Firestore!',
            deviceId: resolvedDeviceId,
            ip: ip,
            ssid: ssid,
          ),
        );
      }
    }

    void handleFailure(String message) {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(
          ProvisioningResult(
            isSuccess: false,
            message: message,
            deviceId: deviceId,
          ),
        );
      }
    }

    timeoutTimer = Timer(timeout, () {
      handleFailure('Connection verification timed out after ${timeout.inSeconds} seconds. Please ensure the probe is powered on and within router range.');
    });

    // Helper to evaluate device data
    bool evaluateDeviceData(Map<String, dynamic> data, String docId) {
      final bool isOnline = (data['isWifiConnected'] == true || data['wifiConnected'] == true);
      final String sysState = (data['systemState'] ?? '').toString();
      final String? ip = data['stationIp']?.toString();
      final String? ssid = data['wifiSsid']?.toString() ?? data['ssid']?.toString();

      // Check if lastSeen is recent (within 45s)
      bool hasRecentHeartbeat = false;
      if (data['lastSeen'] is Timestamp) {
        final age = DateTime.now().difference((data['lastSeen'] as Timestamp).toDate()).inSeconds.abs();
        if (age <= 45) hasRecentHeartbeat = true;
      }

      if (isOnline || sysState == 'CONNECTED_ONLINE' || (hasRecentHeartbeat && (ip != null && ip.isNotEmpty))) {
        handleSuccess(
          resolvedDeviceId: docId,
          ip: ip,
          ssid: ssid,
        );
        return true;
      }
      return false;
    }

    // 1. Primary Check: Direct telemetry report in iot_devices/{deviceId}
    devSubscription = devDocRef.snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data() ?? {};
        evaluateDeviceData(data, deviceId);
      },
      onError: (_) {},
    );

    // 2. Query listener for user's devices (catches if ID resolved to another hardware ID)
    if (uid != null && uid.isNotEmpty) {
      userQuerySubscription = _firestore
          .collection('iot_devices')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen(
        (snap) {
          for (final doc in snap.docs) {
            final data = doc.data();
            if (evaluateDeviceData(data, doc.id)) break;
          }
        },
        onError: (_) {},
      );
    }

    // 3. Secondary Check: provisioning/{setupToken}
    provSubscription = provDocRef.snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data() ?? {};
        final status = (data['status'] ?? 'pending').toString().toLowerCase();

        if (status == 'connected') {
          final ip = data['ip']?.toString();
          final ssid = data['ssid']?.toString();

          // Ensure device record exists in iot_devices collection
          await _registerOrUpdateDeviceRecord(
            deviceId: deviceId,
            ssid: ssid ?? '',
            ip: ip,
            isOnline: true,
          );

          handleSuccess(
            resolvedDeviceId: deviceId,
            ip: ip,
            ssid: ssid,
          );
        } else if (status == 'failed') {
          final errorMsg = data['errorMessage']?.toString() ?? 'Wi-Fi connection failed.';
          handleFailure(errorMsg);
        }
      },
      onError: (_) {},
    );

    // 4. Fast Polling Loop (every 1.5s):
    // In mobile environments, socket handoff between SoftAP and Router/Cellular can delay
    // snapshot events. Active polling ensures instantaneous detection the moment internet restores!
    fastPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (completer.isCompleted) {
        cleanup();
        return;
      }
      try {
        // Direct doc poll
        final docSnap = await devDocRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          if (evaluateDeviceData(docSnap.data()!, deviceId)) return;
        } else {
          // Self-heal: Once mobile phone leaves SoftAP and re-establishes internet,
          // proactively create/ensure the device document exists in Firestore under user ownership!
          // This allows the ESP32's telemetry PATCH to immediately succeed with 200 OK!
          await createOrEnsureDeviceRecord(
            deviceId: deviceId,
            ssid: ssid ?? '',
            isOnline: false,
          ).catchError((_) {});
        }

        // User devices query poll
        if (uid != null && uid.isNotEmpty) {
          final userSnap = await _firestore
              .collection('iot_devices')
              .where('userId', isEqualTo: uid)
              .get();
          for (final doc in userSnap.docs) {
            if (evaluateDeviceData(doc.data(), doc.id)) return;
          }
        }

        // Provisioning doc poll
        final pSnap = await provDocRef.get();
        if (pSnap.exists && pSnap.data() != null) {
          final pData = pSnap.data()!;
          final st = (pData['status'] ?? '').toString().toLowerCase();
          if (st == 'connected') {
            final ip = pData['ip']?.toString();
            final ssid = pData['ssid']?.toString();
            handleSuccess(resolvedDeviceId: deviceId, ip: ip, ssid: ssid);
            return;
          }
        }
      } catch (_) {}
    });

    return completer.future;
  }

  /// Public method to ensure device document exists in `iot_devices/{deviceId}`
  Future<void> createOrEnsureDeviceRecord({
    required String deviceId,
    required String ssid,
    String? ip,
    bool isOnline = false,
  }) async {
    return _registerOrUpdateDeviceRecord(
      deviceId: deviceId,
      ssid: ssid,
      ip: ip,
      isOnline: isOnline,
    );
  }

  /// Creates or updates the operational device document in `iot_devices/{deviceId}`
  Future<void> _registerOrUpdateDeviceRecord({
    required String deviceId,
    required String ssid,
    String? ip,
    bool isOnline = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String effectiveDeviceId = deviceId.trim();

    // Long-Term Anti-Duplication Guard:
    // If the caller passed the generic legacy string "SmartPlant-ESP32" or an empty ID,
    // check if the user already has a canonical hardware device (e.g. SmartPlant-20FB3F).
    // If so, update that real hardware record instead of spawning a duplicate!
    if (effectiveDeviceId.isEmpty || effectiveDeviceId == 'SmartPlant-ESP32') {
      try {
        final existingQuery = await _firestore
            .collection('iot_devices')
            .where('linkedUserIds', arrayContains: user.uid)
            .get();
        final canonicalDocs = existingQuery.docs.where((d) => RegExp(r'^SmartPlant-[A-Fa-f0-9]{4,12}$').hasMatch(d.id));
        if (canonicalDocs.isNotEmpty) {
          effectiveDeviceId = canonicalDocs.first.id;
        }
      } catch (_) {}
    }

    if (effectiveDeviceId.isEmpty) {
      effectiveDeviceId = 'SmartPlant-ESP32';
    }

    final deviceDoc = _firestore.collection('iot_devices').doc(effectiveDeviceId);
    final existing = await deviceDoc.get();

    final updates = <String, dynamic>{
      'id': effectiveDeviceId,
      'userId': user.uid,
      'registeredBy': user.uid,
      'linkedUserIds': FieldValue.arrayUnion([user.uid]),
      'ssid': ssid,
      'wifiSsid': ssid,
      'isWifiConnected': isOnline,
      'wifiConnected': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (ip != null && ip.isNotEmpty) {
      updates['stationIp'] = ip;
    }

    if (!existing.exists) {
      // Pre-determine IoT physical location based on mobile phone's location during setup
      UserLocation? initialLoc;
      try {
        initialLoc = await WeatherService().resolveUserLocation();
      } catch (_) {}

      updates.addAll({
        'name': 'Smart Plant Probe',
        'firmwareVersion': 'v4.1.0-StateMachine',
        'mode': 'MANUAL',
        'autoWaterEnabled': false, // Watering turned OFF by default!
        'lowThreshold': 25,
        'highThreshold': 65, // Standard optimal target (65%)
        'moisturePercent': 0.0,
        'rawADC': 4095,
        'isPumpRunning': false,
        'isIndoor': true,
        'environment': 'indoor',
        'locationCity': initialLoc?.city ?? 'Kuala Lumpur',
        'locationRegion': initialLoc?.region ?? 'Federal Territory',
        'locationCountry': initialLoc?.country ?? 'Malaysia',
        'locationLatitude': initialLoc?.latitude ?? 3.1390,
        'locationLongitude': initialLoc?.longitude ?? 101.6869,
        'city': initialLoc?.city ?? 'Kuala Lumpur',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await deviceDoc.set(updates);
    } else {
      // If updating an existing device that lacks a bound location, backfill it
      final data = existing.data() ?? {};
      if (data['locationCity'] == null && data['city'] == null) {
        try {
          final initialLoc = await WeatherService().resolveUserLocation();
          updates.addAll({
            'locationCity': initialLoc.city,
            'locationRegion': initialLoc.region,
            'locationCountry': initialLoc.country,
            'locationLatitude': initialLoc.latitude,
            'locationLongitude': initialLoc.longitude,
            'city': initialLoc.city,
            'isIndoor': data['isIndoor'] ?? true,
            'environment': data['environment'] ?? 'indoor',
          });
        } catch (_) {}
      }
      await deviceDoc.set(updates, SetOptions(merge: true));
    }

    // Clean up stale legacy ghost "SmartPlant-ESP32" if a real hardware probe exists
    if (effectiveDeviceId != 'SmartPlant-ESP32') {
      try {
        final ghostRef = _firestore.collection('iot_devices').doc('SmartPlant-ESP32');
        final ghostSnap = await ghostRef.get();
        if (ghostSnap.exists) {
          await ghostRef.delete();
        }
      } catch (_) {}
    }
  }
}
