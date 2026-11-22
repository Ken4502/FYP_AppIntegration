import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/iot_device_model.dart';
import 'iot_firestore_service.dart';
import 'iot_hybrid_connectivity_service.dart';
import 'platform/web_hardware_bridge.dart';

/// Background IoT Presence & Heartbeat Watchdog Service
///
/// Responsibilities:
/// 1. Continuously tracks live heartbeat signals (`lastSeen`) from user's IoT probes.
/// 2. If a device stops transmitting telemetry for >90 seconds, marks the probe OFFLINE in
///    Firestore, records a network activity log, and dispatches an instant native phone notification.
/// 3. When an offline device powers back on and resumes sending heartbeats, alerts the user
///    that connection has been restored and flips status back to ONLINE.
class IotPresenceWatchdogService {
  static final IotPresenceWatchdogService _instance = IotPresenceWatchdogService._internal();
  factory IotPresenceWatchdogService() => _instance;
  IotPresenceWatchdogService._internal();

  Timer? _watchdogTimer;
  StreamSubscription<List<IotDevice>>? _deviceSubscription;
  StreamSubscription<User?>? _authSubscription;

  List<IotDevice> _monitoredDevices = [];
  final Map<String, bool> _previousOnlineState = {};
  bool _isInitialized = false;

  /// Starts the presence watchdog service
  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('[IoT Watchdog] 🛡️ Presence watchdog service initialized.');

    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          _stopWatching();
        } else {
          _startWatching(user.uid);
        }
      });
    } catch (_) {}
  }

  void _startWatching(String uid) {
    _stopWatching();

    debugPrint('[IoT Watchdog] 🔍 Watching IoT probes for user: $uid');

    // Real-time stream of all devices registered to this user account
    _deviceSubscription = IotFirestoreService().streamUserDevices(uid).listen(
      (devices) {
        _monitoredDevices = devices;
        _evaluateDevices();
      },
      onError: (err) {
        debugPrint('[IoT Watchdog] ⚠️ Error streaming user devices: $err');
      },
    );

    // Periodic 15-second heartbeat watchdog timer
    _watchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _evaluateDevices();
    });
  }

  void _evaluateDevices() {
    if (_monitoredDevices.isEmpty) return;

    for (final dev in _monitoredDevices) {
      final wasOnline = _previousOnlineState[dev.id];
      final isNowOnline = dev.isOnline;

      if (wasOnline == null) {
        // Initial observation for this session
        _previousOnlineState[dev.id] = isNowOnline;
        if (!isNowOnline && dev.systemState != 'OFFLINE') {
          IotFirestoreService().markDeviceOffline(
            dev.id,
            'Heartbeat timeout: No signal received in >90 seconds',
          );
        }
        continue;
      }

      // Case A: Device transitioned from ONLINE -> OFFLINE
      if (wasOnline == true && !isNowOnline) {
        _previousOnlineState[dev.id] = false;
        debugPrint('[IoT Watchdog] ⚠️ Probe [${dev.id}] "${dev.name}" went OFFLINE!');

        // Dispatch native phone notification
        WebHardwareBridge.showNativeNotification(
          title: '⚠️ Smart Plant Probe Offline',
          body: 'Lost connection with ${dev.name}. No telemetry received in >90 seconds.',
        );

        // Record activity log
        IotHybridConnectivityService().logActivity(
          title: 'Probe Offline (Heartbeat Lost)',
          detail: 'No signal received from ${dev.name} in >90 seconds. Please check device power or Wi-Fi router.',
          type: IotLogType.network,
          deviceId: dev.id,
          deviceName: dev.name,
        );

        // Persist OFFLINE state to Firestore so all linked accounts see it immediately
        IotFirestoreService().markDeviceOffline(
          dev.id,
          'Heartbeat timeout: No signal received in >90 seconds',
        );
      }
      // Case B: Device transitioned from OFFLINE -> ONLINE
      else if (wasOnline == false && isNowOnline) {
        _previousOnlineState[dev.id] = true;
        debugPrint('[IoT Watchdog] 🟢 Probe [${dev.id}] "${dev.name}" is back ONLINE!');

        // Dispatch native phone notification
        WebHardwareBridge.showNativeNotification(
          title: '🟢 Smart Plant Probe Online',
          body: '${dev.name} is back online! Live telemetry restored.',
        );

        // Record activity log
        IotHybridConnectivityService().logActivity(
          title: 'Probe Online (Heartbeat Restored)',
          detail: '${dev.name} reconnected and resumed live telemetry streaming.',
          type: IotLogType.network,
          deviceId: dev.id,
          deviceName: dev.name,
        );

        // Restore systemState in Firestore
        IotFirestoreService().setDeviceSystemState(
          dev.id,
          'CONNECTED_ONLINE',
          'Live heartbeat restored',
        );
      }
    }
  }

  void _stopWatching() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _deviceSubscription?.cancel();
    _deviceSubscription = null;
    _monitoredDevices.clear();
    _previousOnlineState.clear();
  }

  void dispose() {
    _stopWatching();
    _authSubscription?.cancel();
    _authSubscription = null;
    _isInitialized = false;
  }
}
