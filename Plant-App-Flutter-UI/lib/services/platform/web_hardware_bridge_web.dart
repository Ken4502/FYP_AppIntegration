// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WebHardwareBridge {
  static bool get isWebPlatform => true;

  static bool get isWebBluetoothSupported {
    try {
      final nav = js.context['navigator'];
      return nav != null && js.context['navigator']['bluetooth'] != null;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // NOTIFICATIONS (WEB NOTIFICATION API & STUBS)
  // =========================================================================

  static Future<bool> checkNotificationPermission() async {
    try {
      return html.Notification.permission == 'granted';
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final perm = await html.Notification.requestPermission();
      return perm == 'granted';
    } catch (_) {
      return true;
    }
  }

  static void setNotificationTapCallback(Function(Map<String, dynamic>) callback) {}

  static Future<Map<String, dynamic>?> getPendingNotificationPayload() async => null;

  static Future<void> showNativeNotification({
    required String title,
    required String body,
    String? deviceId,
    String? plantId,
  }) async {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body);
      }
    } catch (e) {
      debugPrint('Web notification note: $e');
    }
  }

  // =========================================================================
  // CAPTIVE PORTAL SETUP INTENTS (WEB COMPATIBILITY)
  // =========================================================================

  static Future<void> openWifiSettings() async {
    html.window.alert(
      'To connect to your ESP32 device, connect your computer/phone to the "ESP32-Setup" Wi-Fi network in your operating system Wi-Fi menu.',
    );
  }

  static Future<void> openBrowserUrl([String url = 'http://192.168.4.1']) async {
    try {
      html.window.open(url, '_blank');
    } catch (e) {
      print('Web open URL note: $e');
    }
  }

  static Future<void> openAppSettings() async {}

  static Future<bool> bindProcessToWifi([bool bind = true]) async => false;
  static Future<Map<String, dynamic>?> getWifiGatewayDetails() async => null;
  static Future<String?> getWifiSsid() async => null;
  static Future<String> getNetworkType() async => 'wifi';
  static Future<String> getDeviceModel() async => 'Web Browser';

  // =========================================================================
  // PERSISTENCE (LOCAL STORAGE)
  // =========================================================================

  static Future<void> init() async {}

  static String? loadStorage(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  static Future<String?> loadStorageAsync(String key) async {
    return loadStorage(key);
  }

  static void saveStorage(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  static void removeStorage(String key) {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }

  // =========================================================================
  // HTTP REST
  // =========================================================================

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
      if (errStr.contains('XMLHttpRequest') || errStr.contains('CORS') || errStr.contains('Failed to fetch')) {
        humanError = 'Network/CORS error: Could not reach $url. Device may be offline or on a different Wi-Fi network.';
      } else if (errStr.contains('TimeoutException')) {
        humanError = 'Connection timed out to $url (after ${timeout.inSeconds}s).';
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
  // DEPRECATED BLE STUBS
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
