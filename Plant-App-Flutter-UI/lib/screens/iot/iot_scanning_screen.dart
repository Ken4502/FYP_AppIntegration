import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/platform/web_hardware_bridge.dart';

class IotScanningScreen extends StatefulWidget {
  const IotScanningScreen({super.key});

  @override
  State<IotScanningScreen> createState() => _IotScanningScreenState();
}

class _IotScanningScreenState extends State<IotScanningScreen> {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  bool _isScanning = false;
  bool _isConnecting = false;
  List<DiscoveredIotNode> _discoveredNodes = [];

  @override
  void initState() {
    super.initState();
    _startLocalSubnetScan();
  }

  Future<void> _startLocalSubnetScan() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
    });

    try {
      final nodes = await _service.discoverLocalIotDevices();
      if (mounted) {
        setState(() {
          _discoveredNodes = nodes;
          _isScanning = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _registerDiscoveredNode(DiscoveredIotNode node) async {
    setState(() {
      _isConnecting = true;
    });

    final newIotDevice = IotDevice(
      id: node.deviceId,
      name: node.name,
      isWifiConnected: node.isWifiConnected,
      wifiSsid: 'Configured on Wi-Fi Network',
      supportsMoistureSensor: true,
      supportsAutoWater: true,
      moistureLevel: (node.moisturePercent / 100.0).clamp(0.0, 1.0),
      isVerifiedCompatible: true,
      firmwareVersion: 'v3.0.0-WiFiManager-ntfy',
    );

    await _service.connectIotDevice(newIotDevice);

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Registered ${node.name} (${node.ip}) to phone! Global alerts active.'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, newIotDevice);
    }
  }

  void _onManualCompleteSetup() async {
    setState(() {
      _isConnecting = true;
    });

    final newIotDevice = IotDevice(
      id: 'SmartPlant-ESP32',
      name: 'SmartPlant-ESP32',
      isWifiConnected: true,
      wifiSsid: 'Configured via Captive Portal',
      supportsMoistureSensor: true,
      supportsAutoWater: true,
      moistureLevel: 0.0,
      isVerifiedCompatible: true,
      firmwareVersion: 'v3.0.0-WiFiManager-ntfy',
    );

    await _service.connectIotDevice(newIotDevice);

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
      Navigator.pop(context, newIotDevice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'ESP32 Node Discovery',
        subtitle: 'Local Wi-Fi Subnet Scanner',
        toolbarHeight: 68,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? kDarkCardColor : kBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? kDarkBorderSubtle : kBorderSubtle,
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.refresh_rounded, size: 20, color: kPrimaryColor),
              ),
              tooltip: 'Rescan Wi-Fi Subnet',
              onPressed: _isScanning ? null : _startLocalSubnetScan,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryColor.withValues(alpha: 0.12),
                    kPrimaryColor.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wifi_find_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic Wi-Fi Node Discovery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Discovers ESP32 nodes connected to your home Wi-Fi and registers them to your phone.',
                          style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Discovered Hardware Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discovered ESP32 Nodes on Wi-Fi:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_discoveredNodes.isNotEmpty)
              ..._discoveredNodes.map((node) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCardColor : kSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kPrimaryColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.sensors_rounded, color: kPrimaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('Station IP: ${node.ip} • MAC: ${node.mac}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                              Text('Moisture: ${node.moisturePercent}% • Topic: ${node.ntfyTopic}', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isConnecting ? null : () => _registerDiscoveredNode(node),
                          child: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ))
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isScanning
                            ? 'Scanning local Wi-Fi network for ESP32 nodes...'
                            : 'No ESP32 detected on current Wi-Fi. If unconfigured, connect to "ESP32-Setup" Wi-Fi below.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            const Text(
              'Wi-Fi Setup Instructions (If Node Unconfigured):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
            ),
            const SizedBox(height: 14),

            // Step 1
            _buildSetupStep(
              stepNumber: '1',
              title: 'Power On ESP32',
              description: 'Plug in your ESP32 board. If not connected to Wi-Fi, it will broadcast a hotspot named "ESP32-Setup".',
              icon: Icons.power_rounded,
            ),
            const SizedBox(height: 14),

            // Step 2
            _buildSetupStep(
              stepNumber: '2',
              title: 'Connect to "ESP32-Setup" Wi-Fi',
              description: 'In your phone\'s Wi-Fi settings, connect to "ESP32-Setup" (no password needed).',
              icon: Icons.wifi_find_rounded,
              actionButton: OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open System Wi-Fi Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => WebHardwareBridge.openWifiSettings(),
              ),
            ),
            const SizedBox(height: 14),

            // Step 3
            _buildSetupStep(
              stepNumber: '3',
              title: 'Launch Configuration Portal',
              description: 'Open http://192.168.4.1 to select your home 2.4GHz Wi-Fi network and save password.',
              icon: Icons.open_in_browser_rounded,
              actionButton: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('Open Setup Portal (http://192.168.4.1)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => WebHardwareBridge.openBrowserUrl('http://192.168.4.1'),
              ),
            ),
            const SizedBox(height: 14),

            // Step 4
            _buildSetupStep(
              stepNumber: '4',
              title: 'Auto-Discovery & Alert Registration',
              description: 'Once connected to Wi-Fi, return to this app and tap "Rescan" at the top to dynamically register the node!',
              icon: Icons.notifications_active_rounded,
            ),
            const SizedBox(height: 28),

            // Complete Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isConnecting ? 'Registering Device...' : 'Complete & Return to Hub',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isConnecting ? null : _onManualCompleteSetup,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    Widget? actionButton,
  }) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
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
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: kPrimaryColor,
                child: Text(
                  stepNumber,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: kPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
          if (actionButton != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 10),
              child: actionButton,
            ),
        ],
      ),
    );
  }
}
