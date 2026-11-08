import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class WebHardwareBridge {
  static bool get isWebPlatform => false;
  static bool get isWebBluetoothSupported => false;

  static const _platformChannel = MethodChannel('urban.green/bluetooth');
  static final Map<String, String> _inMemoryStorage = {};

  // =========================================================================
  // NOTIFICATIONS (Android 13+ POST_NOTIFICATIONS & System Heads-Up Alerts)
  // =========================================================================

  /// Checks if POST_NOTIFICATIONS permission is granted (Android 13+)
  static Future<bool> checkNotificationPermission() async {
    try {
      final bool? granted = await _platformChannel.invokeMethod('checkNotificationPermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Prompts user for POST_NOTIFICATIONS permission on Android 13+
  static Future<bool> requestNotificationPermission() async {
    try {
      final bool? granted = await _platformChannel.invokeMethod('requestNotificationPermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  static Function(Map<String, dynamic>)? _notificationTapCallback;

  /// Sets listener for when the user taps on a native system notification
  static void setNotificationTapCallback(Function(Map<String, dynamic>) callback) {
    _notificationTapCallback = callback;
    _platformChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTapped') {
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          _notificationTapCallback?.call(map);
        }
      }
    });
  }

  /// Checks if the app was launched by tapping a notification
  static Future<Map<String, dynamic>?> getPendingNotificationPayload() async {
    try {
      final res = await _platformChannel.invokeMethod('getPendingNotificationPayload');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  /// Displays native Android heads-up system notification for global ntfy alerts
  static Future<void> showNativeNotification({
    required String title,
    required String body,
    String? deviceId,
    String? plantId,
  }) async {
    try {
      await _platformChannel.invokeMethod('showDrySoilNotification', {
        'title': title,
        'body': body,
        'deviceId': deviceId ?? '',
        'plantId': plantId ?? '',
      });
    } catch (e) {
      debugPrint('Native notification note: $e');
    }
  }

  // =========================================================================
  // CAPTIVE PORTAL SETUP INTENTS
  // =========================================================================

  /// Opens the system Wi-Fi settings page so the user can join "ESP32-Setup"
  static Future<void> openWifiSettings() async {
    try {
      await _platformChannel.invokeMethod('openWifiSettings');
    } catch (e) {
      print('Open Wi-Fi Settings note: $e');
    }
  }

  /// Launches the Captive Portal in the external system browser (default: http://192.168.4.1)
  static Future<void> openBrowserUrl([String url = 'http://192.168.4.1']) async {
    try {
      await _platformChannel.invokeMethod('openBrowserUrl', {'url': url});
    } catch (e) {
      print('Open Browser URL note: $e');
    }
  }

  /// Opens Android App Settings page if user permanently denied permissions
  static Future<void> openAppSettings() async {
    try {
      await _platformChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Retrieves the actual Wi-Fi network SSID currently connected to the Android phone
  static Future<String?> getWifiSsid() async {
    try {
      final String? ssid = await _platformChannel.invokeMethod('getWifiSsid');
      if (ssid != null && ssid.isNotEmpty && ssid != '<unknown ssid>') {
        return ssid;
      }
    } catch (e) {
      print('Get Wi-Fi SSID note: $e');
    }
    return null;
  }

  /// Binds or unbinds the app's process sockets to the Wi-Fi network interface.
  /// This prevents cellular mobile data from hijacking local 192.168.4.1 requests on Android.
  static Future<bool> bindProcessToWifi([bool bind = true]) async {
    try {
      final bool? success = await _platformChannel.invokeMethod('bindProcessToWifi', {'bind': bind});
      return success == true;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves Wi-Fi Gateway and DHCP IP details to verify SoftAP connection without needing GPS/SSID.
  static Future<Map<String, dynamic>?> getWifiGatewayDetails() async {
    try {
      final res = await _platformChannel.invokeMethod('getWifiGatewayIp');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the phone's network connection type ('wifi', 'cellular', 'ethernet', 'none', 'unknown')
  static Future<String> getNetworkType() async {
    try {
      final String? type = await _platformChannel.invokeMethod('getNetworkType');
      return type ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Retrieves the phone's hardware model / manufacturer name
  static Future<String> getDeviceModel() async {
    try {
      final String? model = await _platformChannel.invokeMethod('getDeviceModel');
      if (model != null && model.isNotEmpty) return model;
    } catch (_) {}
    return 'Android Phone';
  }

  // =========================================================================
  // LOCAL STORAGE PERSISTENCE
  // =========================================================================

  static bool _isStorageInitialized = false;

  /// Preloads all stored preferences into memory at app launch so synchronous reads work instantly
  static Future<void> init() async {
    if (_isStorageInitialized) return;
    try {
      final Map<dynamic, dynamic>? all = await _platformChannel.invokeMethod('loadAllStorage');
      if (all != null) {
        all.forEach((key, val) {
          if (key != null && val != null) {
            _inMemoryStorage[key.toString()] = val.toString();
          }
        });
      }
      try {
        final String? filesDir = await _platformChannel.invokeMethod('getAppFilesDir');
        if (filesDir != null && filesDir.isNotEmpty) {
          _inMemoryStorage['app_files_dir'] = filesDir;
        }
      } catch (_) {}
      _isStorageInitialized = true;
    } catch (_) {}
  }

  static String? loadStorage(String key) {
    if (_inMemoryStorage.containsKey(key)) {
      return _inMemoryStorage[key];
    }
    try {
      _platformChannel.invokeMethod('loadStorage', {'key': key}).then((val) {
        if (val != null && val is String) {
          _inMemoryStorage[key] = val;
        }
      }).catchError((_) {});
    } catch (_) {}
    return _inMemoryStorage[key];
  }

  static Future<String?> loadStorageAsync(String key) async {
    try {
      final String? val = await _platformChannel.invokeMethod('loadStorage', {'key': key});
      if (val != null && val.isNotEmpty) {
        _inMemoryStorage[key] = val;
        return val;
      }
    } catch (_) {}
    return _inMemoryStorage[key];
  }

  static void saveStorage(String key, String value) {
    _inMemoryStorage[key] = value;
    try {
      _platformChannel.invokeMethod('saveStorage', {'key': key, 'value': value}).catchError((_) {});
    } catch (_) {}
  }

  static void removeStorage(String key) {
    _inMemoryStorage.remove(key);
    try {
      _platformChannel.invokeMethod('saveStorage', {'key': key, 'value': ''}).catchError((_) {});
    } catch (_) {}
  }

  // =========================================================================
  // HTTP REST COMMUNICATION (LOCAL ESP32 & NTFY PUSH)
  // =========================================================================

  /// Real HTTP REST calls to the ESP32 device or outbound web services
  static Future<Map<String, dynamic>> sendHttpRequest(
    String url, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final uri = Uri.parse(url);
      http.Response response;

      final reqHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      if (method == 'POST') {
        response = await http.post(
          uri,
          headers: reqHeaders,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(timeout);
      } else {
        response = await http.get(uri, headers: headers).timeout(timeout);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'data': data,
            'statusCode': response.statusCode,
          };
        } catch (_) {
          return {
            'success': true,
            'data': response.body,
            'statusCode': response.statusCode,
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Device returned HTTP ${response.statusCode}: ${response.body}',
          'statusCode': response.statusCode,
          'fallback': true,
        };
      }
    } catch (e) {
      final errStr = e.toString();
      String humanError = 'Connection failed to $url.';
      if (errStr.contains('TimeoutException')) {
        humanError = 'Connection timed out to $url (after ${timeout.inSeconds}s).';
      } else if (errStr.contains('SocketException')) {
        humanError = 'Network socket error: Could not reach $url. Device may be offline or Wi-Fi not connected.';
      }
      return {
        'success': false,
        'error': humanError,
        'rawError': errStr,
        'fallback': true,
      };
    }
  }

  // =========================================================================
  // DEPRECATED BLE STUBS (SAFE NO-OPS PREVENTING BREAKING CHANGES)
  // =========================================================================

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<bool> checkBlePermissions() async => true;

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<bool> requestBlePermissions() async => true;

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<List<Map<String, dynamic>>> startNativeBleScan() async => [];

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<Map<String, dynamic>> readBleGattTelemetry(String address) async => {'success': false, 'deprecated': true};

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<Map<String, dynamic>> sendBleWifiCredentials({
    required String address,
    required String ssid,
    required String pass,
  }) async => {
    'success': false,
    'deprecated': true,
    'error': 'BLE provisioning deprecated. Use SoftAP Captive Portal at http://192.168.4.1',
  };

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<List<Map<String, dynamic>>> startNativeWifiScan() async => [];

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<bool> isLocationEnabled() async => true;

  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  static Future<void> openLocationSettings() async {}
}
