import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_connection_mode.dart';
import '../../models/iot_device_model.dart';
import '../../models/plant_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/plant_service.dart';
import '../../services/low_moisture_decision_service.dart';
import 'low_moisture_decision_screen.dart';
import 'iot_network_info_screen.dart';
import 'iot_setup_wizard_screen.dart';
import '../../components/iot_connection_guide_sheet.dart';

class IotDetailsScreen extends StatefulWidget {
  final IotDevice device;

  const IotDetailsScreen({super.key, required this.device});

  @override
  State<IotDetailsScreen> createState() => _IotDetailsScreenState();
}

class _IotDetailsScreenState extends State<IotDetailsScreen>
    with SingleTickerProviderStateMixin {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  late TabController _tabController;

  // Real-time Telemetry State
  Timer? _telemetryTimer;
  bool _isAutoPolling = true;
  bool _isConnected = false;
  int _latencyMs = 0;
  DateTime? _lastPollTime;

  // Live Hardware Values
  int _moisturePercent = 0;
  int _rawAdc = 3200;
  bool _isPumpRunning = false;
  String _mode = 'AUTO'; // 'AUTO' or 'MANUAL'
  bool _activeHigh = true;
  final List<int> _moistureHistory = [];
  final List<String> _eventLogs = [];
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
  late TextEditingController _wifiSsidController;
  late TextEditingController _wifiPassController;
  bool _obscureWifiPass = true;
  bool _isScanningWifi = false;
  List<WifiNetwork> _nearbyWifiNetworks = [];
  bool _isProvisioningWifi = false;
  bool _isResettingWifi = false;
  bool _showWifiForm = false;

  // Central Plant Service (for strictly 1-to-1 IoT <-> Plant mapping)
  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _plantService.addListener(_onPlantServiceChanged);

    _moisturePercent = widget.device.moistureLevel?.round() ?? 0;
    _mode = widget.device.autoWaterEnabled ? 'AUTO' : 'MANUAL';

    final initialSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? '';
    _wifiSsidController = TextEditingController(text: initialSsid);
    _wifiPassController = TextEditingController();
    _showWifiForm = !widget.device.isWifiConnected || widget.device.wifiSsid == null || widget.device.wifiSsid!.isEmpty;

    _startPolling();
  }

  void _onPlantServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _plantService.removeListener(_onPlantServiceChanged);
    _stopPolling();
    _stopwatchTimer?.cancel();
    _wifiSsidController.dispose();
    _wifiPassController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    _fetchTelemetry();
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
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
    final data = await _service.fetchLiveHardwareTelemetry();
    sw.stop();

    if (!mounted) return;

    if (data != null) {
      final int mPct = (data['moisture'] is num) ? (data['moisture'] as num).toInt() : 0;
      final int raw = (data['raw'] is num) ? (data['raw'] as num).toInt() : 3200;
      final bool pump = data['pump'] == 1 || data['pump'] == true;
      final String modeStr = (data['mode'] ?? 'AUTO').toString().toUpperCase();
      final bool actHigh = data['activeHigh'] == 1 || data['activeHigh'] == true;
      final String msg = (data['msg'] ?? '').toString();

      // Track pump duration
      if (pump && !_isPumpRunning) {
        _pumpStartTime = DateTime.now();
        _startStopwatch();
      } else if (!pump && _isPumpRunning) {
        _pumpStartTime = null;
        _stopwatchTimer?.cancel();
        _pumpElapsedSeconds = 0;
      }

      setState(() {
        _isConnected = true;
        _latencyMs = sw.elapsedMilliseconds;
        _lastPollTime = DateTime.now();
        _moisturePercent = mPct;
        _rawAdc = raw;
        _isPumpRunning = pump;
        _mode = modeStr;
        _activeHigh = actHigh;

        if (msg.isNotEmpty && (_eventLogs.isEmpty || _eventLogs.first != msg)) {
          _eventLogs.insert(0, msg);
          if (_eventLogs.length > 20) _eventLogs.removeLast();
        }

        _moistureHistory.add(mPct);
        if (_moistureHistory.length > _maxHistoryPoints) {
          _moistureHistory.removeAt(0);
        }
      });
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

    final targetIp = _service.savedStationIp ?? _service.targetDeviceIp;
    final res = await _service.testHardwarePing(targetIp);

    if (mounted) {
      setState(() {
        _isTestingPing = false;
        if (res.isSuccess) {
          final isCloud = res.data?['isCloud'] == true;
          final ms = res.data?['latencyMs'] ?? 25;
          _pingResult = isCloud ? 'Cloud Online (${ms}ms)' : 'Local Online (${ms}ms)';
        } else {
          _pingResult = 'Offline / Unreachable';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? kStatusSuccess : kStatusDanger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isTestingNotification = true);
    final res = await _service.testConnectionAndNotify(
      customMessage: 'Device Alert: ${widget.device.name} test signal received!',
    );

    if (mounted) {
      setState(() => _isTestingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? kStatusSuccess : kStatusDanger,
        ),
      );
    }
  }

  Future<void> _unpairDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair IoT Device?'),
        content: Text(
          'Are you sure you want to remove "${widget.device.name}" from this phone? This phone will no longer act as the main host for alerts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unpair Device'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _service.unregisterDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device unpaired successfully.')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _reconfigureWifi() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const IotSetupWizardScreen()),
    );
    if (updated == true && mounted) {
      final dev = _service.connectedIotDevices.firstWhere(
        (d) => d.id == widget.device.id,
        orElse: () => widget.device,
      );
      setState(() {
        widget.device.isWifiConnected = dev.isWifiConnected;
        widget.device.wifiSsid = dev.wifiSsid;
      });
      if (!widget.device.isWifiConnected) {
        // If Wi-Fi was deleted, navigate back to main IoT page as requested
        Navigator.pop(context, true);
        return;
      }
      _startPolling();
    }
  }

  Future<void> _scanNearbyWifi() async {
    setState(() => _isScanningWifi = true);
    try {
      final networks = await _service.scanNearbyWifiNetworks();
      if (mounted) {
        // Filter out already connected Wi-Fi, empty SSIDs, and deduplicate
        final currentSsid = (widget.device.wifiSsid ?? _service.registeredHomeSsid ?? '').trim().toLowerCase();
        final seen = <String>{};
        final filtered = <WifiNetwork>[];

        for (final net in networks) {
          final clean = net.ssid.trim();
          if (clean.isNotEmpty && clean.toLowerCase() != currentSsid && !seen.contains(clean.toLowerCase())) {
            seen.add(clean.toLowerCase());
            filtered.add(net);
          }
        }

        setState(() {
          _nearbyWifiNetworks = filtered;
          _isScanningWifi = false;
        });

        if (filtered.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No other surrounding 2.4GHz Wi-Fi found. (For iPhone Hotspot, ensure "Maximize Compatibility" is ON in iOS Settings).'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isScanningWifi = false);
    }
  }

  Future<void> _connectDeviceToWifi() async {
    final ssid = _wifiSsidController.text.trim();
    final pass = _wifiPassController.text.trim();

    final validation = IotHybridConnectivityService.validateWifiCredentials(ssid, pass);
    if (!validation.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.message),
          backgroundColor: kStatusDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProvisioningWifi = true);

    final res = await _service.provisionDeviceWifi(
      deviceId: widget.device.id,
      wifiSsid: ssid,
      wifiPassword: pass,
    );

    if (mounted) {
      setState(() {
        _isProvisioningWifi = false;
        if (res.isSuccess) {
          widget.device.wifiSsid = ssid;
          widget.device.isWifiConnected = true;
          _showWifiForm = false;
          _service.connectIotDevice(widget.device);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? kStatusSuccess : kStatusDanger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      if (res.isSuccess) {
        _startPolling();
      }
    }
  }

  Future<void> _removeWifiNetwork({bool andReAdd = false}) async {
    final currentSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? 'configured network';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              andReAdd ? Icons.wifi_protected_setup_rounded : Icons.delete_outline_rounded,
              color: andReAdd ? kPrimaryColor : const Color(0xFFDC2626),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                andReAdd ? 'Delete & Reconfigure Wi-Fi?' : 'Delete Wi-Fi Network?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          andReAdd
              ? 'This will delete "$currentSsid" from the ESP32 first so its 2.4GHz radio is completely unencumbered to scan and connect to your new Wi-Fi or Hotspot.'
              : 'Are you sure you want to delete and forget the Wi-Fi network "$currentSsid"? The ESP32 will disconnect, return to standalone SoftAP mode ("ESP32-Setup" at 192.168.4.1), and you will return to the IoT Devices screen.',
          style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: andReAdd ? kPrimaryColor : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(andReAdd ? 'Delete & Reconfigure' : 'Delete Wi-Fi', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isResettingWifi = true);

    try {
      final res = await _service.resetDeviceWifi(widget.device.id);
      if (!mounted) return;

      setState(() {
        _isResettingWifi = false;
        widget.device.isWifiConnected = false;
        widget.device.wifiSsid = null;
        _wifiSsidController.clear();
        _wifiPassController.clear();
        _nearbyWifiNetworks = [];
        _showWifiForm = andReAdd;
      });

      _service.connectIotDevice(widget.device);

      if (andReAdd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Previous Wi-Fi deleted! Scanning for surrounding 2.4GHz networks...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        _scanNearbyWifi();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Wi-Fi network deleted from ESP32.'),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true); // Go back to main IoT page as requested
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResettingWifi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete Wi-Fi: $e'),
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

    final res = await _service.setWateringMode(targetAuto);
    if (mounted) {
      setState(() {
        _mode = newMode;
        widget.device.autoWaterEnabled = targetAuto;
      });
      _service.persistDevices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message
              : 'Switched to ${targetAuto ? "Automatic Watering" : "Manual Decision"} mode.'),
          backgroundColor: res.isSuccess ? kPrimaryColor : Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> _triggerWaterPulse() async {
    final res = await _service.pulseWaterSeconds(3);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? kStatusSuccess : kStatusDanger,
        ),
      );
    }
  }

  Future<void> _togglePumpState() async {
    final nextState = !_isPumpRunning;
    final res = await _service.setPumpState(nextState);
    if (mounted) {
      setState(() {
        _isPumpRunning = nextState;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? kStatusSuccess : kStatusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
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
                    kAccentMint.withValues(alpha: 0.55),
                    kBackgroundColor,
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
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.device.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: kTextPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _service.isRealHardwareConnected
                                        ? kStatusSuccess.withValues(alpha: 0.12)
                                        : kStatusWarning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _service.isRealHardwareConnected
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
                                          color: _service.isRealHardwareConnected ? kStatusSuccess : kStatusWarning,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _service.isRealHardwareConnected ? 'LIVE' : 'Wi-Fi',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _service.isRealHardwareConnected ? kStatusSuccess : const Color(0xFFB45309),
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
                          color: kSurfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: kBorderSubtle, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.sync_rounded, color: kTextPrimary, size: 21),
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
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
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
                      unselectedLabelColor: kTextSecondary,
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
  // PANEL 2: DEVICE SETTINGS & NETWORK (WI-FI & DIAGNOSTICS)
  // =========================================================================
  Widget _buildDeviceAndWifiPanel() {
    final stationIp = _service.savedStationIp ?? _service.targetDeviceIp;
    final homeSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? 'WenNikk-2.4Ghz';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Device Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderSubtle),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
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
                      const Text(
                        'This phone is registered as the main host and alert receiver.',
                        style: TextStyle(fontSize: 11, color: kTextSecondary),
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
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
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
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hardware & Network Specs',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextPrimary),
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
                  const Divider(height: 16, color: kBorderSubtle),
                  _buildConfigRow(Icons.developer_board_rounded, 'Device Model', 'ESP32-WROOM-32 (Xtensa Dual-Core)'),
                  const Divider(height: 14, color: kBorderSubtle),
                  _buildConfigRow(Icons.memory_rounded, 'Firmware Version', widget.device.firmwareVersion),
                  const Divider(height: 14, color: kBorderSubtle),
                  _buildConfigRow(Icons.wifi_rounded, 'Connected Wi-Fi', homeSsid),
                  const Divider(height: 14, color: kBorderSubtle),
                  _buildConfigRow(Icons.router_rounded, 'Station IP (Home LAN)', stationIp),
                  const Divider(height: 14, color: kBorderSubtle),
                  _buildConfigRow(Icons.wifi_tethering_rounded, 'SoftAP Gateway', '192.168.4.1'),
                  const Divider(height: 14, color: kBorderSubtle),
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
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hardware Calibration & Relay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Relay Trigger Polarity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary)),
                            Text('Active HIGH (3.3V) vs Active LOW (0V GND)', style: TextStyle(fontSize: 10.5, color: kTextSecondary)),
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
                  const Divider(height: 12, color: kBorderSubtle),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sensor Range Calibration', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                      Text(
                        'Dry: ${IotHybridConnectivityService.dryAdcValue} / Wet: ${IotHybridConnectivityService.wetAdcValue}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextPrimary),
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

  /// Connect IoT to Network & Wi-Fi Configuration Card inside Device Details
  Widget _buildNetworkConnectionCard(String stationIp, String homeSsid) {
    final bool hasWifi = widget.device.isWifiConnected &&
        widget.device.wifiSsid != null &&
        widget.device.wifiSsid!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasWifi ? kBorderSubtle : const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: (hasWifi ? kPrimaryColor : const Color(0xFFD97706)).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasWifi ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: hasWifi ? kPrimaryColor : const Color(0xFFD97706),
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
                            'Connect IoT to Network',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasWifi ? kStatusSuccess : const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasWifi ? 'CONNECTED' : 'SETUP REQUIRED',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasWifi
                          ? 'Linked to "$homeSsid" at $stationIp'
                          : 'Probe is in SoftAP setup mode (192.168.4.1)',
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

          // If connected, show status strip with reconfigure toggle & surrounding networks scan
          if (hasWifi && !_showWifiForm) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: kStatusSuccess, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direct LAN link active on "$homeSsid"',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_latencyMs}ms',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assigned Station IP: $stationIp • Gateway: 192.168.4.1',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Information notice regarding single radio channel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To switch to another Wi-Fi or mobile hotspot, remove this network first so the ESP32 radio can scan cleanly without frequency disruption.',
                      style: TextStyle(fontSize: 10.5, color: Colors.blue.shade900, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isResettingWifi ? null : () => _removeWifiNetwork(andReAdd: false),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Delete Wi-Fi',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _reconfigureWifi,
                    icon: const Icon(Icons.wifi_protected_setup_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Change Wi-Fi (3-Step Setup)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Wi-Fi Setup / Connection Form
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Wi-Fi Network Credentials',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary),
                      ),
                      if (hasWifi)
                        InkWell(
                          onTap: () => setState(() => _showWifiForm = false),
                          child: const Text('Cancel', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Scan Nearby Networks Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isScanningWifi ? null : _scanNearbyWifi,
                      icon: _isScanningWifi
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_find_rounded, size: 16),
                      label: Text(_isScanningWifi ? 'Scanning 2.4GHz Networks...' : 'Scan Nearby 2.4GHz Wi-Fi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),

                  // Scanned Chips
                  if (_nearbyWifiNetworks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _nearbyWifiNetworks.take(6).map((net) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(net.ssid, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey.shade300),
                              onPressed: () {
                                setState(() {
                                  _wifiSsidController.text = net.ssid;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // SSID Field
                  TextField(
                    controller: _wifiSsidController,
                    decoration: InputDecoration(
                      labelText: 'Home Wi-Fi Name (SSID)',
                      hintText: 'e.g. MyHome-2.4G',
                      prefixIcon: const Icon(Icons.wifi_rounded, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Password Field
                  TextField(
                    controller: _wifiPassController,
                    obscureText: _obscureWifiPass,
                    decoration: InputDecoration(
                      labelText: 'Wi-Fi Password',
                      hintText: 'WPA2/WPA3 Password (min 8 chars)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureWifiPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setState(() => _obscureWifiPass = !_obscureWifiPass),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '⚠️ Note: ESP32 microcontrollers only connect to 2.4GHz Wi-Fi bands (not 5GHz).',
                    style: TextStyle(fontSize: 10, color: Color(0xFFB45309)),
                  ),
                  const SizedBox(height: 12),

                  // Connect Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProvisioningWifi ? null : _connectDeviceToWifi,
                      icon: _isProvisioningWifi
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _isProvisioningWifi ? 'Connecting ESP32 to Wi-Fi...' : 'Connect IoT to Network',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _reconfigureWifi,
                      child: const Text('Prefer step-by-step guidance? Open Setup Wizard ➔', style: TextStyle(fontSize: 11, color: kPrimaryColor)),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isAuto ? Colors.teal.shade50 : kPrimaryColor.withValues(alpha: 0.12),
                child: Icon(
                  isAuto ? Icons.autorenew_rounded : Icons.water_drop_outlined,
                  color: isAuto ? Colors.teal.shade700 : kPrimaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Watering Mode & Soil Alerts',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                    ),
                    Text(
                      isAuto
                          ? 'Auto watering active • Decision alerts disabled'
                          : 'Manual watering active • Configure decision alerts',
                      style: const TextStyle(fontSize: 11, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAuto ? Colors.teal.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAuto ? 'AUTO' : 'MANUAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAuto ? Colors.teal.shade900 : Colors.orange.shade900,
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
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderSubtle),
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
                        _service.persistDevices();
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

          // Quick Watering Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.water_drop_outlined, size: 16),
                  label: const Text('Quick Water (3s)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _triggerWaterPulse,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(_isPumpRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16),
                  label: Text(_isPumpRunning ? 'Stop Pump' : 'Start Pump'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isPumpRunning ? kStatusDanger : kPrimaryColor,
                    side: BorderSide(color: _isPumpRunning ? kStatusDanger : kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _togglePumpState,
                ),
              ),
            ],
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
  // PANEL 1: PLANT & HYDRATION CARE (PRIMARY & DEFAULT TAB)
  // =========================================================================
  Widget _buildPlantAndCarePanel() {
    final statusColor = _getMoistureColor(_moisturePercent);
    final statusLabel = _getMoistureStatusLabel(_moisturePercent);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Live status banner (Friendly & reassuring)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? kStatusSuccess : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isConnected
                        ? 'Connected • Live Sensor Telemetry Active${_lastPollTime != null ? " (${_lastPollTime!.minute.toString().padLeft(2, '0')}:${_lastPollTime!.second.toString().padLeft(2, '0')})" : ""}'
                        : 'Offline / Searching for Sensor...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? kStatusSuccess : const Color(0xFFB45309),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kStatusSuccess.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_latencyMs}ms',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kStatusSuccess),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Linked Specimen Card (Strict 1-to-1 Mapping) - Plant First!
          _buildAssignedPlantSection(),
          const SizedBox(height: 16),

          // 3. Soil Moisture Level Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Soil Moisture Level',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
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
                    const Text(
                      '%',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextSecondary),
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
                    backgroundColor: kBackgroundColor,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 12),

                // Friendly target & power info
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ideal Target: 30% - 65%',
                      style: TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text('USB 5V Powered', style: TextStyle(fontSize: 11, color: kTextSecondary)),
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
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
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
          title: const Text(
            'Sensor History & Diagnostics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
          ),
          subtitle: const Text(
            'Moisture history, raw ADC & polling controls',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          children: [
            const Divider(height: 1, color: kBorderSubtle),
            const SizedBox(height: 12),
            if (_moistureHistory.isNotEmpty) ...[
              const Text('Live Moisture History (30 samples)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextPrimary)),
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
                const Text('Raw Sensor ADC', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                Text(
                  '$_rawAdc (Range: 1100 wet - 3100 dry)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-refresh Telemetry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary)),
                      Text('Continuously poll probe every 4 seconds', style: TextStyle(fontSize: 10.5, color: kTextSecondary)),
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
                  side: const BorderSide(color: kBorderSubtle),
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
  // PANEL 3: DEVICE ACTIVITY LOGS PANEL
  // =========================================================================
  Widget _buildDeviceActivityLogsPanel() {
    return ValueListenableBuilder<List<IotActivityLog>>(
      valueListenable: _service.activityLogsNotifier,
      builder: (context, logs, _) {
        final deviceLogs = logs.where((l) {
          if (l.deviceId == widget.device.id) return true;
          if (l.deviceId == 'SmartPlant-ESP32' && widget.device.id == _service.registeredDeviceId) return true;
          return logs.length <= 3;
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
  }

  // =========================================================================
  // ASSIGNED PLANT & SPECIMEN LINKING (STRICT 1-TO-1 MAPPING)
  // =========================================================================
  Widget _buildAssignedPlantSection() {
    final Plant? assignedPlant = _plantService.getPlantForDevice(widget.device.id);

    if (assignedPlant == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderSubtle),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.yard_outlined, color: Colors.grey, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Specimen',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'No plant linked to this probe',
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Unassigned',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Link this IoT sensor to a specimen in your garden to track live hydration telemetry and automate watering routines.',
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
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
        color: kSurfaceColor,
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
              const Expanded(
                child: Text(
                  'Assigned Specimen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_moisturePercent >= 25 ? kStatusSuccess : kStatusWarning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _moisturePercent >= 25 ? 'Healthy Hydration' : 'Needs Moisture',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _moisturePercent >= 25 ? kStatusSuccess : kStatusWarning,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignedPlant.species,
                      style: const TextStyle(fontSize: 12, color: kTextSecondary, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target Moisture Range: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                Text(
                  '30% - 65%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor),
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
                  label: const Text('Change Plant'),
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
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey.shade300,
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
                          const Text(
                            'Assign Specimen to Probe',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                          ),
                          Text(
                            'Probe: ${widget.device.name} (Strict 1-to-1 link)',
                            style: const TextStyle(fontSize: 12, color: kTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (plants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No plants found in your garden. Add a plant from the Garden tab first!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextSecondary),
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
                          color: isCurrent ? kPrimaryColor.withValues(alpha: 0.08) : kBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? kPrimaryColor
                                : (isAssignedToOther ? Colors.orange.shade300 : kBorderSubtle),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plant.species, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
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

  // Helpers
  Color _getMoistureColor(int moisture) {
    if (moisture < 25) return const Color(0xFFDC2626); // Dry - Red
    if (moisture <= 70) return kStatusSuccess; // Optimal - Green
    return const Color(0xFF2563EB); // Wet - Blue
  }

  String _getMoistureStatusLabel(int moisture) {
    if (moisture < 25) return 'Soil Dry (Needs Water)';
    if (moisture <= 70) return 'Optimal Moisture';
    return 'Wet Soil';
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
