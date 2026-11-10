import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/iot_connection_mode.dart';
import '../../models/plant_model.dart';
import '../../models/plant_species_profile_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/platform/web_hardware_bridge.dart';

class IotAdvancedManagementScreen extends StatefulWidget {
  final String deviceId;
  final Plant? currentPlant;

  const IotAdvancedManagementScreen({
    super.key,
    this.deviceId = 'ESP32-PLANT-01',
    this.currentPlant,
  });

  @override
  State<IotAdvancedManagementScreen> createState() => _IotAdvancedManagementScreenState();
}

class _IotAdvancedManagementScreenState extends State<IotAdvancedManagementScreen> {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  late IotDeviceConfig _config;

  // Mock plants available in user's garden for linking
  late List<Plant> _userPlants;
  Plant? _selectedPlant;

  // Live hardware telemetry & state
  double _currentMoisture = 0.0;
  int _rawAdc = 3200;
  String _hardwareSystemMode = 'AUTO';
  String _lastHardwareMsg = '';
  bool _isPumpActive = false;
  bool _isLoading = false;
  bool _isAutoWateringActive = false;
  Timer? _telemetryTimer;

  // Bluetooth scanning and discovery states
  bool _isBleScanning = false;
  List<DiscoveredBluetoothDevice> _discoveredBleDevices = [];
  bool _filterCompatibleOnly = true;
  bool _showCompatibilityExplainer = false;

