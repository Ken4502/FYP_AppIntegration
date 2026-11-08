import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'platform/web_hardware_bridge.dart';

/// Represents an incoming payload from the ntfy.sh push bridge
class NtfyAlert {
  final String id;
  final DateTime timestamp;
  final String topic;
  final String title;
  final String message;
  final int priority;
  final List<String> tags;
  final Map<String, dynamic> raw;

  const NtfyAlert({
    required this.id,
    required this.timestamp,
    required this.topic,
    required this.title,
    required this.message,
    this.priority = 3,
    this.tags = const [],
    this.raw = const {},
  });

  factory NtfyAlert.fromJson(Map<String, dynamic> json) {
    final int timeSec = (json['time'] as num?)?.toInt() ?? 0;
    final dt = timeSec > 0
        ? DateTime.fromMillisecondsSinceEpoch(timeSec * 1000)
        : DateTime.now();

    final rawTags = json['tags'];
    List<String> tagsList = [];
    if (rawTags is List) {
      tagsList = rawTags.map((e) => e.toString()).toList();
    }

    return NtfyAlert(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      timestamp: dt,
      topic: (json['topic'] ?? '').toString(),
      title: (json['title'] ?? '🌱 UrbanGreen Alert').toString(),
      message: (json['message'] ?? '').toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      tags: tagsList,
      raw: json,
    );
  }
}

/// Global Background / Foreground Notification Service connected to ntfy.sh
///
/// Ensures ESP32 alerts arrive anywhere in the world (even when the phone is on
/// cellular 4G/5G and the ESP32 is on home Wi-Fi).
class NtfyNotificationService {
  static final NtfyNotificationService _instance = NtfyNotificationService._internal();
  factory NtfyNotificationService() => _instance;

  static const String defaultTopic = 'urbangreen_esp32_alerts';
  String _currentTopic = defaultTopic;

  String get topic => _currentTopic;

  set topic(String value) {
    final clean = value.trim();
    if (clean.isNotEmpty && clean != _currentTopic) {
      _currentTopic = clean;
      WebHardwareBridge.saveStorage('ntfy_topic', clean);
      restart();
    }
  }

  bool _isRunning = false;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  bool get isRunning => _isRunning;

  http.Client? _httpClient;
  StreamSubscription? _streamSubscription;
  Timer? _reconnectTimer;

  final StreamController<NtfyAlert> _alertStreamController = StreamController<NtfyAlert>.broadcast();
  Stream<NtfyAlert> get onAlertReceived => _alertStreamController.stream;

  final List<NtfyAlert> _recentAlerts = [];
  List<NtfyAlert> get recentAlerts => List.unmodifiable(_recentAlerts);

  NtfyNotificationService._internal() {
    final savedTopic = WebHardwareBridge.loadStorage('ntfy_topic');
    if (savedTopic != null && savedTopic.trim().isNotEmpty) {
      _currentTopic = savedTopic.trim();
    }
  }

  /// Start the live notification receiver and request Android 13+ permissions
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // Check & request notification runtime permissions on Android 13+
    try {
      final granted = await WebHardwareBridge.checkNotificationPermission();
      if (!granted) {
        await WebHardwareBridge.requestNotificationPermission();
      }
    } catch (_) {}

    _connectStream();
  }

  /// Restart with new topic or connection reset
  void restart() {
    stop();
    start();
  }

  /// Stop listening
  void stop() {
    _isRunning = false;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    _httpClient?.close();
    _httpClient = null;
    _streamSubscription = null;
  }

  void _connectStream() async {
    if (!_isRunning) return;

    _streamSubscription?.cancel();
    _httpClient?.close();
    _httpClient = http.Client();

    final streamUri = Uri.parse('https://ntfy.sh/$_currentTopic/json');
    debugPrint('[ntfy.sh] 🌐 Connecting to notification stream: $streamUri');

    try {
      final request = http.Request('GET', streamUri);
      request.headers['User-Agent'] = 'UrbanGreen-Flutter/1.0';

      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        _isConnected = true;
        debugPrint('[ntfy.sh] ✅ Connected to stream on topic: "$_currentTopic"');

        _streamSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            _handleIncomingLine(line);
          },
          onError: (err) {
            debugPrint('[ntfy.sh] ⚠️ Stream error: $err');
            _handleDisconnectAndRetry();
          },
          onDone: () {
            debugPrint('[ntfy.sh] ℹ️ Stream connection closed by server.');
            _handleDisconnectAndRetry();
          },
          cancelOnError: true,
        );
      } else {
        debugPrint('[ntfy.sh] ❌ Connection failed (HTTP ${response.statusCode})');
        _handleDisconnectAndRetry();
      }
    } catch (e) {
      debugPrint('[ntfy.sh] ⚠️ Connection exception: $e');
      _handleDisconnectAndRetry();
    }
  }

  void _handleIncomingLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is! Map<String, dynamic>) return;

      final eventType = parsed['event'] as String?;

      if (eventType == 'open') {
        _isConnected = true;
        debugPrint('[ntfy.sh] 🟢 Stream session established: ${parsed['topic']}');
        return;
      }

      if (eventType == 'keepalive') {
        _isConnected = true;
        return;
      }

      if (eventType == 'message') {
        final alert = NtfyAlert.fromJson(parsed);

        // Record in in-memory history (last 50 alerts)
        _recentAlerts.insert(0, alert);
        if (_recentAlerts.length > 50) {
          _recentAlerts.removeLast();
        }

        debugPrint('[ntfy.sh] 🔔 INCOMING GLOBAL ALERT: [${alert.title}] ${alert.message}');

        // Trigger native system notification banner
        WebHardwareBridge.showNativeNotification(
          title: alert.title.isNotEmpty ? alert.title : '🌱 UrbanGreen Alert',
          body: alert.message.isNotEmpty ? alert.message : 'New alert from ESP32',
        );

        // Broadcast to in-app listeners
        _alertStreamController.add(alert);
      }
    } catch (e) {
      debugPrint('[ntfy.sh] Parse line note: $e');
    }
  }

  void _handleDisconnectAndRetry() {
    _isConnected = false;
    _streamSubscription?.cancel();
    _streamSubscription = null;

    if (!_isRunning) return;

    _reconnectTimer?.cancel();
    debugPrint('[ntfy.sh] 🔄 Scheduling reconnect in 4 seconds...');
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (_isRunning) {
        _connectStream();
      }
    });
  }

  /// Sends an outbound test alert to https://ntfy.sh/<topic>
  /// to verify the end-to-end global alert pipeline from anywhere in the world.
  Future<bool> sendTestAlert({
    String? title,
    String? message,
    int priority = 4,
    String tags = 'seedling,tada',
  }) async {
    final alertTitle = title ?? '🌱 ESP32 Global Alert Test';
    final alertBody = message ??
        'Global push bridge active! Notifications will be delivered worldwide via ntfy.sh over 4G/5G/Wi-Fi.';

    try {
      final postUri = Uri.parse('https://ntfy.sh/$_currentTopic');
      final res = await http.post(
        postUri,
        headers: {
          'Title': alertTitle,
          'Priority': priority.toString(),
          'Tags': tags,
        },
        body: alertBody,
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        debugPrint('[ntfy.sh] ✅ Outbound test alert posted successfully!');
        return true;
      } else {
        debugPrint('[ntfy.sh] ❌ Failed to post test alert (HTTP ${res.statusCode}): ${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ntfy.sh] Test alert exception: $e');
      return false;
    }
  }
}
