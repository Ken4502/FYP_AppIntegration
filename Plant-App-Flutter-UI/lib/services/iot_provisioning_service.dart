import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      await sendCredentialsToSoftAP(
        ssid: ssid,
        password: password,
        setupToken: setupToken,
        deviceId: deviceId,
      );

      // 3. Cloud verification with timeout
      return await verifyConnectionInCloud(
        setupToken: setupToken,
        deviceId: deviceId,
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
  Future<bool> sendCredentialsToSoftAP({
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('ESP32 returned HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Re-throw with clear message
      throw Exception('Failed to transmit credentials to ESP32 SoftAP ($e). Ensure phone is connected to ESP32 Wi-Fi hotspot.');
    }
  }

  /// Step 3: Listen to Cloud Firestore for connection confirmation
  /// (with 20-second timeout while phone falls back to normal internet)
  Future<ProvisioningResult> verifyConnectionInCloud({
    required String setupToken,
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final docRef = _firestore.collection('provisioning').doc(setupToken);

    final completer = Completer<ProvisioningResult>();
    StreamSubscription<DocumentSnapshot>? subscription;
    Timer? timeoutTimer;

    timeoutTimer = Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(
          ProvisioningResult(
            isSuccess: false,
            message: 'Connection verification timed out after 20 seconds. Please reconnect to ESP32 hotspot and check Wi-Fi password.',
            deviceId: deviceId,
          ),
        );
      }
    });

    subscription = docRef.snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data() ?? {};
        final status = (data['status'] ?? 'pending').toString().toLowerCase();

        if (status == 'connected') {
          timeoutTimer?.cancel();
          subscription?.cancel();

          final ip = data['ip']?.toString();
          final ssid = data['ssid']?.toString();

          // Ensure device record exists in iot_devices collection
          await _registerOrUpdateDeviceRecord(
            deviceId: deviceId,
            ssid: ssid ?? '',
            ip: ip,
          );

          if (!completer.isCompleted) {
            completer.complete(
              ProvisioningResult(
                isSuccess: true,
                message: 'ESP32 successfully connected to Wi-Fi and synced with Cloud Firestore!',
                deviceId: deviceId,
                ip: ip,
                ssid: ssid,
              ),
            );
          }
        } else if (status == 'failed') {
          timeoutTimer?.cancel();
          subscription?.cancel();

          final errorMsg = data['errorMessage']?.toString() ?? 'Wi-Fi connection failed.';
          if (!completer.isCompleted) {
            completer.complete(
              ProvisioningResult(
                isSuccess: false,
                message: errorMsg,
                deviceId: deviceId,
              ),
            );
          }
        }
      },
      onError: (err) {
        // Continue waiting until timeout or resolve
      },
    );

    return completer.future;
  }

  /// Creates or updates the operational device document in `iot_devices/{deviceId}`
  Future<void> _registerOrUpdateDeviceRecord({
    required String deviceId,
    required String ssid,
    String? ip,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final deviceDoc = _firestore.collection('iot_devices').doc(deviceId);
    final existing = await deviceDoc.get();

    final updates = <String, dynamic>{
      'id': deviceId,
      'userId': user.uid,
      'registeredBy': user.uid,
      'ssid': ssid,
      'isWifiConnected': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (ip != null && ip.isNotEmpty) {
      updates['stationIp'] = ip;
    }

    if (!existing.exists) {
      updates.addAll({
        'name': 'Smart Plant Probe',
        'firmwareVersion': 'v4.1.0-StateMachine',
        'mode': 'MANUAL',
        'autoWaterEnabled': false, // Watering turned OFF by default!
        'lowThreshold': 25,
        'highThreshold': 45,
        'moisturePercent': 0.0,
        'rawADC': 4095,
        'isPumpRunning': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await deviceDoc.set(updates);
    } else {
      await deviceDoc.set(updates, SetOptions(merge: true));
    }
  }
}
