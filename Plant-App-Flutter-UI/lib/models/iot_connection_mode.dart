import 'plant_species_profile_model.dart';

/// Connection mode options for the IoT Device
enum ConnectionMode {
  disconnected,
  localWifi,     // Direct Local Wi-Fi Access Point (http://192.168.4.1)
  wifiCloud,     // Paired to home Wi-Fi + Global ntfy.sh push notification bridge
  @Deprecated('BLE architecture replaced by SoftAP Captive Portal')
  bluetoothOnly, // Deprecated BLE stub
}

/// Comprehensive state model for an IoT device's settings, linking, and connection preference
class IotDeviceConfig {
  final String deviceId;
  String deviceName;
  ConnectionMode connectionMode;
  String? wifiSsid;
  String ntfyTopic;
  String? linkedPlantId;
  String? linkedPlantName;
  String? linkedPlantSpecies;
  PlantSpeciesProfile speciesProfile;
  int customLowThreshold;
  int customHighThreshold;
  DateTime lastSyncedAt;
  bool isAlertEnabled;

  IotDeviceConfig({
    required this.deviceId,
    required this.deviceName,
    this.connectionMode = ConnectionMode.wifiCloud,
    this.wifiSsid,
    this.ntfyTopic = 'urbangreen_esp32_alerts',
    this.linkedPlantId,
    this.linkedPlantName,
    this.linkedPlantSpecies,
    PlantSpeciesProfile? speciesProfile,
    int? customLowThreshold,
    int? customHighThreshold,
    DateTime? lastSyncedAt,
    this.isAlertEnabled = true,
  })  : speciesProfile = speciesProfile ?? PlantSpeciesProfile.defaultProfile,
        customLowThreshold = customLowThreshold ?? (speciesProfile?.lowMoistureThreshold ?? 25),
        customHighThreshold = customHighThreshold ?? (speciesProfile?.highMoistureThreshold ?? 45),
        lastSyncedAt = lastSyncedAt ?? DateTime.now();

  /// Reset connection preferences
  void resetConnectionPreference(ConnectionMode newMode) {
    connectionMode = newMode;
    lastSyncedAt = DateTime.now();
  }

  /// Automatically tailor threshold calibration to match a plant species
  void tailorToPlant({
    required String plantId,
    required String plantName,
    required String species,
  }) {
    linkedPlantId = plantId;
    linkedPlantName = plantName;
    linkedPlantSpecies = species;
    speciesProfile = PlantSpeciesProfile.resolveForSpecies(species);
    customLowThreshold = speciesProfile.lowMoistureThreshold;
    customHighThreshold = speciesProfile.highMoistureThreshold;
    lastSyncedAt = DateTime.now();
  }

  /// Unlink plant and revert to standard profile
  void unlinkPlant() {
    linkedPlantId = null;
    linkedPlantName = null;
    linkedPlantSpecies = null;
    speciesProfile = PlantSpeciesProfile.defaultProfile;
    customLowThreshold = PlantSpeciesProfile.defaultProfile.lowMoistureThreshold;
    customHighThreshold = PlantSpeciesProfile.defaultProfile.highMoistureThreshold;
    lastSyncedAt = DateTime.now();
  }

  /// Completely factory reset all parameters, clear Wi-Fi, unlink plant, and return to disconnected state
  void factoryReset() {
    connectionMode = ConnectionMode.disconnected;
    wifiSsid = null;
    linkedPlantId = null;
    linkedPlantName = null;
    linkedPlantSpecies = null;
    speciesProfile = PlantSpeciesProfile.defaultProfile;
    customLowThreshold = PlantSpeciesProfile.defaultProfile.lowMoistureThreshold;
    customHighThreshold = PlantSpeciesProfile.defaultProfile.highMoistureThreshold;
    isAlertEnabled = true;
    lastSyncedAt = DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'connectionMode': connectionMode.name,
      'wifiSsid': wifiSsid,
      'ntfyTopic': ntfyTopic,
      'linkedPlantId': linkedPlantId,
      'linkedPlantName': linkedPlantName,
      'linkedPlantSpecies': linkedPlantSpecies,
      'lowThreshold': customLowThreshold,
      'highThreshold': customHighThreshold,
      'speciesProfile': speciesProfile.speciesName,
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
      'isAlertEnabled': isAlertEnabled,
    };
  }

  factory IotDeviceConfig.fromMap(Map<String, dynamic> map) {
    final modeString = map['connectionMode'] as String? ?? 'wifiCloud';
    final mode = ConnectionMode.values.firstWhere(
      (m) => m.name == modeString,
      orElse: () => ConnectionMode.wifiCloud,
    );

    final species = map['linkedPlantSpecies'] as String?;
    final profile = PlantSpeciesProfile.resolveForSpecies(species);

    return IotDeviceConfig(
      deviceId: map['deviceId'] as String? ?? 'ESP32-NODE-01',
      deviceName: map['deviceName'] as String? ?? 'Smart Plant Probe',
      connectionMode: mode,
      wifiSsid: map['wifiSsid'] as String?,
      ntfyTopic: map['ntfyTopic'] as String? ?? 'urbangreen_esp32_alerts',
      linkedPlantId: map['linkedPlantId'] as String?,
      linkedPlantName: map['linkedPlantName'] as String?,
      linkedPlantSpecies: species,
      speciesProfile: profile,
      customLowThreshold: (map['lowThreshold'] as num?)?.toInt() ?? profile.lowMoistureThreshold,
      customHighThreshold: (map['highThreshold'] as num?)?.toInt() ?? profile.highMoistureThreshold,
      lastSyncedAt: map['lastSyncedAt'] != null ? DateTime.parse(map['lastSyncedAt']) : DateTime.now(),
      isAlertEnabled: map['isAlertEnabled'] as bool? ?? true,
    );
  }
}

/// Model representing a scanned nearby Wi-Fi access point
class WifiNetwork {
  final String ssid;
  final int signalStrength; // 0 to 100%
  final bool isSecured;
  final String securityType;

  const WifiNetwork({
    required this.ssid,
    required this.signalStrength,
    this.isSecured = true,
    this.securityType = 'WPA2/WPA3',
  });
}

/// Deprecated BLE device container kept for backward compatibility
@Deprecated('BLE architecture replaced by SoftAP Captive Portal')
class DiscoveredBluetoothDevice {
  final String deviceId;
  final String deviceName;
  final int rssi;
  final bool isConnected;
  final List<String> advertisedServiceUuids;
  final String? deviceCategory;

  const DiscoveredBluetoothDevice({
    required this.deviceId,
    required this.deviceName,
    required this.rssi,
    this.isConnected = false,
    this.advertisedServiceUuids = const [],
    this.deviceCategory,
  });

  static const String urbanGreenServiceUuid = 'SoftAP-ESP32-Setup';
  bool get isCompatibleIotDevice => true;
  String get compatibilityLabel => 'UrbanGreen ESP32 Probe';
}
