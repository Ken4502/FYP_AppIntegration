import 'package:cloud_firestore/cloud_firestore.dart';

class IotDevice {
  final String id;
  String name;
  String? userId;
  List<String> linkedUserIds;
  bool isBluetoothConnected; // Deprecated: Kept for serialization compatibility
  bool isWifiConnected;
  String? wifiSsid;
  String ntfyTopic;
  int batteryLevel;
  int signalStrength;
  final bool supportsMoistureSensor;
  final bool supportsAutoWater;
  double? moistureLevel;
  int? rawAdc;
  bool isPumpRunning;
  bool autoWaterEnabled;
  String? autoWaterSchedule;
  bool isVerifiedCompatible;
  String serviceUuid;
  String firmwareVersion;
  DateTime lastSeen;
  DateTime? lastReadingAt;
  DateTime? lastWateredAt;

  // Threshold Configuration
  int lowMoistureThreshold; // in percent (e.g. 25)
  int highMoistureThreshold; // in percent (e.g. 60)

  // Low Moisture Notification & Decision Configuration
  bool lowMoistureAlertEnabled;
  DateTime? lowMoistureIgnoredUntil;
  bool lowMoistureAlwaysIgnored;

  // Linked Plant (Strict 1-to-1 Mapping)
  String? linkedPlantId;
  String? linkedPlantName;
  String? linkedPlantImage;

  // Remote Commands
  Map<String, dynamic>? pendingCommand;

  // Hardware State Machine & Diagnostics
  String? systemState;
  String? stateReason;
  int reconnectAttempts;

  IotDevice({
    required this.id,
    required this.name,
    this.userId,
    List<String>? linkedUserIds,
    this.isBluetoothConnected = false,
    this.isWifiConnected = true,
    this.wifiSsid,
    this.ntfyTopic = 'urbangreen_esp32_alerts',
    this.batteryLevel = 95,
    this.signalStrength = -58,
    this.supportsMoistureSensor = true,
    this.supportsAutoWater = true,
    this.moistureLevel = 0.0,
    this.rawAdc = 3200,
    this.isPumpRunning = false,
    this.autoWaterEnabled = false,
    this.autoWaterSchedule,
    this.isVerifiedCompatible = true,
    this.serviceUuid = 'SoftAP-ESP32-Setup',
    this.firmwareVersion = 'v4.1.0-StateMachine',
    DateTime? lastSeen,
    this.lastReadingAt,
    this.lastWateredAt,
    this.lowMoistureAlertEnabled = true,
    this.lowMoistureThreshold = 25,
    this.highMoistureThreshold = 60,
    this.lowMoistureIgnoredUntil,
    this.lowMoistureAlwaysIgnored = false,
    this.linkedPlantId,
    this.linkedPlantName,
    this.linkedPlantImage,
    this.pendingCommand,
    this.systemState,
    this.stateReason,
    this.reconnectAttempts = 0,
  }) : lastSeen = lastSeen ?? DateTime.now(),
       linkedUserIds = linkedUserIds != null
           ? List<String>.from(linkedUserIds)
           : (userId != null && userId.isNotEmpty ? [userId] : []);

  /// Computed dynamic Online / Offline status based on 2-minute heartbeat window
  bool get isOnline {
    final now = DateTime.now();
    return now.difference(lastSeen).inSeconds < 120;
  }

  /// Whether the ESP32 is currently in grace fallback hotspot mode due to lost Wi-Fi
  bool get isGraceHotspotActive => systemState == 'FALLBACK_HOTSPOT';

  /// Human-friendly display label for hardware state
  String get stateDisplayLabel {
    if (isGraceHotspotActive) return 'Grace Hotspot (Wi-Fi Down)';
    if (!isOnline) return 'Offline';
    switch (systemState) {
      case 'CONNECTED_ONLINE':
        return 'Online';
      case 'RECONNECTING':
        return reconnectAttempts > 0 ? 'Reconnecting (Try $reconnectAttempts/3)' : 'Reconnecting...';
      case 'FALLBACK_HOTSPOT':
        return 'Grace Hotspot (Wi-Fi Down)';
      case 'CONNECTING_WIFI':
        return 'Connecting to Wi-Fi';
      case 'HOTSPOT_BROADCASTING':
        return 'Setup Hotspot Active';
      case 'UNCONFIGURED':
        return 'Unconfigured';
      case 'FACTORY_RESETTING':
        return 'Resetting / Wiping';
      default:
        return 'Online';
    }
  }

