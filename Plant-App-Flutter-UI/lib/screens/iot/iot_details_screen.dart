import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../models/plant_model.dart';
import '../../services/care_log_service.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/iot_firestore_service.dart';
import '../../services/weather_service.dart';
import '../../services/plant_service.dart';
import '../../services/low_moisture_decision_service.dart';
import 'low_moisture_decision_screen.dart';
import 'iot_network_info_screen.dart';
import 'iot_setup_wizard_screen.dart';
import '../../components/iot_connection_guide_sheet.dart';
import '../../components/city_picker_sheet.dart';
import '../garden/edit_plant_screen.dart';

class IotDetailsScreen extends StatefulWidget {
  final IotDevice device;

  const IotDetailsScreen({super.key, required this.device});

  @override
  State<IotDetailsScreen> createState() => _IotDetailsScreenState();
}

class _IotDetailsScreenState extends State<IotDetailsScreen>
    with SingleTickerProviderStateMixin {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  final IotFirestoreService _firestoreService = IotFirestoreService();
  final WeatherService _weatherService = WeatherService();
  late TabController _tabController;

  // Real-time Firestore Telemetry State
  StreamSubscription<IotDevice?>? _deviceFirestoreSub;
  Timer? _telemetryTimer;
  bool _isAutoPolling = true;
  bool _isConnected = false;
  int _latencyMs = 0;
  DateTime? _lastReadingAt;
  DateTime? _lastWateredAt;

  // Real-time Local Weather
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;

  // Live Hardware Values
  int _moisturePercent = 0;
  int _rawAdc = 3200;
  bool _isPumpRunning = false;
  String _mode = 'AUTO'; // 'AUTO' or 'MANUAL'
  bool _activeHigh = true;
  final List<int> _moistureHistory = [];
  static const int _maxHistoryPoints = 30;

  // Pump stopwatch
  DateTime? _pumpStartTime;
  Timer? _stopwatchTimer;
  int _pumpElapsedSeconds = 0;

  // Configuration Panel Actions
  bool _isTestingPing = false;
  String? _pingResult;
  bool _isTestingNotification = false;

  // Wi-Fi & Network Connection State
  bool _isResettingWifi = false;

  // Hardware State Machine & Reconnect Tracking
  String? _systemState;
  String? _stateReason;
  int _reconnectAttempts = 0;

  // Central Plant Service (for strictly 1-to-1 IoT <-> Plant mapping)
  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _plantService.addListener(_onPlantServiceChanged);

    _moisturePercent = widget.device.moistureLevel?.round() ?? 0;
    _mode = widget.device.autoWaterEnabled ? 'AUTO' : 'MANUAL';
    _isConnected = widget.device.isOnline;
    _lastReadingAt = widget.device.lastReadingAt ?? widget.device.lastSeen;
    _lastWateredAt = widget.device.lastWateredAt;
    _systemState = widget.device.systemState;
    _stateReason = widget.device.stateReason;
    _reconnectAttempts = widget.device.reconnectAttempts;

    _loadWeather();
    _subscribeFirestore();
    _startPolling();
  }

  void _onPlantServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _plantService.removeListener(_onPlantServiceChanged);
    _deviceFirestoreSub?.cancel();
    _stopPolling();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    if (_isLoadingWeather) return;
    setState(() => _isLoadingWeather = true);
    try {
      final w = await _weatherService.fetchLocalWeather();
      if (mounted) {
        setState(() {
          _weatherData = w;
          _isLoadingWeather = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  void _subscribeFirestore() {
    _deviceFirestoreSub?.cancel();
    _deviceFirestoreSub = _firestoreService.streamDevice(widget.device.id).listen((device) {
      if (!mounted || device == null) return;
      _updateFromDevice(device);
    });
  }

  void _updateFromDevice(IotDevice device) {
    final int mPct = (device.moistureLevel != null)
        ? (device.moistureLevel! * 100).round()
        : _moisturePercent;
    final int raw = device.rawAdc ?? _rawAdc;
    final bool pump = device.isPumpRunning;
    final String modeStr = device.autoWaterEnabled ? 'AUTO' : 'MANUAL';

    if (pump && !_isPumpRunning) {
      _pumpStartTime = DateTime.now();
      _startStopwatch();
    } else if (!pump && _isPumpRunning) {
      _pumpStartTime = null;
      _stopwatchTimer?.cancel();
      _pumpElapsedSeconds = 0;
    }

    setState(() {
      _isConnected = device.isOnline;
      _lastReadingAt = device.lastReadingAt ?? device.lastSeen;
      _lastWateredAt = device.lastWateredAt;
      _moisturePercent = mPct;
      _rawAdc = raw;
      _isPumpRunning = pump;
      _mode = modeStr;
      _systemState = device.systemState;
      _stateReason = device.stateReason;
      _reconnectAttempts = device.reconnectAttempts;

      _moistureHistory.add(mPct);
      if (_moistureHistory.length > _maxHistoryPoints) {
        _moistureHistory.removeAt(0);
      }
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${monthNames[dt.month - 1]} ${dt.day}, $hour:$minute';
  }

  void _startPolling() {
    _stopPolling();
    _fetchTelemetry();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isAutoPolling && mounted) {
        _fetchTelemetry();
      }
    });
  }

  void _stopPolling() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  Future<void> _fetchTelemetry() async {
    final sw = Stopwatch()..start();
    _loadWeather();
    final dev = await _firestoreService.getDevice(widget.device.id);
    sw.stop();

    if (!mounted) return;

    if (dev != null) {
      _latencyMs = sw.elapsedMilliseconds;
      _updateFromDevice(dev);
    } else {
      if (_isConnected) {
        setState(() => _isConnected = false);
      }
    }
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pumpStartTime != null && mounted) {
        setState(() {
          _pumpElapsedSeconds = DateTime.now().difference(_pumpStartTime!).inSeconds;
        });
      }
    });
  }

  // Hardware Controls
  Future<void> _toggleRelayPolarity() async {
    await _service.toggleRelayInvert();
    if (mounted) {
      setState(() {
        _activeHigh = !_activeHigh;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Relay Polarity: ${_activeHigh ? "Active HIGH (3.3V)" : "Active LOW (0V)"}'),
          backgroundColor: kPrimaryColor,
        ),
      );
    }
  }

  Future<void> _runPing() async {
    setState(() {
      _isTestingPing = true;
      _pingResult = null;
    });

    final sw = Stopwatch()..start();
    final dev = await _firestoreService.getDevice(widget.device.id);
    sw.stop();

    if (mounted) {
      final isOnline = dev != null && dev.isOnline;
      setState(() {
        _isTestingPing = false;
        if (isOnline) {
          _pingResult = 'Cloud Firestore Online (${sw.elapsedMilliseconds}ms)';
        } else {
          _pingResult = 'Offline (Heartbeat timed out)';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline
              ? '✅ Device heartbeat verified in Cloud Firestore (${sw.elapsedMilliseconds}ms).'
              : '⚠️ Device is offline or has not checked in for > 2 minutes.'),
          backgroundColor: isOnline ? kStatusSuccess : kStatusWarning,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isTestingNotification = true);
    await _firestoreService.addDeviceLog(
      widget.device.id,
      title: 'Diagnostic Test Alert',
      detail: 'Manual diagnostic signal dispatched to Cloud Firestore.',
      type: IotLogType.notifying,
    );

    if (mounted) {
      setState(() => _isTestingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Diagnostic notification logged to Cloud Firestore.'),
          backgroundColor: kStatusSuccess,
        ),
      );
    }
  }

  Future<void> _unpairDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset & Unpair?'),
        content: Text(
          'This will completely wipe and unpair "${widget.device.name}":\n\n'
          '• Sends a FACTORY_RESET command to erase Wi-Fi and NVS memory on the ESP32.\n'
          '• Removes the device and telemetry from Cloud Firestore.\n'
          '• Unbinds from any linked botanical specimen.\n\n'
          'The ESP32 will reboot into a clean unconfigured state, allowing the setup cycle to repeat cleanly as usual.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wipe & Unpair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _firestoreService.factoryResetDevice(widget.device.id);
      _plantService.unassignDevice(widget.device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device wiped and removed. Ready for fresh setup.'),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _reconfigureWifi() async {
    final bool isOnline = widget.device.isOnline;
    if (isOnline) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.wifi_protected_setup_rounded, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Change Wi-Fi Network',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'To switch your ESP32 to a different Wi-Fi network or mobile hotspot:\n\n'
            '1. The app will send a remote command to reboot the ESP32 into Setup Mode (ESP32_Plant_Irrigation).\n'
            '2. The 3-Step Setup Wizard will launch immediately to guide network pairing.\n\n'
            '• Botanical logs, sensor calibrations, and linked specimen associations are kept safe.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reboot & Launch Wizard', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      // Show brief rebooting overlay/progress
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor),
                  SizedBox(height: 16),
                  Text('Rebooting ESP32 into Setup Mode...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Broadcasting "ESP32_Plant_Irrigation"', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await _firestoreService.sendResetCommand(widget.device.id);
        await Future.delayed(const Duration(milliseconds: 2000));
      } catch (_) {}

      if (mounted) Navigator.pop(context); // Close rebooting overlay
    } else {
      // Device is offline
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ESP32 Probe is Offline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'The ESP32 is currently disconnected from Cloud Firestore and cannot receive remote commands.\n\n'
            'How to switch Wi-Fi:\n'
            '1. If disconnected recently, it is already broadcasting "ESP32_Plant_Irrigation".\n'
            '2. Or press & hold the physical BOOT button on the ESP32 for 5 seconds until it restarts.\n'
            '3. Tap "Launch Setup Wizard" to connect your phone to the hotspot and save new Wi-Fi credentials.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Launch Setup Wizard', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IotSetupWizardScreen(initialDeviceId: widget.device.id),
      ),
    );

    if (updated == true && mounted) {
      final dev = await _firestoreService.getDevice(widget.device.id);
      if (dev != null && mounted) {
        setState(() {
          widget.device.isWifiConnected = dev.isWifiConnected;
          widget.device.wifiSsid = dev.wifiSsid;
          widget.device.lastSeen = dev.lastSeen;
        });
      }
      _startPolling();
    }
  }

  Future<void> _disconnectWifi() async {
    final currentSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? 'configured network';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Disconnect from Wi-Fi?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disconnect and forget "$currentSsid"?\n\n'
          '• The ESP32 will erase its saved Wi-Fi credentials in flash memory and restart into standalone setup mode (ESP32_Plant_Irrigation).\n'
          '• Your botanical specimen link, calibrations, and activity history remain saved in Cloud Firestore.\n\n'
          'Tip: To completely delete and unpair this device from your account and Firebase, use "Unpair / Forget Device" in the Danger Zone below.',
          style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect Wi-Fi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isResettingWifi = true);

    try {
      if (widget.device.isOnline) {
        await _firestoreService.sendResetCommand(widget.device.id);
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      await _service.resetDeviceWifi(widget.device.id);

      if (!mounted) return;
      setState(() {
        _isResettingWifi = false;
        widget.device.isWifiConnected = false;
        widget.device.wifiSsid = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wi-Fi disconnected. ESP32 is now in standalone setup mode.'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isResettingWifi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect Wi-Fi: $e'),
            backgroundColor: kStatusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Sensor & Watering Controls
  Future<void> _setWateringMode(String newMode) async {
    final bool targetAuto = (newMode == 'AUTO');
    if (_mode == newMode && widget.device.autoWaterEnabled == targetAuto) return;

    await _firestoreService.setWateringMode(widget.device.id, autoWaterEnabled: targetAuto);
    if (mounted) {
      setState(() {
        _mode = newMode;
        widget.device.autoWaterEnabled = targetAuto;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switched to ${targetAuto ? "Automatic Watering" : "Manual Decision"} mode via Cloud Firestore.',
          ),
          backgroundColor: kPrimaryColor,
        ),
      );
    }
  }

  Future<void> _triggerWaterPulse() async {
    await _firestoreService.triggerManualPulse(widget.device.id, durationSeconds: 3);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💧 Quick water pulse (3s) dispatched to Cloud Firestore.'),
          backgroundColor: kStatusSuccess,
        ),
      );
    }
  }

  Future<void> _togglePumpState() async {
    final nextState = !_isPumpRunning;
    await _firestoreService.setPumpState(widget.device.id, nextState);
    if (mounted) {
      setState(() {
        _isPumpRunning = nextState;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextState
                ? 'Emergency pump activated via Cloud Firestore.'
                : 'Emergency pump stopped via Cloud Firestore.',
          ),
          backgroundColor: kStatusSuccess,
        ),
      );
    }
  }

  void _togglePlantEnvironment(Plant plant) {
    final nextEnv = plant.isIndoor ? 'outdoor' : 'indoor';
    final updated = plant.copyWith(environment: nextEnv);
    _plantService.updatePlant(updated);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nextEnv == 'indoor'
            ? '🏠 Set ${plant.name} to Indoor (RainGuard bypassed)'
            : '🌿 Set ${plant.name} to Outdoor (RainGuard active)'),
        backgroundColor: kStatusSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startSmartHydrateWorkflow(Plant? plant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmartHydrateModal(
        device: widget.device,
        plant: plant,
        currentMoisture: _moisturePercent,
        firestoreService: _firestoreService,
        onMoistureUpdated: (newM) {
          if (mounted) {
            setState(() {
              _moisturePercent = newM;
              _moistureHistory.add(newM);
              if (_moistureHistory.length > _maxHistoryPoints) {
                _moistureHistory.removeAt(0);
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildMiniSpectrumIndicator(String label, String range, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            range,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Standardized Botanical Header (Uniform with Garden, Sensors & Shop)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? kDarkSurfaceColor : kAccentMint.withValues(alpha: 0.55),
                    isDark ? kDarkBackgroundColor : kBackgroundColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StandardBackButton(onPressed: () => Navigator.maybePop(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Plant Sensor 🌱',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.device.name,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _isConnected
                                        ? kStatusSuccess.withValues(alpha: 0.12)
                                        : kStatusWarning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isConnected
                                          ? kStatusSuccess.withValues(alpha: 0.3)
                                          : kStatusWarning.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isConnected ? kStatusSuccess : kStatusWarning,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isConnected ? 'ONLINE' : 'STANDBY',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _isConnected ? kStatusSuccess : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Connection Modes Guide Action Button
                      IconButton(
                        tooltip: 'IoT Hotspot vs Wi-Fi Guide',
                        icon: const Icon(Icons.help_outline_rounded, color: kPrimaryColor, size: 22),
                        onPressed: () => showIotConnectionModesGuide(context),
                      ),
                      const SizedBox(width: 4),
                      // 44x44 Circular Refresh Action matching Shop & Garden
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? kDarkCardColor : kSurfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? kDarkBorderSubtle : kBorderSubtle,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.sync_rounded, color: isDark ? kDarkTextPrimary : kTextPrimary, size: 21),
                          tooltip: 'Refresh Telemetry',
                          onPressed: _fetchTelemetry,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Capsule TabBar Container (Fits screen completely, zero overflow, no underline)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCardColor : kSurfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      dividerHeight: 0,
                      isScrollable: false,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.22),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? kDarkTextSecondary : kTextSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.eco_rounded, size: 14),
                                SizedBox(width: 4),
                                Text('Plant & Care'),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.settings_outlined, size: 14),
                                SizedBox(width: 4),
                                Text('Device & Wi-Fi'),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 14),
                                SizedBox(width: 4),
                                Text('Activity Logs'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // TabBarView Content in Expanded
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // PANEL 1: Plant & Hydration Care (Default)
                  _buildPlantAndCarePanel(),

                  // PANEL 2: Device Settings & Network (Wi-Fi & Diagnostics)
                  _buildDeviceAndWifiPanel(),

                  // PANEL 3: Real-Time Activity & Hardware Event Logs
                  _buildDeviceActivityLogsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // GRACE FALLBACK HOTSPOT & RECONNECTION BANNER
  // =========================================================================
  Widget _buildGraceHotspotBanner(bool isDark) {
    final bool isGraceHotspot = (_systemState == 'FALLBACK_HOTSPOT');
    final bool isReconnecting = (_systemState == 'RECONNECTING');

    if (!isGraceHotspot && !isReconnecting) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGraceHotspot
            ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGraceHotspot
              ? (isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B))
              : (isDark ? const Color(0xFF0284C7) : const Color(0xFF38BDF8)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGraceHotspot ? Icons.wifi_off_rounded : Icons.sync_problem_rounded,
                color: isGraceHotspot ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isGraceHotspot
                      ? 'Wi-Fi Down — Grace Hotspot Active'
                      : 'Reconnecting Wi-Fi (Attempt $_reconnectAttempts of 3)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isGraceHotspot
                        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                        : (isDark ? const Color(0xFFBAE6FD) : const Color(0xFF075985)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isGraceHotspot
                ? 'The ESP32 lost Wi-Fi after 3 reconnect retries and opened its grace setup hotspot ("ESP32_Plant_Irrigation").\n\n'
                  '• Autonomous auto-watering is STILL active on the sensor probe.\n'
                  '• The chip auto-probes the router every 60s to self-heal.\n'
                  '• To switch networks, tap Reconfigure Wi-Fi below (existing data & linked plant will NOT be lost).'
                : 'The ESP32 detected a dropped connection and is attempting to reconnect to "${widget.device.wifiSsid ?? "configured Wi-Fi"}".',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: isGraceHotspot
                  ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F))
                  : (isDark ? const Color(0xFFE0F2FE) : const Color(0xFF0C4A6E)),
            ),
          ),
          if (_stateReason != null && _stateReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Diagnostic: $_stateReason',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: isGraceHotspot
                    ? (isDark ? const Color(0xFFFDE68A).withValues(alpha: 0.8) : const Color(0xFF92400E))
                    : (isDark ? const Color(0xFFBAE6FD).withValues(alpha: 0.8) : const Color(0xFF0369A1)),
              ),
            ),
          ],
          if (isGraceHotspot) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.wifi_find_rounded, size: 16),
                label: const Text('Reconfigure Wi-Fi (Preserve Data)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _reconfigureWifi,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // PANEL 2: DEVICE SETTINGS & NETWORK (WI-FI & DIAGNOSTICS)
  // =========================================================================
  Widget _buildDeviceAndWifiPanel() {
    final isDark = context.isDarkMode;
    final stationIp = _service.savedStationIp ?? _service.targetDeviceIp;
    final homeSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? 'WenNikk-2.4Ghz';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGraceHotspotBanner(isDark),

          // 1. Device Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? kDarkCardColor : kSurfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.developer_board_rounded, color: kPrimaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.device.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? kDarkTextPrimary : kTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kStatusSuccess,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'MAIN HOST',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This phone is registered as the main host and alert receiver.',
                        style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Connect IoT to Network Card (Wi-Fi Configuration & Gateway)
          _buildNetworkConnectionCard(stationIp, homeSsid),
          const SizedBox(height: 16),

          // 3. Advanced Hardware Diagnostics & Technical Tools (Collapsible at bottom)
          _buildAdvancedHardwareAccordion(stationIp, homeSsid),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Collapsible Advanced Hardware Diagnostics at the bottom of Device & Wi-Fi tab
  Widget _buildAdvancedHardwareAccordion(String stationIp, String homeSsid) {
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.build_circle_outlined, color: Colors.blueGrey, size: 20),
          ),
          title: const Text(
            'Advanced Hardware Diagnostics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
          ),
          subtitle: const Text(
            'Ping latency, push test, hardware specs & relay settings',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          children: [
            const Divider(height: 1, color: kBorderSubtle),
            const SizedBox(height: 14),

            // Diagnostic Action Buttons
            ElevatedButton.icon(
              icon: _isTestingNotification
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Test Connection (Push Notification)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isTestingNotification ? null : _sendTestNotification,
            ),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              icon: _isTestingPing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_ping_rounded, size: 18),
              label: const Text('Ping ESP32 (Check Latency)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryColor,
                side: const BorderSide(color: kPrimaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isTestingPing ? null : _runPing,
            ),
            const SizedBox(height: 14),

            // Technical Specifications Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hardware & Network Specs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IotNetworkInfoScreen(
                                device: widget.device,
                                isConnected: _isConnected,
                                latencyMs: _latencyMs,
                              ),
                            ),
                          );
                        },
                        child: const Text('Full Specs ➔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      ),
                    ],
                  ),
                  Divider(height: 16, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(Icons.developer_board_rounded, 'Device Model', 'ESP32-WROOM-32 (Xtensa Dual-Core)'),
                  Divider(height: 14, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(Icons.cloud_done_rounded, 'Architecture', 'Pure Cloud Firestore (HTTPS)'),
                  Divider(height: 14, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(Icons.memory_rounded, 'Firmware Version', widget.device.firmwareVersion),
                  Divider(height: 14, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(Icons.wifi_rounded, 'Connected Wi-Fi', homeSsid),
                  Divider(height: 14, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(Icons.router_rounded, 'Station IP (Home LAN)', stationIp.isNotEmpty ? stationIp : 'DHCP Dynamic'),
                  Divider(height: 14, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(Icons.wifi_tethering_rounded, 'SoftAP Setup Hotspot', 'ESP32_Plant_Irrigation (192.168.4.1)'),
                  Divider(height: 14, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  _buildConfigRow(
                    Icons.speed_rounded,
                    'Ping Status',
                    _pingResult ?? (_isConnected ? 'Online (${_latencyMs}ms)' : 'Untested'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Hardware Settings (Relay Polarity & ADC Range)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware Calibration & Relay',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Relay Trigger Polarity',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? kDarkTextPrimary : kTextPrimary,
                              ),
                            ),
                            Text(
                              'Active HIGH (3.3V) vs Active LOW (0V GND)',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? kDarkTextSecondary : kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _activeHigh,
                        activeThumbColor: kPrimaryColor,
                        onChanged: (_) => _toggleRelayPolarity(),
                      ),
                    ],
                  ),
                  Divider(height: 12, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sensor Range Calibration',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                      Text(
                        'Dry: ${IotHybridConnectivityService.dryAdcValue} / Wet: ${IotHybridConnectivityService.wetAdcValue}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Danger Zone: Unpair
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: kStatusDanger, size: 18),
                label: const Text('Unpair / Forget Device', style: TextStyle(color: kStatusDanger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kStatusDanger),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _unpairDevice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Network & Cloud Connectivity Card inside Device Details
  Widget _buildNetworkConnectionCard(String stationIp, String homeSsid) {
    final isDark = context.isDarkMode;
    final bool isOnline = widget.device.isOnline;
    final bool hasWifi = widget.device.isWifiConnected &&
        widget.device.wifiSsid != null &&
        widget.device.wifiSsid!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? (isDark ? kDarkBorderSubtle : kBorderSubtle)
              : (isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isOnline ? kPrimaryColor : const Color(0xFFD97706)).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: isOnline ? kPrimaryColor : const Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Network & Cloud Connectivity',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOnline ? kStatusSuccess : const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOnline ? 'CLOUD SYNC' : 'OFFLINE',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasWifi
                          ? 'Paired to 2.4GHz Wi-Fi "$homeSsid"'
                          : 'No active Wi-Fi connection configured',
                      style: const TextStyle(fontSize: 11, color: kTextSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'IoT Hotspot vs Wi-Fi Guide',
                icon: const Icon(Icons.help_outline_rounded, size: 20, color: kPrimaryColor),
                onPressed: () => showIotConnectionModesGuide(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Network & Cloud Status Strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOnline
                  ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4))
                  : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFFFBEB)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline
                    ? (isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0))
                    : (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: isOnline ? kStatusSuccess : const Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOnline
                            ? 'Cloud Firestore Link Active (HTTPS)'
                            : 'Cloud link standby • Probe offline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isOnline
                              ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534))
                              : (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOnline)
                      Text(
                        '${_latencyMs}ms',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasWifi
                      ? 'Network: $homeSsid • IP: $stationIp'
                      : 'Setup Hotspot: ESP32_Plant_Irrigation (192.168.4.1)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline
                        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))
                        : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Information notice regarding single radio channel & 2.4GHz
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: isDark ? 0.15 : 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200.withValues(alpha: isDark ? 0.3 : 1.0)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To switch to another Wi-Fi or phone hotspot, tap Change Wi-Fi below. The ESP32 will reboot into its setup hotspot ("ESP32_Plant_Irrigation") and open the 3-step setup wizard.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Change Wi-Fi & Disconnect Wi-Fi
          Row(
            children: [
              if (hasWifi) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isResettingWifi ? null : _disconnectWifi,
                    icon: const Icon(Icons.wifi_off_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Disconnect Wi-Fi',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reconfigureWifi,
                  icon: const Icon(Icons.wifi_protected_setup_rounded, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasWifi ? 'Change Wi-Fi Network' : 'Connect to Wi-Fi Wizard',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: kPrimaryColor),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLowMoistureNotificationCard() {
    final dev = widget.device;
    final isAuto = _mode == 'AUTO' || dev.autoWaterEnabled;
    final isIgnored = dev.isLowMoistureAlertIgnored;
    final isAlways = dev.lowMoistureAlwaysIgnored;

    Color bannerColor = const Color(0xFF2E7D32);
    IconData bannerIcon = Icons.notifications_active_rounded;
    if (!dev.lowMoistureAlertEnabled) {
      bannerColor = Colors.grey.shade600;
      bannerIcon = Icons.notifications_off_outlined;
    } else if (isAlways) {
      bannerColor = Colors.red.shade700;
      bannerIcon = Icons.notifications_off_rounded;
    } else if (isIgnored) {
      bannerColor = Colors.amber.shade800;
      bannerIcon = Icons.snooze_rounded;
    }

    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isAuto
                    ? (isDark ? const Color(0xFF134E48) : Colors.teal.shade50)
                    : (isDark ? kDarkSurfaceColor : kPrimaryColor.withValues(alpha: 0.12)),
                child: Icon(
                  isAuto ? Icons.autorenew_rounded : Icons.water_drop_outlined,
                  color: isAuto ? Colors.tealAccent.shade400 : kPrimaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watering Mode & Soil Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    Text(
                      isAuto
                          ? 'Auto watering active • Decision alerts disabled'
                          : 'Manual watering active • Configure decision alerts',
                      style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAuto
                      ? (isDark ? const Color(0xFF134E48) : Colors.teal.shade100)
                      : (isDark ? const Color(0xFF451A03) : Colors.orange.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAuto ? 'AUTO' : 'MANUAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAuto
                        ? (isDark ? const Color(0xFF5EEAD4) : Colors.teal.shade900)
                        : (isDark ? const Color(0xFFFDBA74) : Colors.orange.shade900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mode Selector Strip
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceColor : kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _setWateringMode('AUTO'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isAuto ? Colors.teal.shade700 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.autorenew_rounded, size: 14, color: isAuto ? Colors.white : Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Auto Watering',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isAuto ? FontWeight.bold : FontWeight.w500,
                              color: isAuto ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _setWateringMode('MANUAL'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isAuto ? kPrimaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_outlined, size: 14, color: !isAuto ? Colors.white : Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Manual Mode',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !isAuto ? FontWeight.bold : FontWeight.w500,
                              color: !isAuto ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // CASE 1: AUTO WATERING IS ACTIVE (Doesn't apply, so hide manual alert settings!)
          if (isAuto) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0F766E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Automatic Hydration Managed by ESP32',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hardware pump automatically runs when soil moisture drops below threshold. Manual decision notifications do not apply.',
                          style: TextStyle(fontSize: 11, color: Colors.teal.shade900, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]

          // CASE 2: MANUAL MODE IS ACTIVE (Show option to enable soil notification alert!)
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable Soil Moisture Alert',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextPrimary),
              ),
              subtitle: const Text(
                'Notify when soil moisture is low so you can decide whether to water or snooze',
                style: TextStyle(fontSize: 11, color: kTextSecondary),
              ),
              value: dev.lowMoistureAlertEnabled,
              activeTrackColor: kPrimaryColor,
              onChanged: (val) {
                setState(() {
                  dev.lowMoistureAlertEnabled = val;
                });
                _service.persistDevices();
              },
            ),

            // ONLY WHEN ENABLED, THE SETTINGS BECOME VISIBLE!
            if (dev.lowMoistureAlertEnabled) ...[
              const Divider(height: 16, color: kBorderSubtle),

              // Threshold Selector
              const Text('Alert Trigger Threshold', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 2),
              Text('Alert when moisture drops below this level (Current: ${dev.lowMoistureThreshold}%)', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [15, 20, 25, 30, 35].map((val) {
                  final isSelected = dev.lowMoistureThreshold == val;
                  return ChoiceChip(
                    label: Text('< $val%'),
                    selected: isSelected,
                    selectedColor: kPrimaryColor.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? kPrimaryColor : kTextPrimary,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          dev.lowMoistureThreshold = val;
                        });
                        _firestoreService.updateThresholds(
                          widget.device.id,
                          lowThreshold: val,
                          highThreshold: dev.highMoistureThreshold,
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Current Ignore / Snooze Status Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bannerColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(bannerIcon, size: 16, color: bannerColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dev.lowMoistureIgnoreStatusText,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: bannerColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAlways
                          ? 'Alerts are muted indefinitely. You can un-mute anytime.'
                          : (isIgnored
                              ? 'Alert notifications for this probe are temporarily silenced.'
                              : 'Active. You will receive a heads-up notification whenever soil moisture drops below ${dev.lowMoistureThreshold}%.'),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (isIgnored) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  dev.resetAlertIgnore();
                                });
                                _service.persistDevices();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🔔 Low moisture alerts resumed for this IoT probe.'),
                                    backgroundColor: kPrimaryColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimaryColor,
                                side: const BorderSide(color: kPrimaryColor),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Resume Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _showDeviceIgnorePicker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey.shade800,
                              side: BorderSide(color: Colors.blueGrey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isIgnored ? 'Change Duration' : 'Ignore / Snooze Alerts',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick Preview / Test Button
              OutlinedButton.icon(
                onPressed: () {
                  final plant = PlantService().myPlants.firstWhere(
                    (p) => p.iotDeviceId == dev.id,
                    orElse: () => Plant(
                      id: 'sample',
                      name: dev.name,
                      species: 'Monitored Specimen',
                      imageUrl: 'assets/images/image_1.png',
                      iotDeviceId: dev.id,
                    ),
                  );
                  // Dispatch native notification & launch decision screen
                  LowMoistureDecisionService().dispatchLowMoistureAlert(
                    device: dev,
                    currentMoisture: 18,
                    force: true,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LowMoistureDecisionScreen(
                        device: dev,
                        plant: plant,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.touch_app_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Test Low Moisture Alert & Decision Flow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: kBorderSubtle),
          const SizedBox(height: 14),

          // Running Pump banner if on
          if (_isPumpRunning) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pump is currently ACTIVE (${_pumpElapsedSeconds}s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Dual Watering Controls: Smart Hydrate vs Quick Water (3s)
          Builder(
            builder: (ctx) {
              final Plant? assignedPlant = _plantService.getPlantForDevice(widget.device.id);
              final int targetOptimal = assignedPlant?.optimalMaxMoisture ?? 65;

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        'Smart Hydrate to Optimal ($targetOptimal%)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      onPressed: () => _startSmartHydrateWorkflow(assignedPlant),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.water_drop_outlined, size: 16),
                          label: const Text('Quick Water (3s)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: const BorderSide(color: kPrimaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _triggerWaterPulse,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(_isPumpRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16),
                          label: Text(_isPumpRunning ? 'Stop Pump' : 'Manual Override'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isPumpRunning ? kStatusDanger : Colors.grey.shade700,
                            side: BorderSide(color: _isPumpRunning ? kStatusDanger : Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _togglePumpState,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeviceIgnorePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.snooze_rounded, color: Colors.orange.shade800, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Snooze Dry Soil Notifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                        ),
                        Text(
                          'Select how long to ignore alerts for ${widget.device.name}',
                          style: const TextStyle(fontSize: 12, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildIgnoreDurationTile(
                sheetContext: sheetContext,
                icon: Icons.timer_outlined,
                title: '1 Hour',
                subtitle: 'Snooze alerts for 60 minutes',
                duration: const Duration(hours: 1),
                label: '1 hour',
                always: false,
              ),
              const SizedBox(height: 8),
              _buildIgnoreDurationTile(
                sheetContext: sheetContext,
                icon: Icons.today_outlined,
                title: '1 Day',
                subtitle: 'Silence alerts for 24 hours',
                duration: const Duration(days: 1),
                label: '1 day',
                always: false,
              ),
              const SizedBox(height: 8),
              _buildIgnoreDurationTile(
                sheetContext: sheetContext,
                icon: Icons.date_range_outlined,
                title: '1 Week',
                subtitle: 'Silence alerts for 7 full days',
                duration: const Duration(days: 7),
                label: '1 week',
                always: false,
              ),
              const SizedBox(height: 8),
              _buildIgnoreDurationTile(
                sheetContext: sheetContext,
                icon: Icons.calendar_month_outlined,
                title: '1 Month',
                subtitle: 'Silence alerts for 30 calendar days',
                duration: const Duration(days: 30),
                label: '1 month',
                always: false,
              ),
              const SizedBox(height: 8),
              _buildIgnoreDurationTile(
                sheetContext: sheetContext,
                icon: Icons.notifications_off_outlined,
                title: 'Always (Indefinite)',
                subtitle: 'Mute alerts indefinitely until un-muted here',
                duration: null,
                label: 'Always (Muted)',
                always: true,
                isDangerous: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIgnoreDurationTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String title,
    required String subtitle,
    required Duration? duration,
    required String label,
    required bool always,
    bool isDangerous = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(sheetContext);
        setState(() {
          if (always) {
            widget.device.ignoreAlertAlways();
          } else if (duration != null) {
            widget.device.ignoreAlertFor(duration);
          }
        });
        _service.persistDevices();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏸️ Low moisture alerts for "${widget.device.name}" ignored for $label.'),
            backgroundColor: Colors.blueGrey.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDangerous ? Colors.red.shade50.withValues(alpha: 0.4) : kBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDangerous ? Colors.red.shade200 : kBorderSubtle,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDangerous ? Colors.red.shade100 : Colors.blueGrey.shade100,
              child: Icon(icon, size: 18, color: isDangerous ? Colors.red.shade700 : Colors.blueGrey.shade800),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDangerous ? Colors.red.shade800 : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: isDangerous ? Colors.red.shade700 : kTextSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: isDangerous ? Colors.red.shade400 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // REAL-TIME LOCAL WEATHER WIDGET
  // =========================================================================
  Widget _buildRealTimeWeatherCard(bool isDark) {
    if (_weatherData == null && _isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? kDarkCardColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
          ),
        ),
      );
    }

    final weather = _weatherData;
    if (weather == null) return const SizedBox.shrink();

    final isRainGuard = weather.isRainGuardActive;
    final Plant? assignedPlant = _plantService.getPlantForDevice(widget.device.id);
    final bool isIndoor = assignedPlant?.isIndoor ?? false;
    final int critMin = assignedPlant?.criticalMinMoisture ?? 15;

    // Environment & RainGuard Resolution
    String guardMessage;
    Color guardBgColor;
    Color guardBorderColor;
    Color guardTextCol;
    IconData guardIcon;

    if (isIndoor) {
      guardMessage = '🏠 Indoor Specimen • RainGuard Bypassed\nSheltered from precipitation. Hydration decisions rely strictly on soil sensor telemetry.';
      guardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      guardBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
      guardTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
      guardIcon = Icons.home_rounded;
    } else if (isRainGuard) {
      if (_moisturePercent < critMin) {
        guardMessage = '🚨 Rain Expected Today • Critical Wilting Warning\nSoil is critically dry ($_moisturePercent% < $critMin%). A survival pulse is advised before rain arrives.';
        guardBgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        guardBorderColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
        guardTextCol = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        guardIcon = Icons.warning_amber_rounded;
      } else {
        guardMessage = '🌧️ Rain Expected Today • Outdoor Irrigation Paused\nSoil moisture ($_moisturePercent%) is above critical survival minimum ($critMin%). Watering held to let rain hydrate naturally.';
        guardBgColor = isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
        guardBorderColor = isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE);
        guardTextCol = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        guardIcon = Icons.beach_access_rounded;
      }
    } else {
      guardMessage = '☀️ Clear Skies • Standard Outdoor Hydration Active';
      guardBgColor = isDark ? Colors.black26 : const Color(0xFFF0FDF4);
      guardBorderColor = isDark ? const Color(0xFF14532D) : const Color(0xFFBBF7D0);
      guardTextCol = isDark ? Colors.green.shade200 : const Color(0xFF15803D);
      guardIcon = Icons.wb_sunny_rounded;
    }

    return InkWell(
      onTap: () {
        CityPickerSheet.show(
          context,
          onCitySelected: (loc) async {
            final newWeather = await _weatherService.selectCity(loc);
            if (mounted) setState(() => _weatherData = newWeather);
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? kDarkCardColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  weather.weatherIcon,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${weather.locationName} • ${weather.weatherCondition}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? kDarkTextPrimary : kTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_location_alt_rounded, size: 14, color: kPrimaryColor),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${weather.temperature.toStringAsFixed(1)}°C • ${weather.relativeHumidity}% Humidity • Rain: ${weather.rainAmount}mm (${weather.precipitationProbability}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_right_rounded, size: 18, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: guardBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: guardBorderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(guardIcon, size: 16, color: guardTextCol),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guardMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: guardTextCol,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PANEL 1: PLANT & HYDRATION CARE (PRIMARY & DEFAULT TAB)
  // =========================================================================
  Widget _buildPlantAndCarePanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Plant? assignedPlant = _plantService.getPlantForDevice(widget.device.id);
    final statusColor = _getMoistureColor(_moisturePercent, assignedPlant);
    final statusLabel = _getMoistureStatusLabel(_moisturePercent, assignedPlant);
    final int tCrit = assignedPlant?.criticalMinMoisture ?? 15;
    final int tOptMin = assignedPlant?.optimalMinMoisture ?? 28;
    final int tOptMax = assignedPlant?.optimalMaxMoisture ?? 65;
    final int tMax = assignedPlant?.overwaterMaxMoisture ?? 78;
    final bool isOutdoor = assignedPlant?.isOutdoor ?? false;
    final bool willRainToday = isOutdoor && (_weatherData?.isRainGuardActive ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGraceHotspotBanner(isDark),

          // 1. Live status banner (Friendly & reassuring)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isConnected ? kStatusSuccess.withValues(alpha: 0.1) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isConnected ? kStatusSuccess.withValues(alpha: 0.3) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? kStatusSuccess : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _systemState == 'FALLBACK_HOTSPOT'
                            ? 'Grace Hotspot Active • Auto-Watering Guardrails Online'
                            : (_isConnected ? 'Device Online • Heartbeat Active' : 'Device Offline / Standby'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _systemState == 'FALLBACK_HOTSPOT'
                              ? const Color(0xFFD97706)
                              : (_isConnected ? kStatusSuccess : const Color(0xFFB45309)),
                        ),
                      ),
                      Text(
                        _isConnected
                            ? 'Last reading: ${_formatDateTime(_lastReadingAt)}'
                            : 'Last seen: ${_formatDateTime(widget.device.lastSeen)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _isConnected ? kStatusSuccess.withValues(alpha: 0.8) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_systemState == 'FALLBACK_HOTSPOT'
                            ? const Color(0xFFD97706)
                            : (_isConnected ? kStatusSuccess : const Color(0xFFD97706)))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.device.stateDisplayLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _systemState == 'FALLBACK_HOTSPOT'
                          ? const Color(0xFFD97706)
                          : (_isConnected ? kStatusSuccess : const Color(0xFFD97706)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Real-Time Local Weather Card
          _buildRealTimeWeatherCard(isDark),
          const SizedBox(height: 16),

          // 2. Linked Specimen Card (Strict 1-to-1 Mapping) - Plant First!
          _buildAssignedPlantSection(),
          const SizedBox(height: 16),

          // 3. Soil Moisture Level Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? kDarkCardColor : kSurfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Soil Moisture Level',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Giant Moisture Value
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$_moisturePercent',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_moisturePercent / 100.0).clamp(0.0, 1.0),
                    minHeight: 14,
                    backgroundColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 12),

                // Species 4-Tier Moisture Spectrum Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildMiniSpectrumIndicator('Wilting', '<$tCrit%', const Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      _buildMiniSpectrumIndicator('Thirsty', '$tCrit-$tOptMin%', const Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      _buildMiniSpectrumIndicator('Optimal', '$tOptMin-$tOptMax%', const Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      _buildMiniSpectrumIndicator('Overwater', '>$tMax%', const Color(0xFFB91C1C)),
                    ],
                  ),
                ),

                // Dynamic Alert / Advisory Banners
                if (_moisturePercent < tCrit) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🚨 Critical Drought Alert ($_moisturePercent% < $tCrit%): Soil is critically dry! Severe risk of root desiccation and leaf wilt. Immediate hydration recommended.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_moisturePercent > tMax) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.water_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ Overwater Warning ($_moisturePercent% > $tMax%): Soil is saturated and waterlogged. Risk of root rot and oxygen deprivation. Halt all irrigation and ensure drainage.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_moisturePercent < tOptMin) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: willRainToday ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: willRainToday ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(willRainToday ? Icons.beach_access_rounded : Icons.info_outline_rounded,
                            size: 16, color: willRainToday ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            willRainToday
                                ? '🌧️ Rain Expected Today: Soil is nearing low ($_moisturePercent%), but rainfall will hydrate naturally without pump action.'
                                : '💧 Soil Running Low: Soil moisture is nearing the dry side ($_moisturePercent% < $tOptMin%). Time to water or tap Smart Hydrate.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: willRainToday ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Friendly target & power info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Target Range: $tOptMin% - $tOptMax%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          assignedPlant?.isIndoor == true ? Icons.home_rounded : Icons.park_rounded,
                          size: 13,
                          color: assignedPlant?.isIndoor == true ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignedPlant?.isIndoor == true ? 'Indoor Specimen' : 'Outdoor Specimen',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(height: 18, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Last Reading: ${_formatDateTime(_lastReadingAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.water_drop_outlined, size: 12, color: kPrimaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Last Watered: ${_formatDateTime(_lastWateredAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Watering Mode & Decision Alerts (Integrated with Quick Action buttons!)
          _buildLowMoistureNotificationCard(),
          const SizedBox(height: 16),

          // 5. Diagnostics & Sensor History (Collapsible Progressive Disclosure at bottom)
          _buildSensorDiagnosticsAccordion(statusColor),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Collapsible Sensor History & Diagnostics at the bottom of Plant & Care tab
  Widget _buildSensorDiagnosticsAccordion(Color statusColor) {
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_outlined, color: kPrimaryColor, size: 20),
          ),
          title: Text(
            'Sensor History & Diagnostics',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          subtitle: Text(
            'Moisture history, raw ADC & polling controls',
            style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
          ),
          children: [
            Divider(height: 1, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            const SizedBox(height: 12),
            if (_moistureHistory.isNotEmpty) ...[
              Text(
                'Live Moisture History (30 samples)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: CustomPaint(
                  painter: _SparklinePainter(_moistureHistory, statusColor),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raw Sensor ADC',
                  style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                ),
                Text(
                  '$_rawAdc (Range: 1100 wet - 3100 dry)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-refresh Telemetry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      Text(
                        'Continuously poll probe every 4 seconds',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isAutoPolling,
                  activeThumbColor: kPrimaryColor,
                  onChanged: (val) => setState(() => _isAutoPolling = val),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text('View Full Activity Logs Tab ➔', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: BorderSide(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _tabController.animateTo(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PANEL 3: DEVICE ACTIVITY LOGS PANEL (FIRESTORE & LOCAL SYNC)
  // =========================================================================
  Widget _buildDeviceActivityLogsPanel() {
    return StreamBuilder<List<IotActivityLog>>(
      stream: _firestoreService.streamDeviceLogs(widget.device.id),
      builder: (context, snapshot) {
        final cloudLogs = snapshot.data ?? [];
        return ValueListenableBuilder<List<IotActivityLog>>(
          valueListenable: _service.activityLogsNotifier,
          builder: (context, localLogs, _) {
            final Set<String> seen = {};
            final List<IotActivityLog> merged = [];
            for (final log in [...cloudLogs, ...localLogs]) {
              final key = '${log.title}_${log.timestamp.millisecondsSinceEpoch ~/ 1000}';
              if (!seen.contains(key)) {
                seen.add(key);
                merged.add(log);
              }
            }
            merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            final deviceLogs = merged.where((l) {
              if (l.deviceId == widget.device.id) return true;
              if (l.deviceId == 'SmartPlant-ESP32' && widget.device.id == _service.registeredDeviceId) return true;
              return merged.length <= 3;
            }).toList();

            if (deviceLogs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, size: 44, color: kPrimaryColor),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Logs for This Device Yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Real-time sensing, auto-watering cycles, and push notifications for this IoT unit will appear here automatically as they occur.',
                        style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(kDefaultPadding),
              itemCount: deviceLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final log = deviceLogs[idx];
                final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: log.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(log.icon, size: 17, color: log.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    log.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(timeStr, style: const TextStyle(fontSize: 10, color: kTextSecondary)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(log.detail, style: const TextStyle(fontSize: 11, color: kTextSecondary, height: 1.3)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: log.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    log.categoryLabel.toUpperCase(),
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: log.color, letterSpacing: 0.4),
                                  ),
                                ),
                                if (log.durationSeconds != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      '⏱️ ${log.durationSeconds}s duration',
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ASSIGNED PLANT & SPECIMEN LINKING (STRICT 1-TO-1 MAPPING)
  // =========================================================================
  Widget _buildAssignedPlantSection() {
    final isDark = context.isDarkMode;
    final Plant? assignedPlant = _plantService.getPlantForDevice(widget.device.id);

    if (assignedPlant == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? kDarkCardColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.yard_outlined, color: isDark ? kDarkTextSecondary : Colors.grey, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Specimen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No plant linked to this probe',
                        style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Unassigned',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? kDarkTextSecondary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Link this IoT sensor to a specimen in your garden to track live hydration telemetry and automate watering routines.',
              style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Assign Plant to this Sensor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showPlantAssignmentModal,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: kPrimaryColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assigned Specimen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _togglePlantEnvironment(assignedPlant),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: assignedPlant.isIndoor
                        ? const Color(0xFF1E3A8A).withValues(alpha: isDark ? 0.35 : 0.12)
                        : const Color(0xFF14532D).withValues(alpha: isDark ? 0.35 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: assignedPlant.isIndoor ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        assignedPlant.isIndoor ? Icons.home_rounded : Icons.park_rounded,
                        size: 13,
                        color: assignedPlant.isIndoor ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        assignedPlant.isIndoor ? 'Indoor' : 'Outdoor',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: assignedPlant.isIndoor
                              ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                              : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 12,
                        color: assignedPlant.isIndoor ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPlantThumbnail(assignedPlant.imageUrl, size: 54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignedPlant.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignedPlant.species,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceColor : kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Target Optimal Hydration: ',
                      style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                    ),
                    Text(
                      '${assignedPlant.optimalMinMoisture}% - ${assignedPlant.optimalMaxMoisture}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Critical Wilting / Overwater: ',
                      style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                    ),
                    Text(
                      '<${assignedPlant.criticalMinMoisture}% | >${assignedPlant.overwaterMaxMoisture}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade300 : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  assignedPlant.isIndoor
                      ? '🏠 Indoor: Sheltered from rain. RainGuard bypassed.'
                      : '🌿 Outdoor: RainGuard active. Automatically holds watering if rain is forecast today.',
                  style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Change'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showPlantAssignmentModal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Plant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<Plant>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPlantScreen(plant: assignedPlant),
                      ),
                    );
                    if (updated != null && mounted) {
                      _plantService.updatePlant(updated);
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_off_rounded, size: 16, color: kStatusDanger),
                  label: const Text('Unlink', style: TextStyle(color: kStatusDanger)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kStatusDanger.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmUnlinkPlant(assignedPlant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPlantAssignmentModal() {
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final plants = _plantService.myPlants;
        final currentAssignedPlant = _plantService.getPlantForDevice(widget.device.id);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? kDarkSurfaceColor : kSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? kDarkBorderSubtle : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.link_rounded, color: kPrimaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Specimen to Probe',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          Text(
                            'Probe: ${widget.device.name} (Strict 1-to-1 link)',
                            style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? kDarkTextPrimary : null),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? kDarkBorderSubtle : null),
              if (plants.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No plants found in your garden. Add a plant from the Garden tab first!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? kDarkTextSecondary : kTextSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: plants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final plant = plants[idx];
                      final isCurrent = plant.id == currentAssignedPlant?.id;
                      final isAssignedToOther = plant.iotDeviceId != null &&
                          plant.iotDeviceId!.isNotEmpty &&
                          plant.iotDeviceId != widget.device.id;

                      return Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? kPrimaryColor.withValues(alpha: 0.08)
                              : (isDark ? kDarkCardColor : kBackgroundColor),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? kPrimaryColor
                                : (isAssignedToOther
                                    ? Colors.orange.shade300
                                    : (isDark ? kDarkBorderSubtle : kBorderSubtle)),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildPlantThumbnail(plant.imageUrl, size: 44),
                          ),
                          title: Text(
                            plant.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plant.species,
                                style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                              ),
                              const SizedBox(height: 2),
                              if (isCurrent)
                                const Text(
                                  '✓ Currently assigned to this probe',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                )
                              else if (isAssignedToOther)
                                Text(
                                  '⚠️ Linked to probe: ${plant.iotDeviceId}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                )
                              else
                                const Text(
                                  'Ready to pair (Available)',
                                  style: TextStyle(fontSize: 11, color: Colors.green),
                                ),
                            ],
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.check_circle, color: kPrimaryColor)
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            if (isCurrent) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${plant.name} is already assigned to this probe.')),
                              );
                              return;
                            }

                            if (isAssignedToOther) {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dlgContext) => AlertDialog(
                                  title: const Text('Reassign Probe?'),
                                  content: Text(
                                    '${plant.name} is currently monitored by probe "${plant.iotDeviceId}". '
                                    'Reassigning it will transfer monitoring to "${widget.device.name}". '
                                    'Each plant can only be assigned to one probe. Proceed?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dlgContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                                      onPressed: () => Navigator.pop(dlgContext, true),
                                      child: const Text('Reassign', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                            }

                            _plantService.assignDeviceToPlant(
                              plantId: plant.id,
                              deviceId: widget.device.id,
                            );
                            _firestoreService.linkPlant(
                              widget.device.id,
                              plantId: plant.id,
                              plantName: plant.name,
                              plantImage: plant.imageUrl,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🌿 Successfully assigned ${plant.name} to ${widget.device.name}!'),
                                  backgroundColor: kPrimaryColor,
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmUnlinkPlant(Plant plant) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: const Text('Unlink Specimen?'),
        content: Text(
          'Are you sure you want to unlink ${plant.name} from ${widget.device.name}? '
          'This probe will become unassigned and available for any other plant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger),
            onPressed: () {
              Navigator.pop(dlgContext);
              _plantService.unassignDevice(widget.device.id);
              _firestoreService.unlinkPlant(widget.device.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unlinked ${plant.name} from probe.'),
                    backgroundColor: Colors.black87,
                  ),
                );
              }
            },
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantThumbnail(String imageUrl, {double size = 44}) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _plantPlaceholder(size),
      );
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _plantPlaceholder(size),
      );
    } else {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _plantPlaceholder(size),
        );
      }
      return _plantPlaceholder(size);
    }
  }

  Widget _plantPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: kPrimaryColor.withValues(alpha: 0.1),
      child: Icon(Icons.eco_rounded, color: kPrimaryColor, size: size * 0.5),
    );
  }

  // Helpers calibrated with botanical species & 4-tier moisture spectrum
  Color _getMoistureColor(int moisture, [Plant? plant]) {
    final p = plant ?? _plantService.getPlantForDevice(widget.device.id);
    final tCrit = p?.criticalMinMoisture ?? 15;
    final tOptMin = p?.optimalMinMoisture ?? 28;
    final tOptMax = p?.optimalMaxMoisture ?? 65;
    final tMax = p?.overwaterMaxMoisture ?? 78;

    if (moisture < tCrit) return const Color(0xFFDC2626); // Critical Drought - Red
    if (moisture < tOptMin) return const Color(0xFFD97706); // Thirsty/Dry - Amber
    if (moisture <= tOptMax) return kStatusSuccess; // Optimal - Green
    if (moisture <= tMax) return const Color(0xFF0284C7); // Well Hydrated - Blue
    return const Color(0xFFB91C1C); // Overwatered / Saturated - Deep Red
  }

  String _getMoistureStatusLabel(int moisture, [Plant? plant]) {
    final p = plant ?? _plantService.getPlantForDevice(widget.device.id);
    final tCrit = p?.criticalMinMoisture ?? 15;
    final tOptMin = p?.optimalMinMoisture ?? 28;
    final tOptMax = p?.optimalMaxMoisture ?? 65;
    final tMax = p?.overwaterMaxMoisture ?? 78;
    final isRainExpected = (p == null || p.isOutdoor) && (_weatherData?.isRainGuardActive == true);

    if (moisture < tCrit) return 'Critical Drought ⚠️';
    if (moisture < tOptMin) {
      return isRainExpected ? 'Thirsty (Rain Expected)' : 'Soil Low (Due for Water)';
    }
    if (moisture <= tOptMax) return 'Optimal Hydration';
    if (moisture <= tMax) return 'Well Hydrated';
    return '⚠️ Overwatered';
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final double normalizedY = 1.0 - (values[i] / 100.0).clamp(0.0, 1.0);
      final double x = i * stepX;
      final double y = normalizedY * (size.height - 8) + 4;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values.length != values.length ||
        (values.isNotEmpty && oldDelegate.values.isNotEmpty && oldDelegate.values.last != values.last);
  }
}

// ===========================================================================
// SMART HYDRATE TO OPTIMAL MODAL (PULSE-AND-SOAK CLOSED LOOP WORKFLOW)
// ===========================================================================
class _SmartHydrateModal extends StatefulWidget {
  final IotDevice device;
  final Plant? plant;
  final int currentMoisture;
  final IotFirestoreService firestoreService;
  final ValueChanged<int> onMoistureUpdated;

  const _SmartHydrateModal({
    required this.device,
    required this.plant,
    required this.currentMoisture,
    required this.firestoreService,
    required this.onMoistureUpdated,
  });

  @override
  State<_SmartHydrateModal> createState() => _SmartHydrateModalState();
}

class _SmartHydrateModalState extends State<_SmartHydrateModal> {
  late int _moisture;
  late int _targetMoisture;
  late int _optMinMoisture;
  late int _critMinMoisture;
  late int _overwaterMax;

  int _cycle = 0;
  final int _maxCycles = 3;
  bool _isRunning = false;
  String _phase = 'idle'; // 'idle', 'already_optimal', 'pulsing', 'soaking', 'completed', 'aborted'
  int _soakSecondsRemaining = 10;
  Timer? _soakTimer;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _moisture = widget.currentMoisture;
    _targetMoisture = widget.plant?.optimalMaxMoisture ?? 65;
    _optMinMoisture = widget.plant?.optimalMinMoisture ?? 30;
    _critMinMoisture = widget.plant?.criticalMinMoisture ?? 15;
    _overwaterMax = widget.plant?.overwaterMaxMoisture ?? 78;

    if (_moisture >= _targetMoisture) {
      _phase = 'already_optimal';
      _statusMessage =
          'Soil moisture is currently at $_moisture%, which satisfies or exceeds the optimal target ($_targetMoisture%). Additional watering is not needed to prevent root saturation.';
    } else {
      _statusMessage =
          'Soil moisture is at $_moisture% (Optimal target is $_targetMoisture%). Water will be applied using the Pulse-and-Soak protocol: 3-second gentle pulses followed by a 10-second soak window.';
    }
  }

  @override
  void dispose() {
    _soakTimer?.cancel();
    super.dispose();
  }

  Future<void> _startHydration() async {
    setState(() {
      _isRunning = true;
      _cycle = 1;
      _phase = 'pulsing';
      _statusMessage = 'Cycle 1/$_maxCycles: Dispatched 3-second hardware pulse...';
    });

    await _executeCycle();
  }

  Future<void> _executeCycle() async {
    if (!mounted || !_isRunning) return;

    setState(() {
      _phase = 'pulsing';
      _statusMessage = 'Cycle $_cycle/$_maxCycles: Actuating hardware pump (3s pulse)...';
    });

    try {
      await widget.firestoreService.triggerManualPulse(widget.device.id, durationSeconds: 3);
    } catch (e) {
      debugPrint('Pulse trigger error: $e');
    }

    if (!mounted || !_isRunning) return;

    // Start 10-second soak interval
    setState(() {
      _phase = 'soaking';
      _soakSecondsRemaining = 10;
      _statusMessage = 'Cycle $_cycle/$_maxCycles: Root zone percolation & diffusion (10s soak)...';
    });

    _soakTimer?.cancel();
    _soakTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_soakSecondsRemaining > 1) {
        setState(() {
          _soakSecondsRemaining--;
        });
      } else {
        timer.cancel();
        await _evaluateTelemetry();
      }
    });
  }

  Future<void> _evaluateTelemetry() async {
    if (!mounted || !_isRunning) return;

    setState(() {
      _phase = 'evaluating';
      _statusMessage = 'Fetching updated soil probe telemetry...';
    });

    // Refresh telemetry from Firestore
    final updatedDev = await widget.firestoreService.getDevice(widget.device.id);
    if (updatedDev?.moistureLevel != null) {
      final newM = (updatedDev!.moistureLevel! * 100).round();
      setState(() {
        _moisture = newM;
      });
      widget.onMoistureUpdated(newM);
    }

    if (!mounted) return;

    // Check target reached
    if (_moisture >= _targetMoisture) {
      _finalizeHydration(
        summary: '🎉 Target reached! Soil moisture is now at $_moisture% (Optimal: $_targetMoisture%).',
      );
      return;
    }

    // Check safety cap
    if (_cycle >= _maxCycles) {
      _finalizeHydration(
        summary: 'Safety cap reached (3 pulses completed). Current moisture is $_moisture%. Allowed soil time to absorb before further irrigation.',
      );
      return;
    }

    // Continue to next cycle
    setState(() {
      _cycle++;
    });
    await _executeCycle();
  }

  void _finalizeHydration({required String summary}) {
    _soakTimer?.cancel();
    setState(() {
      _isRunning = false;
      _phase = 'completed';
      _statusMessage = summary;
    });

    if (widget.plant != null) {
      CareLogService().logWatering(
        plantId: widget.plant!.id,
        plantName: widget.plant!.name,
        species: widget.plant!.species,
        imageUrl: widget.plant!.imageUrl,
        amountMl: _cycle * 75,
        careMode: 'Smart Hydrate to Optimal (Pulse-and-Soak)',
        moistureBefore: widget.currentMoisture,
        moistureAfter: _moisture,
        notes: summary,
      );

      final updatedPlant = widget.plant!.copyWith(lastWatered: DateTime.now());
      PlantService().updatePlant(updatedPlant);
    }
  }

  void _abortHydration() {
    _soakTimer?.cancel();
    setState(() {
      _isRunning = false;
      _phase = 'aborted';
      _statusMessage = 'Hydration stopped by user. Current moisture is $_moisture%.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plantName = widget.plant?.name ?? widget.device.name;
    final species = widget.plant?.species ?? 'Botanical Specimen';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
                  child: const Icon(Icons.auto_awesome_rounded, color: kPrimaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart Hydrate to Optimal',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$plantName • $species',
                        style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _soakTimer?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Moisture Comparison & Range Gauge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Current Moisture', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '$_moisture%',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _moisture >= _targetMoisture
                                  ? const Color(0xFF16A34A)
                                  : (_moisture < _critMinMoisture ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 36, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('Target Hydration', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '$_targetMoisture%',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Dual Progress Bar showing Target Marker
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_moisture / 100.0).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _moisture >= _targetMoisture ? const Color(0xFF16A34A) : kPrimaryColor,
                          ),
                        ),
                      ),
                      // Target Line Marker
                      Positioned(
                        left: (_targetMoisture / 100.0) * (MediaQuery.of(context).size.width - 72),
                        child: Container(
                          width: 2,
                          height: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Critical Wilting: <$_critMinMoisture%',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626)),
                      ),
                      Text(
                        'Target: $_optMinMoisture% - $_targetMoisture%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                      Text(
                        'Max: >$_overwaterMax%',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Phase Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _phase == 'completed' || _phase == 'already_optimal'
                    ? const Color(0xFFF0FDF4)
                    : (_phase == 'soaking' ? const Color(0xFFEFF6FF) : (isDark ? kDarkSurfaceColor : kBackgroundColor)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _phase == 'completed' || _phase == 'already_optimal'
                      ? const Color(0xFFBBF7D0)
                      : (_phase == 'soaking' ? const Color(0xFFBFDBFE) : (isDark ? kDarkBorderSubtle : kBorderSubtle)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_phase == 'soaking')
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _soakSecondsRemaining / 10.0,
                            strokeWidth: 3,
                            color: const Color(0xFF2563EB),
                            backgroundColor: Colors.blue.shade100,
                          ),
                          Text(
                            '$_soakSecondsRemaining',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                        ],
                      ),
                    )
                  else if (_phase == 'pulsing')
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimaryColor),
                    )
                  else if (_phase == 'completed' || _phase == 'already_optimal')
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24)
                  else
                    const Icon(Icons.info_outline_rounded, color: kPrimaryColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _phase == 'soaking'
                              ? 'Pulse-and-Soak Absorption'
                              : (_phase == 'pulsing'
                                  ? 'Actuating Hardware Pump'
                                  : (_phase == 'completed'
                                      ? 'Hydration Complete'
                                      : (_phase == 'already_optimal' ? 'Healthy Hydration' : 'Pulse-and-Soak Protocol'))),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _phase == 'completed' || _phase == 'already_optimal'
                                ? const Color(0xFF15803D)
                                : (_phase == 'soaking' ? const Color(0xFF1D4ED8) : (isDark ? kDarkTextPrimary : kTextPrimary)),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bottom Action Button
            if (_isRunning)
              ElevatedButton.icon(
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop Hydration', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kStatusDanger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _abortHydration,
              )
            else if (_phase == 'completed' || _phase == 'already_optimal')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.water_drop_outlined, size: 16),
                      label: const Text('Force Pulse (3s)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await widget.firestoreService.triggerManualPulse(widget.device.id, durationSeconds: 3);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('💧 Quick 3s water pulse dispatched.')),
                          );
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.water_drop_rounded, size: 18),
                label: Text(
                  'Begin Smart Hydration ($_moisture% → $_targetMoisture%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _startHydration,
              ),
          ],
        ),
      ),
    );
  }
}
