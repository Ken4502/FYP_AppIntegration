import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/iot_connection_mode.dart';
import '../../models/iot_device_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/platform/web_hardware_bridge.dart';
import 'iot_details_screen.dart';
import 'iot_setup_wizard_screen.dart';

class IotConnectionSetupScreen extends StatefulWidget {
  final VoidCallback? onConnectedProceed;
  final VoidCallback? onViewLogs;

  const IotConnectionSetupScreen({
    super.key,
    this.onConnectedProceed,
    this.onViewLogs,
  });

  @override
  State<IotConnectionSetupScreen> createState() => _IotConnectionSetupScreenState();
}

class _IotConnectionSetupScreenState extends State<IotConnectionSetupScreen>
    with WidgetsBindingObserver {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  late TextEditingController _ipController;
  late TextEditingController _homeSsidController;
  late TextEditingController _homePassController;

  // Real-time Dynamic 6-Instance State
  Timer? _probeTimer;
  bool _isProbing = false;
  IotNetworkStatus? _currentStatus;

  // Manual Ping State
  bool _isTestingPing = false;
  bool? _lastPingSuccess;
  String? _lastPingMessage;

  // Test Notification State
  bool _isTestingNotification = false;

  // Home Wi-Fi Provisioning State
  bool _obscurePassword = true;
  bool _isScanningNetworks = false;
  List<WifiNetwork> _scannedNetworks = [];
  bool _isProvisioning = false;
  bool? _provisionSuccess;
  String? _provisionMessage;

  // View state
  bool _showWifiReconfigure = false;
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ipController = TextEditingController(text: _service.targetDeviceIp);
    _homeSsidController = TextEditingController();
    _homePassController = TextEditingController();

    // Start immediate check and background 3-second auto-probe
    _probeActiveNetwork();
    _probeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _probeActiveNetwork();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probeTimer?.cancel();
    _ipController.dispose();
    _homeSsidController.dispose();
    _homePassController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User just returned from phone settings or Wi-Fi switcher
      _probeActiveNetwork();
    }
  }

  /// Real-time multi-target probe to dynamically detect the 6 instances
  Future<void> _probeActiveNetwork() async {
    if (_isProbing) return;
    if (mounted) setState(() => _isProbing = true);

    try {
      final status = await _service.detectNetworkInstance();
      if (!mounted) return;

      setState(() {
        _isProbing = false;
        _currentStatus = status;

        if (status.activeIp.isNotEmpty &&
            !status.activeIp.contains('Cloud') &&
            _ipController.text != status.activeIp) {
          _ipController.text = status.activeIp;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isProbing = false);
      }
    }
  }

  Future<void> _runPingTest() async {
    setState(() {
      _isTestingPing = true;
      _lastPingMessage = null;
    });

    final targetIp = _ipController.text.trim();
    final res = await _service.testHardwarePing(targetIp);

    if (mounted) {
      setState(() {
        _isTestingPing = false;
        _lastPingSuccess = res.isSuccess;
        _lastPingMessage = res.message;
      });

      _probeActiveNetwork();
      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected to ESP32 at $targetIp!'),
            backgroundColor: kStatusSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Dispatches a test notification and verifies end-to-end receipt
  Future<void> _testNotificationAction() async {
    setState(() => _isTestingNotification = true);

    final res = await _service.testConnectionAndNotify();

    if (mounted) {
      setState(() => _isTestingNotification = false);
      _probeActiveNetwork();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                res.isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: res.isSuccess ? kStatusSuccess : kStatusDanger,
                size: 24,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  res.isSuccess ? 'Round-Trip Verified!' : 'Handshake Failed',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(res.message, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              if (res.isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kStatusSuccess.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: kStatusSuccess, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Latency: ${res.data?['latencyMs'] != null ? "${res.data?['latencyMs']}ms" : "Verified"} • ${res.data?['channel'] ?? "Hardware"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kStatusSuccess),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 Look at your phone\'s notification bar — you should see the heads-up notification with sound & vibration.',
                  style: TextStyle(fontSize: 11, color: kTextSecondary),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hardware was not detected at the target IP. Verify power & Wi-Fi credentials.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(res.isSuccess ? 'Awesome!' : 'OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _scanNearbyHomeNetworks() async {
    setState(() {
      _isScanningNetworks = true;
    });

    final networks = await _service.scanNearbyWifiNetworks();

    if (mounted) {
      setState(() {
        _isScanningNetworks = false;
        _scannedNetworks = networks;
      });

      if (networks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No 2.4GHz Wi-Fi networks found. Ensure your phone is connected to SmartPlant-ESP32.'),
            backgroundColor: kStatusWarning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _connectEsp32ToHomeWifi() async {
    final ssid = _homeSsidController.text.trim();
    final pass = _homePassController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or type your Home Wi-Fi name (SSID).')),
      );
      return;
    }

    setState(() {
      _isProvisioning = true;
      _provisionMessage = null;
      _provisionSuccess = null;
    });

    final res = await _service.provisionDeviceWifi(
      deviceId: 'SmartPlant-ESP32',
      wifiSsid: ssid,
      wifiPassword: pass,
    );

    if (mounted) {
      final String? assignedIp = res.data?['ip'] as String?;
      setState(() {
        _isProvisioning = false;
        _provisionSuccess = res.isSuccess;
        _provisionMessage = res.message;
        if (assignedIp != null && assignedIp.isNotEmpty) {
          _ipController.text = assignedIp;
        }
      });

      if (res.isSuccess) {
        _probeActiveNetwork();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Connected! ESP32 joined "$ssid" at ${assignedIp ?? "home network"}. Reconnect your phone to "$ssid"!'),
            backgroundColor: kStatusSuccess,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _resetHomeWifi() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Wi-Fi Credentials?'),
        content: const Text(
          'This will clear the saved home Wi-Fi credentials from the ESP32 flash memory and return the device to setup mode.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger, foregroundColor: Colors.white),
            child: const Text('Reset & Forget'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await _service.resetDeviceWifi('SmartPlant-ESP32');
      setState(() {
        _homeSsidController.clear();
        _homePassController.clear();
        _ipController.text = '192.168.4.1';
        _showWifiReconfigure = true;
      });
      _probeActiveNetwork();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: kPrimaryColor),
        );
      }
    }
  }

  Future<void> _toggleDeviceRegistration() async {
    if (_service.isDeviceRegistered) {
      await _service.unregisterDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sensor unregistered from this phone.')),
        );
      }
    } else {
      await _service.registerDevice(
        deviceId: 'SmartPlant-ESP32',
        name: 'Smart Plant Sensor',
        homeSsid: 'WenNikk-2.4Ghz',
        stationIp: '192.168.1.18',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sensor registered to this phone!'), backgroundColor: kStatusSuccess),
        );
      }
    }
    _probeActiveNetwork();
  }

  Future<void> _launchSetupWizard() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const IotSetupWizardScreen()),
    );
    if (res == true && mounted) {
      _probeActiveNetwork();
    }
  }

  void _openDeviceDetails(IotDevice device) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IotDetailsScreen(device: device)),
    );
    if (res == true && mounted) {
      _probeActiveNetwork();
    }
  }

  Widget _buildSetupNewIotButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchSetupWizard,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup New IoT Device',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Step-by-step: Connect hotspot, configure Wi-Fi & pair',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHostedDevicesSection(IotNetworkStatus? status) {
    final isRegistered = _service.isDeviceRegistered;
    final deviceName = _service.registeredDeviceName;
    final stationIp = _service.savedStationIp ?? _service.targetDeviceIp;
    final homeSsid = _service.registeredHomeSsid ?? status?.esp32Ssid ?? 'Home Wi-Fi';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderSubtleColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 18, color: kPrimaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Connected IoT Hosted on this Phone',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isRegistered ? kStatusSuccess.withValues(alpha: 0.12) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isRegistered ? '1 Hosted' : '0 Hosted',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isRegistered ? kStatusSuccess : kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isRegistered) ...[
            InkWell(
              onTap: () {
                final dev = IotDevice(
                  id: _service.registeredDeviceId,
                  name: deviceName,
                  wifiSsid: homeSsid,
                  isWifiConnected: true,
                  moistureLevel: status?.moisture?.toDouble() ?? 0.0,
                );
                _openDeviceDetails(dev);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderSubtleColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.developer_board_rounded, color: kPrimaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  deviceName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kStatusSuccess,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'HOST: THIS PHONE 🟢',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Wi-Fi: $homeSsid • IP: $stationIp',
                            style: const TextStyle(fontSize: 11, color: kTextSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Soil Moisture: ${status?.moisture != null ? "${status!.moisture}%" : "Monitoring live..."}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status?.moisture != null ? kStatusSuccess : kTextSecondary,
                                ),
                              ),
                              const Text('• Details & Sensors ➔', style: TextStyle(fontSize: 10, color: kPrimaryColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: kTextSecondary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No IoT devices paired to this phone yet. Tap "Setup New IoT Device" above to connect and host an ESP32.',
                      style: TextStyle(fontSize: 11, color: kTextSecondary, height: 1.3),
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

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;
    final instance = status?.instance ?? IotNetworkInstance.remoteNoDeviceLinked;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _probeActiveNetwork,
        color: kPrimaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(kDefaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Primary Action: Setup New IoT Device
              _buildSetupNewIotButton(),
              const SizedBox(height: 14),

              // 1. Connected IoT Devices Hosted on this Phone
              _buildHostedDevicesSection(status),
              const SizedBox(height: 16),

              // 2. Dynamic 6-Instance Status Banner
              _buildDynamicInstanceBanner(status),
              const SizedBox(height: 16),

              // 3. Dynamic Content per Instance
              _buildDynamicInstanceContent(instance, status),
              const SizedBox(height: 16),

              // 4. Quick Action: Test Connection & Send Notification
              _buildTestNotificationCard(status),
              const SizedBox(height: 16),

              // 5. Live Activity Logs Stream Card
              _buildActivityLogsCard(),
              const SizedBox(height: 16),

              // 6. Collapsible Advanced Developer & IP Tools
              _buildAdvancedSettingsAccordion(status),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Dynamic Status Banner rendering the exact state of the 6 instances
  Widget _buildDynamicInstanceBanner(IotNetworkStatus? status) {
    final instance = status?.instance ?? IotNetworkInstance.remoteNoDeviceLinked;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    switch (instance) {
      case IotNetworkInstance.hotspotUnpaired:
        color = const Color(0xFFD97706);
        icon = Icons.wifi_tethering_rounded;
        title = '1. ESP32 Hotspot Connected (Needs Home Wi-Fi)';
        subtitle = 'Phone is on "SmartPlant-ESP32" • Ready for 2.4GHz Wi-Fi setup';
        break;

      case IotNetworkInstance.hotspotAlreadyPaired:
        color = const Color(0xFF2563EB);
        icon = Icons.router_rounded;
        title = '2. Hotspot Link (Already on Home Wi-Fi)';
        subtitle = 'Sensor is on "${status?.esp32Ssid ?? "Home Wi-Fi"}" (${status?.stationIp ?? "Online"})';
        break;

      case IotNetworkInstance.homeWifiOnline:
        color = kStatusSuccess;
        icon = Icons.wifi_rounded;
        title = '3. Local Home Wi-Fi (Direct Link Active)';
        subtitle = 'Direct LAN link: ${status?.activeIp} (${status?.latencyMs}ms) • "${status?.phoneSsid ?? "Home Wi-Fi"}"';
        break;

      case IotNetworkInstance.homeWifiOffline:
        color = const Color(0xFFDC2626);
        icon = Icons.wifi_off_rounded;
        title = '4. Home Wi-Fi (Sensor Not Found Locally)';
        subtitle = 'Phone is on "${status?.phoneSsid ?? "Home Wi-Fi"}", but ESP32 at ${status?.activeIp} is unreachable';
        break;

      case IotNetworkInstance.remoteCloudLinked:
        color = const Color(0xFF0284C7);
        icon = Icons.cloud_done_rounded;
        title = '5. Remote Cloud Link (4G/5G Worldwide Access)';
        subtitle = 'Phone is on ${status?.networkType.toUpperCase()} • Linked to "${status?.registeredDeviceName}"';
        break;

      case IotNetworkInstance.remoteNoDeviceLinked:
        color = const Color(0xFF64748B);
        icon = Icons.cloud_off_rounded;
        title = '6. Remote Network (No Sensor Linked Yet)';
        subtitle = 'Phone is on ${status?.networkType.toUpperCase()} • Connect to "SmartPlant-ESP32" to set up';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isProbing) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: color,
            tooltip: 'Refresh Network Status',
            onPressed: _probeActiveNetwork,
          ),
        ],
      ),
    );
  }

  /// 2. Dynamic content card for the current instance
  Widget _buildDynamicInstanceContent(IotNetworkInstance instance, IotNetworkStatus? status) {
    switch (instance) {
      // INSTANCE 1: Hotspot connected, needs Home Wi-Fi
      case IotNetworkInstance.hotspotUnpaired:
        return _buildGuidedSetupSection(isHotspotConnected: true);

      // INSTANCE 2: Hotspot connected, already paired to Home Wi-Fi
      case IotNetworkInstance.hotspotAlreadyPaired:
        return _buildHotspotAlreadyPairedCard(status);

      // INSTANCE 3: Home Wi-Fi online
      case IotNetworkInstance.homeWifiOnline:
        return _buildHomeWifiOnlineCard(status);

      // INSTANCE 4: Home Wi-Fi, sensor offline
      case IotNetworkInstance.homeWifiOffline:
        return _buildHomeWifiOfflineCard(status);

      // INSTANCE 5: Remote (4G/5G / other Wi-Fi) & ESP32 is registered
      case IotNetworkInstance.remoteCloudLinked:
        return _buildRemoteCloudLinkedCard(status);

      // INSTANCE 6: Remote (4G/5G / other Wi-Fi) & ESP32 is NOT registered
      case IotNetworkInstance.remoteNoDeviceLinked:
        return _buildRemoteNoDeviceLinkedCard(status);
    }
  }

  /// Card for Instance 2: Hotspot connected, already paired
  Widget _buildHotspotAlreadyPairedCard(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sensor is Already on Home Wi-Fi!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your sensor is connected to "${status?.esp32Ssid ?? "Home Wi-Fi"}" at IP ${status?.stationIp ?? "192.168.1.18"}. Your phone is currently on the setup hotspot.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => WebHardwareBridge.openWifiSettings(),
                icon: const Icon(Icons.wifi_rounded, size: 18),
                label: Text('Reconnect Phone to "${status?.esp32Ssid ?? "Home Wi-Fi"}"'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showWifiReconfigure = !_showWifiReconfigure),
                child: Text(
                  _showWifiReconfigure ? 'Hide Wi-Fi Pairing Form' : 'Need to change Wi-Fi network? Tap here',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                ),
              ),
            ),
            if (_showWifiReconfigure) ...[
              const Divider(),
              _buildStep2HomeWifiForm(),
            ],
          ],
        ),
      ),
    );
  }

  /// Card for Instance 3: Home Wi-Fi Online
  Widget _buildHomeWifiOnlineCard(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFBBF7D0)),
      ),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct Home Link Active!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
                      ),
                      Text(
                        'Online at ${status?.activeIp} on "${status?.esp32Ssid ?? "Home Router"}"',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Moisture', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        status?.moisture != null ? '${status!.moisture}%' : '--%',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kStatusSuccess),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.shade200),
                  Column(
                    children: [
                      const Text('Latency', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '${status?.latencyMs ?? 0} ms',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.shade200),
                  Column(
                    children: [
                      const Text('Mode', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        status?.mode ?? 'AUTO',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showWifiReconfigure = !_showWifiReconfigure),
                icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF15803D)),
                label: const Text('Reconfigure / Change Wi-Fi', style: TextStyle(fontSize: 12, color: Color(0xFF15803D))),
              ),
            ),
            if (_showWifiReconfigure) ...[
              const Divider(),
              _buildStep2HomeWifiForm(),
            ],
          ],
        ),
      ),
    );
  }

  /// Card for Instance 4: Home Wi-Fi, Sensor Offline
  Widget _buildHomeWifiOfflineCard(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFECACA)),
      ),
      color: const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sensor Not Found on Local Network',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF991B1B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your phone is on "${status?.phoneSsid ?? "Home Wi-Fi"}", but ESP32 at ${status?.activeIp} is not responding.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Ensure the ESP32 is powered on (blue power LED on board).\n'
              '• If the ESP32 restarted, it may take 10 seconds to reconnect to your Wi-Fi.\n'
              '• If your router changed or restarted, connect to "SmartPlant-ESP32" to reconfigure.',
              style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _runPingTest,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry Local Ping'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFF87171)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => WebHardwareBridge.openWifiSettings(),
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                    label: const Text('Open Hotspot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Card for Instance 5: Remote Cloud Linked (4G/5G / Remote Wi-Fi)
  Widget _buildRemoteCloudLinkedCard(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFBAE6FD)),
      ),
      color: const Color(0xFFF0F9FF),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sensor Linked via Global Cloud!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0369A1)),
                      ),
                      Text(
                        'Phone Network: ${status?.networkType.toUpperCase() ?? "CELLULAR / 4G"}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF075985)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0F2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Linked Sensor: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                      Flexible(
                        child: Text(
                          status?.registeredDeviceName ?? 'Smart Plant Sensor',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextPrimary),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Home Wi-Fi Router: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                      Flexible(
                        child: Text(
                          status?.registeredHomeSsid ?? 'WenNikk-2.4Ghz',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextPrimary),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Push Alert Pipeline: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                      Flexible(
                        child: Text(
                          'ntfy.sh & System Banner 🟢',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kStatusSuccess),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 Even though you are away from home, you will receive notifications if soil becomes dry, and you can water your plant remotely.',
              style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  /// Card for Instance 6: Remote Network & No Sensor Linked
  Widget _buildRemoteNoDeviceLinkedCard(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.borderSubtleColor),
      ),
      color: context.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.eco_outlined, color: Colors.grey.shade700, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'No Plant Sensor Registered',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'You are on Mobile Data and do not have an ESP32 sensor linked to this phone yet. To set up your first sensor:',
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderSubtleColor),
              ),
              child: const Text(
                '1. Plug in your SmartPlant-ESP32 device.\n'
                '2. Turn on phone Wi-Fi and connect to "SmartPlant-ESP32" (Password: 12345678).\n'
                '3. Return to this screen to pair it with your home Wi-Fi in 30 seconds.',
                style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => WebHardwareBridge.openWifiSettings(),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open Phone Wi-Fi Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 3: Test Connection & Send Notification Card
  Widget _buildTestNotificationCard(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFDE68A)),
      ),
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 8),
                Text(
                  'End-to-End Alert Verification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Test that your phone receives heads-up push notifications from the ESP32 right now (works on both local Wi-Fi and 4G/5G mobile data):',
              style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTestingNotification ? null : _testNotificationAction,
                icon: _isTestingNotification
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isTestingNotification ? 'Sending Test Notification...' : '🔔 Test Connection & Send Notification',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 1 & 2 Guided Setup (used in Instance 1 & fallback)
  Widget _buildGuidedSetupSection({bool isHotspotConnected = false}) {
    return Column(
      children: [
        // STEP 1 CARD
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: context.borderSubtleColor),
          ),
          color: context.cardBg,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHotspotConnected ? kStatusSuccess : kPrimaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isHotspotConnected ? 'STEP 1: DONE' : 'STEP 1',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Connect Phone to Sensor Hotspot',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isHotspotConnected) ...[
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: kStatusSuccess, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phone is connected to SmartPlant-ESP32! Now complete Step 2 below.',
                          style: TextStyle(fontSize: 13, color: kStatusSuccess, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Connect your phone to the sensor\'s setup Wi-Fi in your phone settings:',
                    style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderSubtleColor),
                    ),
                    child: Column(
                      children: [
                        _buildCredentialRow('Network Name:', 'SmartPlant-ESP32', Icons.wifi),
                        const Divider(height: 16),
                        _buildCredentialRow('Password:', '12345678', Icons.lock_outline_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => WebHardwareBridge.openWifiSettings(),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Open Phone Wi-Fi Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // STEP 2 CARD
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: context.borderSubtleColor),
          ),
          color: context.cardBg,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'STEP 2',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Connect Sensor to Home Wi-Fi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose your 2.4GHz home Wi-Fi network so the sensor connects to your router:',
                  style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                _buildStep2HomeWifiForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2HomeWifiForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan Nearby Networks Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isScanningNetworks ? null : _scanNearbyHomeNetworks,
            icon: _isScanningNetworks
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find_rounded, size: 18),
            label: Text(_isScanningNetworks ? 'Scanning Nearby Wi-Fi...' : 'Scan Nearby 2.4GHz Wi-Fi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        // Scanned SSIDs horizontal chip row
        if (_scannedNetworks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Discovered Networks (Tap to select):', style: TextStyle(fontSize: 11, color: kTextSecondary)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _scannedNetworks.map((net) {
                final isSelected = _homeSsidController.text == net.ssid;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text('${net.ssid} (${net.signalStrength}%)'),
                    avatar: Icon(Icons.wifi, size: 14, color: isSelected ? Colors.white : kPrimaryColor),
                    backgroundColor: isSelected ? kPrimaryColor : kBackgroundColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : kTextPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onPressed: () {
                      setState(() {
                        _homeSsidController.text = net.ssid;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Home Wi-Fi SSID input
        TextField(
          controller: _homeSsidController,
          decoration: InputDecoration(
            labelText: 'Home Wi-Fi Name (SSID)',
            hintText: 'e.g. MyHome_2.4G',
            prefixIcon: const Icon(Icons.router_rounded, color: Color(0xFF2563EB)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Home Wi-Fi Password input
        TextField(
          controller: _homePassController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Home Wi-Fi Password',
            hintText: 'WPA2/WPA3 Password',
            prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF2563EB)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Connect Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProvisioning ? null : _connectEsp32ToHomeWifi,
            icon: _isProvisioning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(_isProvisioning ? 'Connecting ESP32 to Wi-Fi...' : 'Connect ESP32 to Home Wi-Fi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),

        // Provisioning feedback box
        if (_provisionMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _provisionSuccess == true
                  ? kStatusSuccess.withValues(alpha: 0.1)
                  : kStatusDanger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _provisionSuccess == true
                    ? kStatusSuccess.withValues(alpha: 0.3)
                    : kStatusDanger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _provisionSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: _provisionSuccess == true ? kStatusSuccess : kStatusDanger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _provisionMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _provisionSuccess == true ? kStatusSuccess : kStatusDanger,
                        ),
                      ),
                      if (_provisionSuccess == true) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '💡 Next Step: Reconnect your phone back to your Home Wi-Fi. The app will auto-detect your sensor!',
                          style: TextStyle(fontSize: 11, color: kTextPrimary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCredentialRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kPrimaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: kTextSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityLogsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderSubtleColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 18, color: kPrimaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Recent IoT Activity Logs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                  ),
                ],
              ),
              if (widget.onViewLogs != null)
                TextButton(
                  onPressed: widget.onViewLogs,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View All ➔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<IotActivityLog>>(
            valueListenable: _service.activityLogsNotifier,
            builder: (ctx, logs, _) {
              if (logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No events recorded yet. Hardware and watering events will show here.', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                );
              }
              final displayLogs = logs.take(3).toList();
              return Column(
                children: displayLogs.map((l) {
                  final timeStr = '${l.timestamp.hour.toString().padLeft(2, '0')}:${l.timestamp.minute.toString().padLeft(2, '0')}:${l.timestamp.second.toString().padLeft(2, '0')}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(l.icon, size: 16, color: l.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        l.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kTextPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(timeStr, style: const TextStyle(fontSize: 9, color: kTextSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l.detail,
                                  style: const TextStyle(fontSize: 10, color: kTextSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (widget.onViewLogs != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('Open Full Activity Log Stream'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kBorderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: widget.onViewLogs,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Collapsible Accordion containing technical IP settings, registration toggle, manual Ping, and memory reset
  Widget _buildAdvancedSettingsAccordion(IotNetworkStatus? status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.borderSubtleColor),
      ),
      color: context.cardBg,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showAdvancedSettings,
          onExpansionChanged: (val) => setState(() => _showAdvancedSettings = val),
          leading: const Icon(Icons.build_circle_outlined, color: kTextSecondary),
          title: const Text(
            'Advanced Hardware & Registration Tools',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
          ),
          subtitle: const Text(
            'Manual IP, ping testing, device registration, memory reset',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: kBorderSubtle),
                  const SizedBox(height: 8),

                  // Device Registration Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone Registration Status',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                          ),
                          Text(
                            _service.isDeviceRegistered ? 'Linked to this phone & account 🟢' : 'Not registered to this phone ⚪',
                            style: TextStyle(
                              fontSize: 11,
                              color: _service.isDeviceRegistered ? kStatusSuccess : kTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton(
                        onPressed: _toggleDeviceRegistration,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _service.isDeviceRegistered ? kStatusDanger : kPrimaryColor,
                          side: BorderSide(color: _service.isDeviceRegistered ? kStatusDanger : kPrimaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: Text(_service.isDeviceRegistered ? 'Unregister' : 'Register'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: kBorderSubtle),
                  const SizedBox(height: 8),

                  const Text(
                    'Manual IP Configuration & Ping Test',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'ESP32 Device IP Address',
                      hintText: '192.168.1.18 or 192.168.4.1',
                      prefixIcon: const Icon(Icons.lan_outlined, color: kPrimaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        _service.setTargetDeviceIp(val.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTestingPing ? null : _runPingTest,
                      icon: _isTestingPing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(_isTestingPing ? 'Pinging...' : 'Test Connection (Ping)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_lastPingMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _lastPingSuccess == true
                            ? kStatusSuccess.withValues(alpha: 0.1)
                            : kStatusDanger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _lastPingMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _lastPingSuccess == true ? kStatusSuccess : kStatusDanger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: kBorderSubtle),
                  const SizedBox(height: 8),
                  const Text(
                    'Hardware Reset',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Clear saved Wi-Fi credentials from ESP32 memory and return to factory SoftAP setup mode.',
                    style: TextStyle(fontSize: 11, color: kTextSecondary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _resetHomeWifi,
                      icon: const Icon(Icons.delete_forever_rounded, color: kStatusDanger, size: 18),
                      label: const Text('Reset & Forget Saved Wi-Fi', style: TextStyle(color: kStatusDanger)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
}
