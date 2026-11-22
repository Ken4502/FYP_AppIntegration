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
  String? stationIp;

  // Physical IoT-Bound Location (stored in Firestore so outstation users always see IoT site weather)
  String? locationCity;
  String? locationRegion;
  String? locationCountry;
  double? locationLatitude;
  double? locationLongitude;

  // Environment Setting: Indoor (sheltered, fixed target) vs Outdoor (dynamic weather-reactive)
  bool isIndoor;

  // Notification Automation & Preferences
  bool dynamicMoistureAlertEnabled;
  bool dailyWeatherNotificationEnabled;

  IotDevice({
    required this.id,
    required this.name,
    this.userId,
    List<String>? linkedUserIds,
    this.isBluetoothConnected = false,
    this.isWifiConnected = true,
    this.wifiSsid,
    this.stationIp,
    this.locationCity,
    this.locationRegion,
    this.locationCountry,
    this.locationLatitude,
    this.locationLongitude,
    this.isIndoor = true,
    this.dynamicMoistureAlertEnabled = true,
    this.dailyWeatherNotificationEnabled = true,
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

  /// Computed dynamic Online / Offline status based on 90-second heartbeat window
  bool get isOnline {
    if (systemState == 'OFFLINE') return false;
    final now = DateTime.now();
    return now.difference(lastSeen).inSeconds < 90;
  }

  /// Safe, normalized soil moisture percentage [0..100] regardless of representation
  int get moisturePercentInt {
    if (moistureLevel == null) return 0;
    if (moistureLevel! > 1.0) {
      return moistureLevel!.round().clamp(0, 100);
    }
    return (moistureLevel! * 100).round().clamp(0, 100);
  }

  /// Whether the ESP32 is currently in grace fallback hotspot mode due to lost Wi-Fi
  bool get isGraceHotspotActive => systemState == 'FALLBACK_HOTSPOT';

  /// Human-friendly display label for hardware state
  String get stateDisplayLabel {
    if (isGraceHotspotActive) return 'Grace Hotspot (Wi-Fi Down)';
    if (!isOnline || systemState == 'OFFLINE') return 'Offline';
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
      case 'OFFLINE':
        return 'Offline';
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

  IotDevice copyWith({
    String? id,
    String? name,
    String? userId,
    List<String>? linkedUserIds,
    bool? isBluetoothConnected,
    bool? isWifiConnected,
    String? wifiSsid,
    String? stationIp,
    String? locationCity,
    String? locationRegion,
    String? locationCountry,
    double? locationLatitude,
    double? locationLongitude,
    bool? isIndoor,
    bool? dynamicMoistureAlertEnabled,
    bool? dailyWeatherNotificationEnabled,
    String? ntfyTopic,
    int? batteryLevel,
    int? signalStrength,
    bool? supportsMoistureSensor,
    bool? supportsAutoWater,
    double? moistureLevel,
    int? rawAdc,
    bool? isPumpRunning,
    bool? autoWaterEnabled,
    String? autoWaterSchedule,
    bool? isVerifiedCompatible,
    String? serviceUuid,
    String? firmwareVersion,
    DateTime? lastSeen,
    DateTime? lastReadingAt,
    DateTime? lastWateredAt,
    bool? lowMoistureAlertEnabled,
    int? lowMoistureThreshold,
    int? highMoistureThreshold,
    DateTime? lowMoistureIgnoredUntil,
    bool? lowMoistureAlwaysIgnored,
    String? linkedPlantId,
    String? linkedPlantName,
    String? linkedPlantImage,
    Map<String, dynamic>? pendingCommand,
    String? systemState,
    String? stateReason,
    int? reconnectAttempts,
  }) {
    return IotDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      linkedUserIds: linkedUserIds ?? this.linkedUserIds,
      isBluetoothConnected: isBluetoothConnected ?? this.isBluetoothConnected,
      isWifiConnected: isWifiConnected ?? this.isWifiConnected,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      stationIp: stationIp ?? this.stationIp,
      locationCity: locationCity ?? this.locationCity,
      locationRegion: locationRegion ?? this.locationRegion,
      locationCountry: locationCountry ?? this.locationCountry,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      isIndoor: isIndoor ?? this.isIndoor,
      dynamicMoistureAlertEnabled: dynamicMoistureAlertEnabled ?? this.dynamicMoistureAlertEnabled,
      dailyWeatherNotificationEnabled: dailyWeatherNotificationEnabled ?? this.dailyWeatherNotificationEnabled,
      ntfyTopic: ntfyTopic ?? this.ntfyTopic,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      supportsMoistureSensor: supportsMoistureSensor ?? this.supportsMoistureSensor,
      supportsAutoWater: supportsAutoWater ?? this.supportsAutoWater,
      moistureLevel: moistureLevel ?? this.moistureLevel,
      rawAdc: rawAdc ?? this.rawAdc,
      isPumpRunning: isPumpRunning ?? this.isPumpRunning,
      autoWaterEnabled: autoWaterEnabled ?? this.autoWaterEnabled,
      autoWaterSchedule: autoWaterSchedule ?? this.autoWaterSchedule,
      isVerifiedCompatible: isVerifiedCompatible ?? this.isVerifiedCompatible,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      lastSeen: lastSeen ?? this.lastSeen,
      lastReadingAt: lastReadingAt ?? this.lastReadingAt,
      lastWateredAt: lastWateredAt ?? this.lastWateredAt,
      lowMoistureAlertEnabled: lowMoistureAlertEnabled ?? this.lowMoistureAlertEnabled,
      lowMoistureThreshold: lowMoistureThreshold ?? this.lowMoistureThreshold,
      highMoistureThreshold: highMoistureThreshold ?? this.highMoistureThreshold,
      lowMoistureIgnoredUntil: lowMoistureIgnoredUntil ?? this.lowMoistureIgnoredUntil,
      lowMoistureAlwaysIgnored: lowMoistureAlwaysIgnored ?? this.lowMoistureAlwaysIgnored,
      linkedPlantId: linkedPlantId ?? this.linkedPlantId,
      linkedPlantName: linkedPlantName ?? this.linkedPlantName,
      linkedPlantImage: linkedPlantImage ?? this.linkedPlantImage,
      pendingCommand: pendingCommand ?? this.pendingCommand,
      systemState: systemState ?? this.systemState,
      stateReason: stateReason ?? this.stateReason,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }

  /// Formatted display name for the IoT-bound location
  String get locationDisplayName {
    if (locationCity != null && locationCity!.trim().isNotEmpty) {
      if (locationRegion != null &&
          locationRegion!.trim().isNotEmpty &&
          locationCity!.toLowerCase() != locationRegion!.toLowerCase()) {
        return '${locationCity!.trim()}, ${locationRegion!.trim()}';
      }
      return locationCity!.trim();
    }
    return 'Location Not Bound';
  }

  /// Calculates dynamic soil moisture target based on indoor/outdoor setting and live weather metrics.
  int calculateDynamicTargetMoisture(dynamic weatherData, {dynamic plant}) {
    final bool effectiveIndoor = (plant != null && plant.isIndoor is bool)
        ? (plant.isIndoor as bool)
        : isIndoor;

    if (effectiveIndoor || weatherData == null) {
      return highMoistureThreshold; // Default ~60-65%
    }

    final bool isRainGuard = (weatherData.isRainGuardActive as bool? ?? false);
    if (isRainGuard) {
      return 50; // Relaxed target to let natural rainfall hydrate without pump
    }

    final double temp = (weatherData.temperature as num?)?.toDouble() ?? 28.0;
    final int humidity = (weatherData.relativeHumidity as num?)?.toInt() ?? 65;

    if (temp >= 32.0 || humidity <= 45) {
      // Hot and dry -> boost target cushion to counteract rapid evaporation
      return (highMoistureThreshold + 5).clamp(65, 80);
    }
    if (temp <= 24.0 || humidity >= 80) {
      // Cool and humid -> relax target to avoid root sogginess
      return (highMoistureThreshold - 5).clamp(45, 65);
    }
    return highMoistureThreshold;
  }

  /// Human-readable explanation of why the target moisture is configured this way.
  String getDynamicWateringExplanation(dynamic weatherData, {dynamic plant}) {
    final int target = calculateDynamicTargetMoisture(weatherData, plant: plant);
    final bool effectiveIndoor = (plant != null && plant.isIndoor is bool)
        ? (plant.isIndoor as bool)
        : isIndoor;

    if (effectiveIndoor) {
      return '🏠 Indoor Environment: Soil moisture target is fixed at $target%. The plant is sheltered from outdoor rain, wind, and solar evaporation.';
    }
    if (weatherData == null) {
      return '🌿 Outdoor Environment: Standard smart watering target at $target%. Connect to local microclimate weather for dynamic adjustments.';
    }
    final bool isRainGuard = (weatherData.isRainGuardActive as bool? ?? false);
    if (isRainGuard) {
      final rainAmt = (weatherData.rainAmount as num?)?.toDouble() ?? 0.0;
      final precipProb = (weatherData.precipitationProbability as num?)?.toInt() ?? 0;
      return '🌧️ Outdoor Dynamic Watering (Rain Guard Active): Natural rain detected ($rainAmt mm, $precipProb% chance). Target reduced to $target% to prevent root saturation.';
    }
    final double temp = (weatherData.temperature as num?)?.toDouble() ?? 28.0;
    final int humidity = (weatherData.relativeHumidity as num?)?.toInt() ?? 65;
    if (temp >= 32.0 || humidity <= 45) {
      return '☀️ Outdoor Dynamic Watering (Heat Compensation): Hot weather (${temp.toStringAsFixed(1)}°C, $humidity% RH) causes rapid soil evaporation. Target boosted to $target% to protect roots.';
    }
    if (temp <= 24.0 || humidity >= 80) {
      return '⛅ Outdoor Dynamic Watering (Cool & Humid): Low evaporation (${temp.toStringAsFixed(1)}°C, $humidity% RH). Target relaxed to $target% to prevent fungal dampness.';
    }
    final cond = weatherData.weatherCondition?.toString() ?? 'Moderate';
    return '☀️ Outdoor Dynamic Watering (Balanced): Normal outdoor conditions (${temp.toStringAsFixed(1)}°C, $cond). Target set at $target%.';
  }

  /// Calculates dynamic soil moisture alert trigger threshold.
  /// Rule:
  /// 1. Base on plant species criticalMinMoisture (e.g. 15%).
  /// 2. If Outdoor:
  ///    - When raining: Trigger ONLY below minimal moisture (e.g. 15%).
  ///    - Other days (sunny/dry/wind): Trigger at minimal moisture + 10% (e.g. 25%).
  /// 3. If Indoor:
  ///    - Trigger at minimal moisture + 10% by default (e.g. 25%).
  int calculateDynamicAlertThreshold({dynamic plant, dynamic weatherData}) {
    if (!dynamicMoistureAlertEnabled) {
      return lowMoistureThreshold;
    }
    final int baseMin = (plant != null && plant.criticalMinMoisture is int)
        ? (plant.criticalMinMoisture as int)
        : 15;
    final bool effectiveIndoor = (plant != null && plant.isIndoor is bool)
        ? (plant.isIndoor as bool)
        : isIndoor;

    final int optMin = (plant != null && plant.optimalMinMoisture is int)
        ? (plant.optimalMinMoisture as int)
        : (baseMin + 5);

    if (effectiveIndoor) {
      return optMin.clamp(5, 50);
    }
    final bool isRaining = (weatherData != null && (weatherData.isRainGuardActive == true || weatherData.isRaining == true));
    if (isRaining) {
      return baseMin.clamp(5, 50);
    }
    return optMin.clamp(5, 50);
  }

  String getDynamicAlertThresholdExplanation({dynamic plant, dynamic weatherData}) {
    final int baseMin = (plant != null && plant.criticalMinMoisture is int)
        ? (plant.criticalMinMoisture as int)
        : 15;
    final String plantName = plant?.name?.toString() ?? name;
    final String species = plant?.species?.toString() ?? 'Monitored Specimen';
    final bool effectiveIndoor = (plant != null && plant.isIndoor is bool)
        ? (plant.isIndoor as bool)
        : isIndoor;

    if (effectiveIndoor) {
      return '🏠 Sheltered Indoor Alert: $species ($plantName) has a baseline minimum of $baseMin%. Sheltered indoors, the alert is set to ${baseMin + 10}% (+10% safety buffer) so you are notified before dehydration.';
    }
    final bool isRaining = (weatherData != null && (weatherData.isRainGuardActive == true || weatherData.isRaining == true));
    if (isRaining) {
      return '🌧️ Outdoor Rain Guard Alert: Rain is detected or forecast today. Alert threshold is kept at $baseMin% (critical survival minimum) to allow natural rainfall to hydrate the plant without unnecessary alerts.';
    }
    return '☀️ Outdoor Clear Alert: $species ($plantName) has a baseline minimum of $baseMin%. On dry/clear days, alert triggers at ${baseMin + 10}% (+10% safety buffer) to protect roots against sun and wind transpiration.';
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
      'dynamicMoistureAlertEnabled': dynamicMoistureAlertEnabled,
      'dailyWeatherNotificationEnabled': dailyWeatherNotificationEnabled,
      'linkedPlantId': linkedPlantId,
      'linkedPlantName': linkedPlantName,
      'linkedPlantImage': linkedPlantImage,
      'pendingCommand': pendingCommand,
      'systemState': systemState,
      'stateReason': stateReason,
      'reconnectAttempts': reconnectAttempts,
      'stationIp': stationIp,
      'locationCity': locationCity,
      'locationRegion': locationRegion,
      'locationCountry': locationCountry,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'isIndoor': isIndoor,
      'environment': isIndoor ? 'indoor' : 'outdoor',
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
    if (map['moistureLevel'] is num) {
      parsedMoisture = (map['moistureLevel'] as num).toDouble();
    } else if (map['moisturePercent'] is num) {
      parsedMoisture = (map['moisturePercent'] as num).toDouble();
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
      dynamicMoistureAlertEnabled: map['dynamicMoistureAlertEnabled'] as bool? ?? true,
      dailyWeatherNotificationEnabled: map['dailyWeatherNotificationEnabled'] as bool? ?? true,
      linkedPlantId: map['linkedPlantId'] as String?,
      linkedPlantName: map['linkedPlantName'] as String?,
      linkedPlantImage: map['linkedPlantImage'] as String?,
      pendingCommand: map['pendingCommand'] is Map ? Map<String, dynamic>.from(map['pendingCommand'] as Map) : null,
      systemState: map['systemState'] as String?,
      stateReason: map['stateReason'] as String?,
      reconnectAttempts: (map['reconnectAttempts'] as num?)?.toInt() ?? 0,
      stationIp: map['stationIp'] as String?,
      locationCity: map['locationCity'] as String? ?? map['city'] as String?,
      locationRegion: map['locationRegion'] as String? ?? map['region'] as String?,
      locationCountry: map['locationCountry'] as String? ?? map['country'] as String?,
      locationLatitude: (map['locationLatitude'] as num?)?.toDouble() ?? (map['latitude'] as num?)?.toDouble(),
      locationLongitude: (map['locationLongitude'] as num?)?.toDouble() ?? (map['longitude'] as num?)?.toDouble(),
      isIndoor: map['isIndoor'] as bool? ?? (map['environment'] != 'outdoor'),
    );
  }
}