  /// Whether alerts are currently snoozed/muted
  bool get isLowMoistureAlertIgnored {
    if (!lowMoistureAlertEnabled) return true;
    if (lowMoistureAlwaysIgnored) return true;
    if (lowMoistureIgnoredUntil != null) {
      return DateTime.now().isBefore(lowMoistureIgnoredUntil!);
    }
    return false;
  }

  /// Format short date helper
  static String _formatShortDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  /// Format short time helper
  static String _formatShortTime(DateTime dt) {
    final hr = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hr:$min $ampm';
  }

  /// Human-readable ignore status text
  String get lowMoistureIgnoreStatusText {
    if (!lowMoistureAlertEnabled) {
      return 'Alerts Disabled';
    }
    if (lowMoistureAlwaysIgnored) {
      return 'Always Ignored (Muted)';
    }
    if (lowMoistureIgnoredUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(lowMoistureIgnoredUntil!)) {
        final diff = lowMoistureIgnoredUntil!.difference(now);
        final totalHours = (diff.inMinutes / 60.0).ceil();
        final totalDays = (totalHours / 24.0).ceil();
        if (totalDays >= 7) {
          final weeks = (totalDays / 7.0).round();
          return 'Ignored for ${weeks}w (until ${_formatShortDate(lowMoistureIgnoredUntil!)})';
        } else if (totalDays >= 1) {
          return 'Ignored for ${totalDays}d (until ${_formatShortDate(lowMoistureIgnoredUntil!)})';
        } else if (totalHours >= 1) {
          return 'Ignored for ${totalHours}h (until ${_formatShortTime(lowMoistureIgnoredUntil!)})';
        } else {
          return 'Ignored for ${diff.inMinutes.clamp(1, 60)}m';
        }
      }
    }
    return 'Active (Alerting when < $lowMoistureThreshold%)';
  }

  void ignoreAlertFor(Duration duration) {
    lowMoistureIgnoredUntil = DateTime.now().add(duration);
    lowMoistureAlwaysIgnored = false;
  }

  void ignoreAlertAlways() {
    lowMoistureAlwaysIgnored = true;
    lowMoistureIgnoredUntil = null;
  }

  void resetAlertIgnore() {
    lowMoistureIgnoredUntil = null;
    lowMoistureAlwaysIgnored = false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'linkedUserIds': linkedUserIds,
      'isBluetoothConnected': isBluetoothConnected,
      'isWifiConnected': isWifiConnected,
      'wifiSsid': wifiSsid,
      'ntfyTopic': ntfyTopic,
      'batteryLevel': batteryLevel,
      'signalStrength': signalStrength,
      'supportsMoistureSensor': supportsMoistureSensor,
      'supportsAutoWater': supportsAutoWater,
      'moistureLevel': moistureLevel,
      'moisturePercent': moistureLevel,
      'rawADC': rawAdc,
      'raw': rawAdc,
      'isPumpRunning': isPumpRunning,
      'autoWaterEnabled': autoWaterEnabled,
      'autoWaterSchedule': autoWaterSchedule,
      'isVerifiedCompatible': isVerifiedCompatible,
      'serviceUuid': serviceUuid,
      'firmwareVersion': firmwareVersion,
      'lastSeen': lastSeen.toIso8601String(),
      'lastReadingAt': lastReadingAt?.toIso8601String(),
      'lastWateredAt': lastWateredAt?.toIso8601String(),
      'lowMoistureAlertEnabled': lowMoistureAlertEnabled,
      'lowMoistureThreshold': lowMoistureThreshold,
      'lowThreshold': lowMoistureThreshold,
      'highMoistureThreshold': highMoistureThreshold,
      'highThreshold': highMoistureThreshold,
      'lowMoistureIgnoredUntil': lowMoistureIgnoredUntil?.toIso8601String(),
      'lowMoistureAlwaysIgnored': lowMoistureAlwaysIgnored,
      'linkedPlantId': linkedPlantId,
      'linkedPlantName': linkedPlantName,
      'linkedPlantImage': linkedPlantImage,
      'pendingCommand': pendingCommand,
      'systemState': systemState,
      'stateReason': stateReason,
      'reconnectAttempts': reconnectAttempts,
    };
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  factory IotDevice.fromMap(Map<String, dynamic> map) {
    // Robust parsing for moisture
    double parsedMoisture = 0.0;
    if (map['moisturePercent'] is num) {
      parsedMoisture = (map['moisturePercent'] as num).toDouble();
    } else if (map['moistureLevel'] is num) {
      parsedMoisture = (map['moistureLevel'] as num).toDouble();
    } else if (map['moisture'] is num) {
      parsedMoisture = (map['moisture'] as num).toDouble();
    }

    // Robust parsing for raw ADC
    int parsedRawAdc = 3200;
    if (map['rawADC'] is num) {
      parsedRawAdc = (map['rawADC'] as num).toInt();
    } else if (map['rawAdc'] is num) {
      parsedRawAdc = (map['rawAdc'] as num).toInt();
    } else if (map['raw'] is num) {
      parsedRawAdc = (map['raw'] as num).toInt();
    }

    // Robust parsing for pump running
    bool parsedPump = false;
    if (map['isPumpRunning'] is bool) {
      parsedPump = map['isPumpRunning'] as bool;
    } else if (map['pump'] != null) {
      parsedPump = map['pump'] == 1 || map['pump'] == true || map['pump'] == '1';
    }

    // Robust parsing for timestamps
    final lastSeen = _parseDateTime(map['lastSeen']) ?? DateTime.now();
    final lastReading = _parseDateTime(map['lastReadingAt'] ?? map['lastReading']);
    final lastWatered = _parseDateTime(map['lastWateredAt'] ?? map['lastWatered']);
    final ignoredUntil = _parseDateTime(map['lowMoistureIgnoredUntil']);

    // Robust parsing for thresholds
    final lowThresh = (map['lowThreshold'] as num?)?.toInt() ??
        (map['lowMoistureThreshold'] as num?)?.toInt() ??
        25;
    final highThresh = (map['highThreshold'] as num?)?.toInt() ??
        (map['highMoistureThreshold'] as num?)?.toInt() ??
        60;

    // Robust parsing for linked user accounts
    final rawLinked = map['linkedUserIds'];
    final List<String> parsedLinkedUsers = [];
    if (rawLinked is List) {
      for (final u in rawLinked) {
        if (u != null && u.toString().trim().isNotEmpty) {
          parsedLinkedUsers.add(u.toString().trim());
        }
      }
    }
    final ownerUid = map['userId'] as String? ?? map['registeredBy'] as String?;
    if (ownerUid != null && ownerUid.trim().isNotEmpty && !parsedLinkedUsers.contains(ownerUid.trim())) {
      parsedLinkedUsers.add(ownerUid.trim());
    }

    return IotDevice(
      id: map['id'] as String? ?? (map['device'] as String? ?? 'ESP32-NODE-01'),
      name: map['name'] as String? ?? 'Smart Plant Probe',
      userId: ownerUid,
      linkedUserIds: parsedLinkedUsers,
      isBluetoothConnected: map['isBluetoothConnected'] as bool? ?? false,
      isWifiConnected: map['isWifiConnected'] as bool? ?? true,
      wifiSsid: map['wifiSsid'] as String? ?? map['ssid'] as String? ?? map['homeSsid'] as String?,
      ntfyTopic: map['ntfyTopic'] as String? ?? 'urbangreen_esp32_alerts',
      batteryLevel: (map['batteryLevel'] as num?)?.toInt() ?? 95,
      signalStrength: (map['signalStrength'] as num?)?.toInt() ?? -58,
      supportsMoistureSensor: map['supportsMoistureSensor'] as bool? ?? true,
      supportsAutoWater: map['supportsAutoWater'] as bool? ?? true,
      moistureLevel: parsedMoisture,
      rawAdc: parsedRawAdc,
      isPumpRunning: parsedPump,
      autoWaterEnabled: map['autoWaterEnabled'] as bool? ?? (map['mode'] == 'AUTO'),
      autoWaterSchedule: map['autoWaterSchedule'] as String?,
      isVerifiedCompatible: map['isVerifiedCompatible'] as bool? ?? true,
      serviceUuid: map['serviceUuid'] as String? ?? 'SoftAP-ESP32-Setup',
      firmwareVersion: map['firmwareVersion'] as String? ?? 'v4.0.0-Firestore',
      lastSeen: lastSeen,
      lastReadingAt: lastReading,
      lastWateredAt: lastWatered,
      lowMoistureAlertEnabled: map['lowMoistureAlertEnabled'] as bool? ?? true,
      lowMoistureThreshold: lowThresh,
      highMoistureThreshold: highThresh,
      lowMoistureIgnoredUntil: ignoredUntil,
      lowMoistureAlwaysIgnored: map['lowMoistureAlwaysIgnored'] as bool? ?? false,
      linkedPlantId: map['linkedPlantId'] as String?,
      linkedPlantName: map['linkedPlantName'] as String?,
      linkedPlantImage: map['linkedPlantImage'] as String?,
      pendingCommand: map['pendingCommand'] is Map ? Map<String, dynamic>.from(map['pendingCommand'] as Map) : null,
      systemState: map['systemState'] as String?,
      stateReason: map['stateReason'] as String?,
      reconnectAttempts: (map['reconnectAttempts'] as num?)?.toInt() ?? 0,
    );
  }
}
