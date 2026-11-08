class IotDevice {
  final String id;
  String name;
  bool isBluetoothConnected; // Deprecated: Kept for serialization compatibility
  bool isWifiConnected;
  String? wifiSsid;
  String ntfyTopic;
  int batteryLevel;
  int signalStrength;
  final bool supportsMoistureSensor;
  final bool supportsAutoWater;
  double? moistureLevel;
  bool autoWaterEnabled;
  String? autoWaterSchedule;
  bool isVerifiedCompatible;
  String serviceUuid;
  String firmwareVersion;
  DateTime lastSeen;

  // Low Moisture Notification & Decision Configuration
  bool lowMoistureAlertEnabled;
  int lowMoistureThreshold; // in percent (e.g. 25)
  DateTime? lowMoistureIgnoredUntil;
  bool lowMoistureAlwaysIgnored;

  IotDevice({
    required this.id,
    required this.name,
    this.isBluetoothConnected = false,
    this.isWifiConnected = true,
    this.wifiSsid,
    this.ntfyTopic = 'urbangreen_esp32_alerts',
    this.batteryLevel = 95,
    this.signalStrength = -58,
    this.supportsMoistureSensor = true,
    this.supportsAutoWater = true,
    this.moistureLevel = 0.0,
    this.autoWaterEnabled = false,
    this.autoWaterSchedule,
    this.isVerifiedCompatible = true,
    this.serviceUuid = 'SoftAP-ESP32-Setup',
    this.firmwareVersion = 'v3.0.0-WiFiManager-ntfy',
    DateTime? lastSeen,
    this.lowMoistureAlertEnabled = true,
    this.lowMoistureThreshold = 25,
    this.lowMoistureIgnoredUntil,
    this.lowMoistureAlwaysIgnored = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

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
      'isBluetoothConnected': isBluetoothConnected,
      'isWifiConnected': isWifiConnected,
      'wifiSsid': wifiSsid,
      'ntfyTopic': ntfyTopic,
      'batteryLevel': batteryLevel,
      'signalStrength': signalStrength,
      'supportsMoistureSensor': supportsMoistureSensor,
      'supportsAutoWater': supportsAutoWater,
      'moistureLevel': moistureLevel,
      'autoWaterEnabled': autoWaterEnabled,
      'autoWaterSchedule': autoWaterSchedule,
      'isVerifiedCompatible': isVerifiedCompatible,
      'serviceUuid': serviceUuid,
      'firmwareVersion': firmwareVersion,
      'lastSeen': lastSeen.toIso8601String(),
      'lowMoistureAlertEnabled': lowMoistureAlertEnabled,
      'lowMoistureThreshold': lowMoistureThreshold,
      'lowMoistureIgnoredUntil': lowMoistureIgnoredUntil?.toIso8601String(),
      'lowMoistureAlwaysIgnored': lowMoistureAlwaysIgnored,
    };
  }

  factory IotDevice.fromMap(Map<String, dynamic> map) {
    return IotDevice(
      id: map['id'] as String? ?? 'ESP32-NODE-01',
      name: map['name'] as String? ?? 'Smart Plant Probe',
      isBluetoothConnected: map['isBluetoothConnected'] as bool? ?? false,
      isWifiConnected: map['isWifiConnected'] as bool? ?? true,
      wifiSsid: map['wifiSsid'] as String?,
      ntfyTopic: map['ntfyTopic'] as String? ?? 'urbangreen_esp32_alerts',
      batteryLevel: (map['batteryLevel'] as num?)?.toInt() ?? 95,
      signalStrength: (map['signalStrength'] as num?)?.toInt() ?? -58,
      supportsMoistureSensor: map['supportsMoistureSensor'] as bool? ?? true,
      supportsAutoWater: map['supportsAutoWater'] as bool? ?? true,
      moistureLevel: (map['moistureLevel'] as num?)?.toDouble() ?? 0.0,
      autoWaterEnabled: map['autoWaterEnabled'] as bool? ?? false,
      autoWaterSchedule: map['autoWaterSchedule'] as String?,
      isVerifiedCompatible: map['isVerifiedCompatible'] as bool? ?? true,
      serviceUuid: map['serviceUuid'] as String? ?? 'SoftAP-ESP32-Setup',
      firmwareVersion: map['firmwareVersion'] as String? ?? 'v3.0.0-WiFiManager-ntfy',
      lastSeen: map['lastSeen'] != null ? DateTime.tryParse(map['lastSeen']) ?? DateTime.now() : DateTime.now(),
      lowMoistureAlertEnabled: map['lowMoistureAlertEnabled'] as bool? ?? true,
      lowMoistureThreshold: (map['lowMoistureThreshold'] as num?)?.toInt() ?? 25,
      lowMoistureIgnoredUntil: map['lowMoistureIgnoredUntil'] != null
          ? DateTime.tryParse(map['lowMoistureIgnoredUntil'].toString())
          : null,
      lowMoistureAlwaysIgnored: map['lowMoistureAlwaysIgnored'] as bool? ?? false,
    );
  }
}