  @override
  void initState() {
    super.initState();
    _config = _service.getDevice(widget.deviceId);
    _discoveredBleDevices = _service.discoveredBleDevices;

    _userPlants = [
      Plant(
        id: 'p1',
        name: 'My Jade Snake Plant',
        species: 'Sansevieria trifasciata',
        imageUrl: '',
        description: 'Hardy bedroom air-purifying succulent.',
      ),
      Plant(
        id: 'p2',
        name: 'Living Room Peace Lily',
        species: 'Spathiphyllum',
        imageUrl: '',
        description: 'Moisture loving flowering shade plant.',
      ),
      Plant(
        id: 'p3',
        name: 'Kitchen Garden Basil',
        species: 'Ocimum basilicum',
        imageUrl: '',
        description: 'Aromatic sweet culinary herb.',
      ),
      Plant(
        id: 'p4',
        name: 'Balcony Monstera',
        species: 'Monstera deliciosa',
        imageUrl: '',
        description: 'Classic tropical Swiss cheese split-leaf.',
      ),
    ];

    if (widget.currentPlant != null) {
      _selectedPlant = widget.currentPlant;
      _autoTailorToPlant(_selectedPlant!, showToast: false);
    } else if (_config.linkedPlantId != null) {
      _selectedPlant = _userPlants.firstWhere(
        (p) => p.id == _config.linkedPlantId,
        orElse: () => _userPlants.first,
      );
    }

    // Start background telemetry loop
    _startTelemetryLoop();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  /// Active telemetry polling loop with hardware ping
  void _startTelemetryLoop() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _tickTelemetry();
    });
  }

  Future<void> _tickTelemetry() async {
    if (!mounted) return;

    // 1. Fetch real hardware sensor data directly from the ESP32
    final res = await WebHardwareBridge.sendHttpRequest(
      'http://${_service.targetDeviceIp}/api/data',
      timeout: const Duration(seconds: 2),
    );

    if (res['success'] == true && res['data'] is Map) {
      final data = res['data'] as Map;
      _service.isRealHardwareConnected = true;
      if (mounted) {
        setState(() {
          _currentMoisture = ((data['moisture'] as num?) ?? _currentMoisture).toDouble();
          _isPumpActive = data['pump'] == 1;
          _rawAdc = (data['raw'] as int?) ?? _rawAdc;
          _hardwareSystemMode = (data['mode'] as String?) ?? _hardwareSystemMode;
          _lastHardwareMsg = (data['msg'] as String?) ?? _lastHardwareMsg;
        });
      }

      // If connected via Wi-Fi Cloud, push real sensor telemetry to Firestore
      if (_config.connectionMode == ConnectionMode.wifiCloud) {
        _service.pushTelemetryLogToFirebase(
          deviceId: _config.deviceId,
          moisturePercent: _currentMoisture,
          isPumpRunning: _isPumpActive,
        );
      }
      return;
    } else {
      if (_service.isRealHardwareConnected && mounted) {
        setState(() => _service.isRealHardwareConnected = false);
      }
    }

    // 2. Only if explicitly running in Virtual Demo Simulation Mode
    if (_config.deviceName.contains('Demo') || _config.deviceName.contains('Virtual')) {
      setState(() {
        if (_isPumpActive) {
          _currentMoisture = (_currentMoisture + 4.5).clamp(0.0, 100.0);
          if (_currentMoisture >= _config.customHighThreshold) {
            _isPumpActive = false;
            _showFeedback(OperationFeedback.success(
              'Hydration Target Met',
              'Soil moisture reached cutoff (>= ${_config.customHighThreshold}%). Pump automatically turned off.',
            ));
          }
        } else {
          if (_currentMoisture > 10.0) {
            _currentMoisture = (_currentMoisture - 0.3).clamp(0.0, 100.0);
          }
          if (_currentMoisture < _config.customLowThreshold && !_isAutoWateringActive) {
            _isAutoWateringActive = true;
            _triggerAutoWateringCycle();
          }
        }
      });
    }
  }

  /// Toggle between strictly decoupled AUTO and MANUAL mode on ESP32
  Future<void> _toggleHardwareMode() async {
    final res = await WebHardwareBridge.sendHttpRequest(
      'http://${_service.targetDeviceIp}/api/mode?toggle=1',
      timeout: const Duration(seconds: 3),
    );
    if (res['success'] == true && res['data'] is Map) {
      final data = res['data'] as Map;
      setState(() {
        _hardwareSystemMode = (data['mode'] as String?) ?? 'AUTO';
        _lastHardwareMsg = (data['msg'] as String?) ?? '';
      });
      _showFeedback(OperationFeedback.success(
        'System Mode Changed',
        'ESP32 switched to $_hardwareSystemMode mode.',
      ));
    } else {
      _showFeedback(OperationFeedback.fail(
        'Mode Toggle Failed',
        'ESP32 unreachable at ${_service.targetDeviceIp}: ${res['error']}',
      ));
    }
  }

  void _triggerAutoWateringCycle() {
    setState(() => _isPumpActive = true);
    _showFeedback(OperationFeedback.success(
      '🚨 Auto-Watering Started',
      'Moisture (${_currentMoisture.toInt()}%) is below trigger threshold (< ${_config.customLowThreshold}%). Pump activated.',
    ));

    _service.pushTelemetryLogToFirebase(
      deviceId: _config.deviceId,
      moisturePercent: _currentMoisture,
      isPumpRunning: true,
    );

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _isAutoWateringActive = false;
      }
    });
  }

  void _showFeedback(OperationFeedback feedback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              feedback.isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    feedback.message,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: feedback.isSuccess ? kPrimaryColor : kStatusDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: BLUETOOTH PAIRING & PROVISIONING FLOW
  // ---------------------------------------------------------------------------

  /// Open dedicated sheet that shows a list of compatible IoT devices first
  void _showDevicePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _IotDevicePickerBottomSheet(
          service: _service,
          onDeviceSelected: (DiscoveredBluetoothDevice device) async {
            Navigator.pop(ctx);
            await _connectToSelectedDevice(device);
          },
          onScanNativeHardware: () async {
            Navigator.pop(ctx);
            await _initiateBluetoothPairing();
          },
        );
      },
    );
  }

  /// Connect to the specific compatible IoT device picked by the user
  Future<void> _connectToSelectedDevice(DiscoveredBluetoothDevice device) async {
    setState(() => _isLoading = true);

    final feedback = await _service.pairViaBluetooth(
      device.deviceId,
      allowDemoFallback: true,
    );

    setState(() {
      _isLoading = false;
      _config = _service.getDevice(device.deviceId);
      _isBleScanning = false;
      _discoveredBleDevices = _service.discoveredBleDevices;
    });

    _showFeedback(feedback);

    if (feedback.isSuccess && mounted) {
      _promptWifiPairingChoice();
    }
  }

  Future<void> _initiateBluetoothPairing([String? targetDeviceId]) async {
    final devId = targetDeviceId ?? _config.deviceId;

    // Check if target device is known and incompatible
    final knownDev = _discoveredBleDevices.where((d) => d.deviceId == devId).firstOrNull;
    if (knownDev != null && !knownDev.isCompatibleIotDevice) {
      _showIncompatibleDeviceDialog(knownDev);
      return;
    }

    setState(() => _isLoading = true);

    // If targetDeviceId is a known compatible simulation probe, allow demo fallback
    final isDemoProbe = knownDev != null && knownDev.isCompatibleIotDevice && !_service.isRealHardwareConnected;
    final feedback = await _service.pairViaBluetooth(
      devId,
      allowDemoFallback: isDemoProbe,
    );

    setState(() {
      _isLoading = false;
      _config = _service.getDevice(devId);
      _isBleScanning = false;
    });

    if (feedback.isSuccess && mounted) {
      _showFeedback(feedback);
      _promptWifiPairingChoice();
    } else if (mounted) {
      _showFeedback(feedback);
      if (feedback.data?['incompatible'] == true) {
        final devName = feedback.data?['deviceName'] as String? ?? 'Unknown Device';
        _showIncompatibleDeviceDialog(
          knownDev ?? DiscoveredBluetoothDevice(
            deviceId: devId,
            deviceName: devName,
            rssi: -50,
          ),
        );
      } else {
        _showBluetoothFailureDialog(devId, feedback.message);
      }
    }
  }

  /// Dialog explaining why a selected Bluetooth device is incompatible
  void _showIncompatibleDeviceDialog(DiscoveredBluetoothDevice dev) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.block_flipped, color: Colors.orange.shade800, size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Incompatible Bluetooth Device',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(_getDeviceCategoryIcon(dev), size: 28, color: Colors.orange.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dev.deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            dev.compatibilityLabel,
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Why can\'t I pair this device?\n'
                'This device does not support UrbanGreen SmartPlant functions (soil moisture monitoring or water pump relay control).\n\n'
                'How the app verifies compatible IoT devices:\n'
                '• GATT Service UUID: Probes advertise 0xFF01 (0000FF01-0000-1000-8000-00805F9B34FB)\n'
                '• Name Signature: Starts with "SmartPlant-" or "UrbanGreen-"\n'
                '• Sensor Telemetry: GATT Characteristic for capacitance moisture\n\n'
                'Please select your ESP32 SmartPlant probe from the list.',
                style: TextStyle(fontSize: 12, height: 1.45, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Understood'),
            ),
          ],
        );
      },
    );
  }

  IconData _getDeviceCategoryIcon(DiscoveredBluetoothDevice dev) {
    if (dev.isCompatibleIotDevice) return Icons.eco_rounded;
    final lower = dev.deviceName.toLowerCase();
    if (lower.contains('headphone') ||
        lower.contains('wh-') ||
        lower.contains('buds') ||
        lower.contains('airpod') ||
        lower.contains('speaker') ||
        lower.contains('audio')) {
      return Icons.headphones_rounded;
    }
    if (lower.contains('watch') || lower.contains('band')) {
      return Icons.watch_rounded;
    }
    if (lower.contains('phone') || lower.contains('ipad') || lower.contains('pixel') || lower.contains('galaxy')) {
      return Icons.smartphone_rounded;
    }
    if (lower.contains('tv')) {
      return Icons.tv_rounded;
    }
    return Icons.devices_other_rounded;
  }

  /// Explicit demo mode activation (clearly separated from real hardware)
  Future<void> _activateDemoMode() async {
    setState(() => _isLoading = true);
    final res = await _service.enableDemoSimulationMode(_config.deviceId);
    setState(() {
      _isLoading = false;
      _config = _service.getDevice(_config.deviceId);
      _discoveredBleDevices = _service.discoveredBleDevices;
    });
    _showFeedback(res);
    if (mounted) {
      _promptWifiPairingChoice();
    }
  }

  /// Dialog when real Bluetooth hardware is not found / unpowered
  void _showBluetoothFailureDialog(String devId, String errorMsg) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled_rounded, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Text('IoT Hardware Not Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMsg, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.power_off_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Is your ESP32 powered on? Plug in the USB cable to power up the board before pairing.',
                        style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _initiateBluetoothPairing(devId); // Retry real scan
              },
              child: const Text('Retry Hardware Scan'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _activateDemoMode();
              },
              icon: const Icon(Icons.science_outlined, size: 16),
              label: const Text('Test with Demo Mode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Toggle Bluetooth Discovery scan on/off
  Future<void> _toggleBluetoothScan() async {
    setState(() => _isLoading = true);
    final feedback = await _service.toggleBluetoothScan();
    setState(() {
      _isLoading = false;
      _isBleScanning = _service.isBluetoothScanning;
      _discoveredBleDevices = _service.discoveredBleDevices;
    });
    _showFeedback(feedback);
  }

  void _promptWifiPairingChoice() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.wifi_rounded, color: kPrimaryColor),
              SizedBox(width: 10),
              Text('Connect to Wi-Fi?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your phone is paired with the IoT device via Bluetooth!\n\n'
            'Would you like to connect this device to your home Wi-Fi network so you can receive cloud updates and remote alerts when away from home?',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            // User says NO
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showBluetoothOnlyWarningDialog();
              },
              child: const Text('No, Bluetooth Only', style: TextStyle(color: Colors.grey)),
            ),
            // User says YES: Show available Wi-Fi networks!
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showWifiSelectionSheet();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Yes, Select Wi-Fi'),
            ),
          ],
        );
      },
    );
  }

  // Warning when user refuses Wi-Fi
  void _showBluetoothOnlyWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFFBEB), // Soft Warning Amber
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: kStatusWarning, size: 28),
              SizedBox(width: 10),
              Text('Offline Mode Notice', style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            '⚠️ Without a Wi-Fi connection, you will NOT receive remote push notifications or cloud historical logs when away from home.\n\n'
            'You can only use simple functions to view live moisture and control the pump when within direct Bluetooth range (~10 meters).',
            style: TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _service.selectBluetoothOnlyMode(_config.deviceId);
                setState(() {});
                _showFeedback(res);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kStatusWarning,
                foregroundColor: Colors.white,
              ),
              child: const Text('I Understand, Continue'),
            ),
          ],
        );
      },
    );
  }

  /// Show available Wi-Fi networks discovered by the IoT device
  void _showWifiSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _WifiPickerBottomSheet(
          service: _service,
          onWifiSelected: (WifiNetwork network) {
            Navigator.pop(ctx);
            if (!network.isSecured) {
              _connectToWifi(network.ssid, '');
            } else {
              _showWifiPasswordDialog(network);
            }
          },
          onManualEntrySelected: () {
            Navigator.pop(ctx);
            _showCustomWifiDialog();
          },
        );
      },
    );
  }

  /// Dialog to enter ONLY the password for the selected Wi-Fi network
  void _showWifiPasswordDialog(WifiNetwork network) {
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.wifi_lock_rounded, color: kPrimaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Password for "${network.ssid}"',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        network.signalStrength > 70 ? Icons.wifi : Icons.wifi_2_bar,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Signal: ${network.signalStrength}% • Security: ${network.securityType}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Wi-Fi Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setDialogState(() => obscure = !obscure);
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showWifiSelectionSheet(); // Back to list
                  },
                  child: const Text('Back to List'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pass = passwordController.text;
                    Navigator.pop(ctx);
                    _connectToWifi(network.ssid, pass);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Fallback dialog to manually enter hidden or unbroadcasted Wi-Fi SSID
  void _showCustomWifiDialog() {
    final ssidController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Other / Hidden Wi-Fi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssidController,
                decoration: InputDecoration(
                  labelText: 'Network Name (SSID)',
                  prefixIcon: const Icon(Icons.wifi),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password (leave empty if open)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final ssid = ssidController.text.trim();
                final pass = passController.text;
                Navigator.pop(ctx);
                _connectToWifi(ssid, pass);
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  /// Provision Wi-Fi with selected credentials
  Future<void> _connectToWifi(String ssid, String password) async {
    setState(() => _isLoading = true);
    final res = await _service.provisionWifiAndFirebase(
      deviceId: _config.deviceId,
      wifiSsid: ssid,
      wifiPassword: password,
    );
    setState(() => _isLoading = false);
    _showFeedback(res);
  }

  /// Confirmation dialog to factory reset the IoT device
  void _showResetIotConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.restart_alt_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Reset IoT Device?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.red)),
            ],
          ),
          content: const Text(
            'Are you sure you want to reset this IoT device to factory settings?\n\n'
            '• Stored Wi-Fi network credentials will be wiped\n'
            '• Any linked plant configuration will be removed\n'
            '• Moisture trigger thresholds will revert to hardware defaults (< 25% / >= 45%)\n'
            '• Connection preferences will be completely cleared\n\n'
            'The device will return to initial discovery & pairing mode.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                final res = await _service.resetIotDevice(_config.deviceId);
                setState(() {
                  _selectedPlant = null;
                  _isBleScanning = false;
                  _isLoading = false;
                });
                _showFeedback(res);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Yes, Factory Reset'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: IOT PREFERENCE SWITCHER (RESET LOGIC)
  // ---------------------------------------------------------------------------

  Future<void> _switchConnectionPreference(ConnectionMode targetMode) async {
    if (targetMode == _config.connectionMode) return;

    if (targetMode == ConnectionMode.wifiCloud) {
      _showWifiSelectionSheet();
    } else {
      setState(() => _isLoading = true);
      // Reset preference cleanly
      final res = await _service.switchConnectionMethod(
        deviceId: _config.deviceId,
        newMode: targetMode,
      );
      setState(() => _isLoading = false);
      _showFeedback(res);
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 3: PLANT LINKING & BOTANICAL SPECIES AUTO-TAILORING
  // ---------------------------------------------------------------------------

  Future<void> _autoTailorToPlant(Plant plant, {bool showToast = true}) async {
    setState(() => _isLoading = true);

    final res = await _service.linkDeviceToPlant(
      deviceId: _config.deviceId,
      plantId: plant.id,
      plantName: plant.name,
      species: plant.species,
    );

    setState(() {
      _selectedPlant = plant;
      _isLoading = false;
    });

    if (showToast) {
      _showFeedback(res);
    }
  }

  Future<void> _unlinkPlant() async {
    setState(() => _isLoading = true);
    final res = await _service.unlinkDeviceFromPlant(_config.deviceId);
    setState(() {
      _selectedPlant = null;
      _isLoading = false;
    });
    _showFeedback(res);
  }

  // ---------------------------------------------------------------------------
  // MANUAL CONTROLS & TEST PULSE
  // ---------------------------------------------------------------------------

  Future<void> _manualPulseWater() async {
    setState(() => _isPumpActive = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💧 Sending water pulse command to ESP32...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 4),
      ),
    );

    final res = await _service.pulseWater(_config.deviceId);

    if (mounted) {
      // Re-read actual data from ESP32
      final pingRes = await WebHardwareBridge.sendHttpRequest(
        'http://${_service.targetDeviceIp}/api/data',
        timeout: const Duration(seconds: 2),
      );

      setState(() {
        _isPumpActive = false;
        if (pingRes['success'] == true && pingRes['data'] is Map) {
          _currentMoisture = ((pingRes['data']['moisture'] as num?) ?? _currentMoisture).toDouble();
          _rawAdc = (pingRes['data']['raw'] as int?) ?? _rawAdc;
          _hardwareSystemMode = (pingRes['data']['mode'] as String?) ?? _hardwareSystemMode;
        }
      });

      if (_config.connectionMode == ConnectionMode.wifiCloud) {
        _service.pushTelemetryLogToFirebase(
          deviceId: _config.deviceId,
          moisturePercent: _currentMoisture,
          isPumpRunning: false,
        );
      }

      _showFeedback(res);
    }
  }

  void _showHardwareConfigDialog() {
    final ipController = TextEditingController(text: _service.targetDeviceIp);
    bool isPinging = false;
    String? pingResultMsg;
    bool? pingSuccess;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.router_rounded, color: kPrimaryColor),
                  SizedBox(width: 10),
                  Text('Hardware Link & Ping', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure target ESP32 IP address to exchange real sensor & relay commands over Wi-Fi:',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ipController,
                    decoration: InputDecoration(
                      labelText: 'Device IP / Hostname',
                      hintText: '192.168.4.1 or 192.168.1.xxx',
                      prefixIcon: const Icon(Icons.lan_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pingResultMsg != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pingSuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: pingSuccess == true ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        pingResultMsg!,
                        style: TextStyle(
                          fontSize: 11,
                          color: pingSuccess == true ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isPinging
                          ? null
                          : () async {
                              setDialogState(() {
                                isPinging = true;
                                pingResultMsg = 'Pinging ${ipController.text.trim()}...';
                              });
                              final res = await _service.testHardwarePing(ipController.text.trim());
                              setDialogState(() {
                                isPinging = false;
                                pingSuccess = res.isSuccess;
                                pingResultMsg = '${res.title}: ${res.message}';
                              });
                            },
                      icon: isPinging
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.speed_rounded, size: 16),
                      label: Text(isPinging ? 'Pinging ESP32...' : 'Test Connection (Ping)'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _service.targetDeviceIp = ipController.text.trim();
                    Navigator.pop(ctx);
                    setState(() {});
                    _showFeedback(OperationFeedback.success(
                      'Endpoint Saved',
                      'Target device IP set to "${_service.targetDeviceIp}".',
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Endpoint'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHardwareDiagnosticsBanner() {
    final isOnline = _service.isRealHardwareConnected;
    final hasError = _service.lastHardwareError != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.shade50
            : hasError
                ? const Color(0xFFFEF2F2)
                : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline
              ? Colors.green.shade200
              : hasError
                  ? Colors.red.shade200
                  : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline
                ? Icons.check_circle_rounded
                : hasError
                    ? Icons.warning_amber_rounded
                    : Icons.memory_rounded,
            size: 20,
            color: isOnline
                ? Colors.green
                : hasError
                    ? Colors.red
                    : Colors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline
                      ? 'Physical ESP32 Online (${_service.targetDeviceIp})'
                      : hasError
                          ? 'Hardware Offline (Fallback Active)'
                          : 'Virtual Hardware Node Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isOnline
                        ? Colors.green.shade900
                        : hasError
                            ? Colors.red.shade900
                            : Colors.blue.shade900,
                  ),
                ),
                Text(
                  isOnline
                      ? 'Live sensor telemetry & relay commands streaming over local network.'
                      : hasError
                          ? '${_service.lastHardwareError} • Operating in resilient fallback mode.'
                          : 'Browser localStorage & simulation engine active. Tap to link physical ESP32.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline
                        ? Colors.green.shade800
                        : hasError
                            ? Colors.red.shade800
                            : Colors.blue.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showHardwareConfigDialog,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Configure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = _config.connectionMode;
    final profile = _config.speciesProfile;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(_config.deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: context.surfaceBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.router_outlined),
            tooltip: 'Hardware Link & IP',
            onPressed: _showHardwareConfigDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Settings',
            onPressed: () {
              _showFeedback(OperationFeedback.success('Synced', 'Latest parameters retrieved.'));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 0. Hardware Link & Fallback Diagnostics Banner
                _buildHardwareDiagnosticsBanner(),

                // 1. Connection Status Hero Card
                _buildConnectionStatusCard(mode),
                const SizedBox(height: 16),

                // 2. Bluetooth Searching, Discovery & Recovery Card
                _buildBluetoothDiscoveryCard(),
                const SizedBox(height: 16),

                // 3. Connection Preference Switcher (Always resets cleanly)
                _buildPreferenceSwitcherCard(mode),
                const SizedBox(height: 16),

                // 4. Plant Species Linking & Auto-Tailoring Card
                _buildPlantLinkingCard(profile),
                const SizedBox(height: 16),

                // 5. Real-time Telemetry & Manual Action Card
                _buildLiveTelemetryCard(),
                const SizedBox(height: 16),

                // 6. Device Reset & Factory Diagnostics Card
                _buildDeviceMaintenanceCard(),
              ],
            ),
    );
  }

  Widget _buildConnectionStatusCard(ConnectionMode mode) {
    Color badgeColor;
    IconData modeIcon;
    String modeTitle;
    String modeDesc;

    switch (mode) {
      case ConnectionMode.localWifi:
        badgeColor = Colors.blue;
        modeIcon = Icons.wifi_tethering_rounded;
        modeTitle = 'SoftAP Captive Portal Mode';
        modeDesc = 'Connected to ESP32 local AP (192.168.4.1). Ready for setup.';
        break;
      case ConnectionMode.wifiCloud:
        badgeColor = kStatusSuccess;
        modeIcon = Icons.cloud_done_rounded;
        modeTitle = 'Wi-Fi & Firebase Cloud Active';
        modeDesc = 'Connected to "${_config.wifiSsid ?? 'Home Wi-Fi'}". Real-time cloud logs & remote alerts are streaming.';
        break;
      case ConnectionMode.bluetoothOnly:
        badgeColor = kStatusWarning;
        modeIcon = Icons.bluetooth_connected_rounded;
        modeTitle = 'Direct Bluetooth (Offline Mode)';
        modeDesc = 'Operating within local BLE range (~10m). Cloud alerts & remote feedback are paused.';
        break;
      case ConnectionMode.disconnected:
        badgeColor = Colors.grey;
        modeIcon = Icons.bluetooth_searching_rounded;
        modeTitle = 'Device Disconnected';
        modeDesc = 'Pair via Bluetooth to start monitoring your plant.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: badgeColor.withValues(alpha: 0.15),
                child: Icon(modeIcon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(modeTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: badgeColor)),
                    Text(modeDesc, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          if (mode == ConnectionMode.disconnected) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showDevicePickerSheet,
                icon: const Icon(Icons.devices_rounded, size: 18),
                label: const Text('Pair Device (Select Compatible Probe)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _activateDemoMode,
                icon: const Icon(Icons.science_outlined, size: 16, color: Colors.blueGrey),
                label: const Text('🧪 Test in Demo Mode (No Hardware Needed)', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitcherCard(ConnectionMode currentMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtleColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: kTextPrimary, size: 20),
              SizedBox(width: 8),
              Text('Connection Method Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select how you want this IoT device to connect. Switching automatically resets previous connection preferences.',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Bluetooth Option
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth, size: 16),
                      SizedBox(width: 6),
                      Text('Bluetooth Only', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  selected: currentMode == ConnectionMode.bluetoothOnly,
                  selectedColor: kAccentMint,
                  onSelected: (val) {
                    if (val) _switchConnectionPreference(ConnectionMode.bluetoothOnly);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Wi-Fi Cloud Option
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Wi-Fi + Cloud', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  selected: currentMode == ConnectionMode.wifiCloud,
                  selectedColor: Colors.blue.shade100,
                  onSelected: (val) {
                    if (val) _switchConnectionPreference(ConnectionMode.wifiCloud);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlantLinkingCard(PlantSpeciesProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtleColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.eco_rounded, color: kPrimaryColor, size: 20),
              SizedBox(width: 8),
              Text('Linked Plant & Species Auto-Tailoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary)),
            ],
          ),
          const SizedBox(height: 10),

          // Dropdown Plant Picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Plant>(
                isExpanded: true,
                hint: const Text('Select a plant in your garden to link...'),
                value: _selectedPlant,
                items: _userPlants.map((plant) {
                  return DropdownMenuItem<Plant>(
                    value: plant,
                    child: Text('${plant.name} (${plant.species})'),
                  );
                }).toList(),
                onChanged: (plant) {
                  if (plant != null) {
                    _autoTailorToPlant(plant);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tailored Profile Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderSubtleColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile: ${profile.speciesName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimaryDark),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        profile.category.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '💡 ${profile.careSummary}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildThresholdBadge('Dry Trigger', '< ${_config.customLowThreshold}%', Colors.red),
                    _buildThresholdBadge('Wet Cutoff', '>= ${_config.customHighThreshold}%', Colors.green),
                    _buildThresholdBadge('Cycle', profile.recommendedCycle.split('(').first.trim(), Colors.blue),
                  ],
                ),
              ],
            ),
          ),

          if (_selectedPlant != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _unlinkPlant,
                icon: const Icon(Icons.link_off, size: 16, color: Colors.red),
                label: const Text('Unlink Plant', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdBadge(String label, String value, MaterialColor color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.shade200),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade800),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTelemetryCard() {
    final isCriticallyDry = _currentMoisture < _config.customLowThreshold;
    final isWet = _currentMoisture >= _config.customHighThreshold;
    final progressColor = isCriticallyDry ? Colors.red : (isWet ? Colors.blue : Colors.green);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCriticallyDry ? Colors.red.shade200 : kBorderSubtle,
          width: isCriticallyDry ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live ESP32 Telemetry & Actuator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(
                children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor: _service.isRealHardwareConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _service.isRealHardwareConnected
                        ? 'ESP32 Online'
                        : (_config.deviceName.contains('Demo') ? 'Demo Simulation' : 'ESP32 Offline'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _service.isRealHardwareConnected
                          ? Colors.green.shade800
                          : (_config.deviceName.contains('Demo') ? Colors.blue.shade800 : Colors.orange.shade900),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_currentMoisture.toInt()}%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCriticallyDry ? 'DRY' : (isWet ? 'OPTIMAL / WET' : 'NORMAL'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Soil Moisture (Capacitive Pin 34) • Raw ADC: $_rawAdc',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isPumpActive ? null : _manualPulseWater,
                icon: _isPumpActive
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.water_drop_rounded, size: 16),
                label: Text(_isPumpActive ? 'Pumping...' : 'Pulse Water'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hardware status badges (Mode, Relay State, Target IP)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: _toggleHardwareMode,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _hardwareSystemMode == 'AUTO' ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _hardwareSystemMode == 'AUTO' ? Colors.green.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hardwareSystemMode == 'AUTO' ? Icons.autorenew_rounded : Icons.touch_app_rounded,
                        size: 13,
                        color: _hardwareSystemMode == 'AUTO' ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'MODE: $_hardwareSystemMode (Tap to Switch)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _hardwareSystemMode == 'AUTO' ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isPumpActive ? Colors.green.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isPumpActive ? Colors.green.shade400 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  _isPumpActive ? 'RELAY (PIN 23): ON' : 'RELAY: OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isPumpActive ? Colors.green.shade900 : Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Text(
                  'IP: ${_service.targetDeviceIp}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Visual moisture gauge bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentMoisture / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          if (isCriticallyDry) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Moisture < ${_config.customLowThreshold}%. Auto-irrigation trigger active.',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBluetoothDiscoveryCard() {
    final compatibleCount = _discoveredBleDevices.where((d) => d.isCompatibleIotDevice).length;
    final totalCount = _discoveredBleDevices.length;
    final displayDevices = _filterCompatibleOnly
        ? _discoveredBleDevices.where((d) => d.isCompatibleIotDevice).toList()
        : _discoveredBleDevices;

    // Always sort compatible probes to the very top, ordered by signal strength
    final sortedDevices = List<DiscoveredBluetoothDevice>.from(displayDevices)
      ..sort((a, b) {
        if (a.isCompatibleIotDevice && !b.isCompatibleIotDevice) return -1;
        if (!a.isCompatibleIotDevice && b.isCompatibleIotDevice) return 1;
        return b.rssi.compareTo(a.rssi);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isBleScanning ? kPrimaryColor.withValues(alpha: 0.5) : kBorderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _isBleScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                      color: _isBleScanning ? kPrimaryColor : kTextPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Bluetooth Discovery',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _toggleBluetoothScan,
                icon: Icon(_isBleScanning ? Icons.stop_circle_outlined : Icons.radar, size: 16),
                label: Text(_isBleScanning ? 'Stop' : 'Search', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: _isBleScanning ? Colors.red : kPrimaryColor,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Scans 2.4GHz BLE channels for nearby peripherals. UrbanGreen probes are verified via GATT Service UUID (0xFF01) and firmware signatures.',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          const SizedBox(height: 8),

          // Open Dedicated Device Picker Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showDevicePickerSheet,
              icon: const Icon(Icons.touch_app_rounded, size: 16),
              label: const Text('Pick from Compatible IoT Probes List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Collapsible Compatibility Explainer Banner
          InkWell(
            onTap: () {
              setState(() => _showCompatibilityExplainer = !_showCompatibilityExplainer);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: Colors.blue.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'How the app verifies compatible IoT devices',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _showCompatibilityExplainer ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.blue.shade800,
                  ),
                ],
              ),
            ),
          ),

          if (_showCompatibilityExplainer) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExplainerRow(
                    Icons.fingerprint,
                    '1. Custom GATT Service UUID',
                    'The probe broadcasts 0000FF01-0000-1000-8000-00805F9B34FB (0xFF01). Audio & wearables lack this UUID.',
                  ),
                  const SizedBox(height: 8),
                  _buildExplainerRow(
                    Icons.badge_outlined,
                    '2. Name & Manufacturer Signature',
                    'Firmware identifies with "SmartPlant-" or "UrbanGreen-".',
                  ),
                  const SizedBox(height: 8),
                  _buildExplainerRow(
                    Icons.handshake_outlined,
                    '3. Telemetry Handshake',
                    'App verifies Soil Moisture Characteristic (0xFF02) & Pump Relay Characteristic (0xFF03).',
                  ),
                ],
              ),
            ),
          ],

          if (_isBleScanning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Scanning BLE channels ($totalCount devices found, $compatibleCount compatible)...',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          if (_discoveredBleDevices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bluetooth_searching, color: Colors.grey, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'No Physical SmartPlant Probes Found',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ensure your ESP32 board is plugged into USB and powered on.\nOr load verified compatible probes in simulation mode:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _service.populateDemoBleDevices(includeIncompatible: true);
                            _discoveredBleDevices = _service.discoveredBleDevices;
                          });
                        },
                        icon: const Icon(Icons.devices_other_rounded, size: 14),
                        label: const Text('Show Nearby Devices (Compatible First)', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _service.populateDemoBleDevices(includeIncompatible: false);
                            _discoveredBleDevices = _service.discoveredBleDevices;
                          });
                        },
                        icon: const Icon(Icons.eco_rounded, size: 14),
                        label: const Text('Compatible Probes Only', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            // Filter Toggle Bar: Compatible Only is first!
            Row(
              children: [
                ChoiceChip(
                  label: Text('✓ Compatible ($compatibleCount)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _filterCompatibleOnly,
                  selectedColor: kAccentMint,
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    if (val) setState(() => _filterCompatibleOnly = true);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('All Devices ($totalCount)', style: const TextStyle(fontSize: 11)),
                  selected: !_filterCompatibleOnly,
                  selectedColor: Colors.blue.shade100,
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    if (val) setState(() => _filterCompatibleOnly = false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDevices.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, idx) {
                final dev = sortedDevices[idx];
                final isCurrent = _config.deviceId == dev.deviceId && _config.connectionMode != ConnectionMode.disconnected;
                final isCompat = dev.isCompatibleIotDevice;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCompat ? Colors.green.shade50.withValues(alpha: 0.25) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCompat ? Colors.green.shade200 : Colors.grey.shade300,
                      width: isCompat ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isCompat
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          _getDeviceCategoryIcon(dev),
                          size: 18,
                          color: isCompat ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.deviceName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            // Compatibility Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompat ? Colors.green.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCompat
                                    ? '✓ UrbanGreen IoT Probe (Service: 0xFF01)'
                                    : '✕ ${dev.compatibilityLabel}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCompat ? Colors.green.shade900 : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${dev.deviceId} • RSSI: ${dev.rssi} dBm',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isCompat)
                        ElevatedButton(
                          onPressed: () => _connectToSelectedDevice(dev),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent ? Colors.grey.shade200 : kPrimaryColor,
                            foregroundColor: isCurrent ? Colors.black87 : Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            elevation: 0,
                          ),
                          child: Text(isCurrent ? 'Re-pair' : 'Connect', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _showIncompatibleDeviceDialog(dev),
                          icon: const Icon(Icons.info_outline, size: 13),
                          label: const Text('Incompatible', style: TextStyle(fontSize: 10)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplainerRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kPrimaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: kTextPrimary)),
              const SizedBox(height: 1),
              Text(description, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceMaintenanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Device Reset & Maintenance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Need to re-configure or troubleshoot? Reset the IoT probe to clear all Wi-Fi credentials, plant bindings, and thresholds.',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showResetIotConfirmDialog,
              icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.red),
              label: const Text('Reset IoT Device to Factory Defaults', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet that scans and lists nearby available Wi-Fi networks
class _WifiPickerBottomSheet extends StatefulWidget {
  final IotHybridConnectivityService service;
  final ValueChanged<WifiNetwork> onWifiSelected;
  final VoidCallback onManualEntrySelected;

  const _WifiPickerBottomSheet({
    required this.service,
    required this.onWifiSelected,
    required this.onManualEntrySelected,
  });

  @override
  State<_WifiPickerBottomSheet> createState() => _WifiPickerBottomSheetState();
}

class _WifiPickerBottomSheetState extends State<_WifiPickerBottomSheet> {
  bool _isScanning = true;
  List<WifiNetwork> _networks = [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _isScanning = true);
    final results = await widget.service.scanNearbyWifiNetworks();
    if (mounted) {
      setState(() {
        _networks = results;
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.wifi_find_rounded, color: kPrimaryColor),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Wi-Fi Networks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Select your network to connect', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isScanning
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Rescan Wi-Fi',
                  onPressed: _isScanning ? null : _scan,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isScanning
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: kPrimaryColor),
                        SizedBox(height: 12),
                        Text('Scanning 2.4GHz Wi-Fi channels...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _networks.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                    itemBuilder: (ctx, index) {
                      if (index == _networks.length) {
                        return ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFF1F5F9),
                            child: Icon(Icons.add, color: Colors.blueGrey, size: 20),
                          ),
                          title: const Text('Add hidden network...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          onTap: widget.onManualEntrySelected,
                        );
                      }

                      final net = _networks[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: kAccentMint.withValues(alpha: 0.3),
                          child: Icon(
                            net.signalStrength > 75
                                ? Icons.wifi
                                : net.signalStrength > 50
                                    ? Icons.wifi_2_bar
                                    : Icons.wifi_1_bar,
                            color: kPrimaryColor,
                            size: 18,
                          ),
                        ),
                        title: Text(net.ssid, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          '${net.signalStrength}% Signal • ${net.securityType}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        trailing: net.isSecured
                            ? const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey)
                            : Chip(
                                label: const Text('Open', style: TextStyle(fontSize: 10, color: Colors.green)),
                                backgroundColor: Colors.green.shade50,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                        onTap: () => widget.onWifiSelected(net),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet that scans and lists compatible IoT devices first, letting the user pick and connect
class _IotDevicePickerBottomSheet extends StatefulWidget {
  final IotHybridConnectivityService service;
  final ValueChanged<DiscoveredBluetoothDevice> onDeviceSelected;
  final VoidCallback onScanNativeHardware;

  const _IotDevicePickerBottomSheet({
    required this.service,
    required this.onDeviceSelected,
    required this.onScanNativeHardware,
  });

  @override
  State<_IotDevicePickerBottomSheet> createState() => _IotDevicePickerBottomSheetState();
}

class _IotDevicePickerBottomSheetState extends State<_IotDevicePickerBottomSheet> {
  bool _isScanning = true;
  List<DiscoveredBluetoothDevice> _compatibleDevices = [];
  List<DiscoveredBluetoothDevice> _otherDevices = [];
  bool _showOtherDevices = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _isScanning = true);
    final all = await widget.service.scanCompatibleIotDevices();
    if (mounted) {
      setState(() {
        _compatibleDevices = all.where((d) => d.isCompatibleIotDevice).toList();
        _otherDevices = all.where((d) => !d.isCompatibleIotDevice).toList();
        _isScanning = false;
      });
    }
  }

  IconData _getCategoryIcon(DiscoveredBluetoothDevice dev) {
    if (dev.isCompatibleIotDevice) return Icons.eco_rounded;
    final lower = dev.deviceName.toLowerCase();
    if (lower.contains('headphone') ||
        lower.contains('wh-') ||
        lower.contains('buds') ||
        lower.contains('airpod') ||
        lower.contains('speaker') ||
        lower.contains('audio')) {
      return Icons.headphones_rounded;
    }
    if (lower.contains('watch') || lower.contains('band')) {
      return Icons.watch_rounded;
    }
    if (lower.contains('phone') || lower.contains('ipad') || lower.contains('pixel') || lower.contains('galaxy')) {
      return Icons.smartphone_rounded;
    }
    if (lower.contains('tv')) {
      return Icons.tv_rounded;
    }
    return Icons.devices_other_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kAccentMint.withValues(alpha: 0.3),
                  child: const Icon(Icons.bluetooth_searching, color: kPrimaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compatible IoT Probes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Select your UrbanGreen SmartPlant node to connect', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isScanning
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Rescan Devices',
                  onPressed: _isScanning ? null : _scan,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isScanning
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: kPrimaryColor),
                        SizedBox(height: 12),
                        Text('Scanning BLE channels for compatible probes...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Looking for GATT Service UUID 0xFF01', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header for Compatible Probes Section
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'COMPATIBLE IOT DEVICES (${_compatibleDevices.length} READY)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // List of Compatible Probes (Shown First!)
                      if (_compatibleDevices.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.blueGrey),
                                  SizedBox(width: 6),
                                  Text(
                                    'No active hardware detected',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ensure your ESP32 board is plugged in and powered on.\n'
                                'If testing without hardware, you can load a virtual test node:',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  widget.service.populateDemoBleDevices();
                                  _scan();
                                },
                                icon: const Icon(Icons.science_outlined, size: 14),
                                label: const Text('Load Virtual Test Node', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._compatibleDevices.map((dev) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.green.shade100,
                                  child: const Icon(Icons.eco_rounded, color: Colors.green, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dev.deviceName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '✓ Service: 0xFF01',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Signal: ${dev.rssi} dBm',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => widget.onDeviceSelected(dev),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    elevation: 0,
                                  ),
                                  child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // Physical ESP32 Hardware Probe Action
                      OutlinedButton.icon(
                        onPressed: widget.onScanNativeHardware,
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: Text(WebHardwareBridge.isWebPlatform ? 'Scan Physical ESP32 Hardware (Web Bluetooth)' : 'Probe Physical ESP32 Hardware'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Other Incompatible Peripherals (Expandable section at bottom)
                      if (_otherDevices.isNotEmpty) ...[
                        InkWell(
                          onTap: () {
                            setState(() => _showOtherDevices = !_showOtherDevices);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _showOtherDevices ? Icons.expand_less : Icons.expand_more,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Other Nearby Bluetooth Devices (${_otherDevices.length} Incompatible)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showOtherDevices) ...[
                          const SizedBox(height: 8),
                          ..._otherDevices.map((dev) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(_getCategoryIcon(dev), size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(dev.deviceName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                        Text(
                                          '✕ ${dev.compatibilityLabel}',
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Incompatible', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

