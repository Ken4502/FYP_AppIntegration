import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/ntfy_notification_service.dart';
import 'iot_setup_wizard_screen.dart';

/// Comprehensive Hardware & Network Diagnostics Screen
/// Displays full, un-truncated hardware specs, network topology, IP addressing,
/// routing endpoints, and interactive ping / diagnostic tools.
class IotNetworkInfoScreen extends StatefulWidget {
  final IotDevice device;
  final bool isConnected;
  final int latencyMs;

  const IotNetworkInfoScreen({
    super.key,
    required this.device,
    this.isConnected = false,
    this.latencyMs = 0,
  });

  @override
  State<IotNetworkInfoScreen> createState() => _IotNetworkInfoScreenState();
}

class _IotNetworkInfoScreenState extends State<IotNetworkInfoScreen> {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();

  bool _isPinging = false;
  String? _pingResult;
  int _currentLatency = 0;
  bool _isTestingAlert = false;

  @override
  void initState() {
    super.initState();
    _currentLatency = widget.latencyMs;
  }

  Future<void> _runPing() async {
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    final sw = Stopwatch()..start();
    final data = await _service.fetchLiveHardwareTelemetry();
    sw.stop();

    if (!mounted) return;

    setState(() {
      _isPinging = false;
      if (data != null) {
        _currentLatency = sw.elapsedMilliseconds;
        _pingResult = 'Online (${_currentLatency}ms response)';
      } else {
        _pingResult = 'Hardware timeout / offline';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          data != null
              ? '✅ Ping Successful: ${_currentLatency}ms round-trip latency'
              : '⚠️ Ping Failed: ESP32 did not respond on local station IP',
        ),
        backgroundColor: data != null ? kPrimaryColor : kStatusDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendTestAlert() async {
    setState(() => _isTestingAlert = true);

    final res = await _service.testConnectionAndNotify(
      customMessage: 'Diagnostic Alert Test: ESP32 hardware & network link verified successfully!',
    );

    if (!mounted) return;
    setState(() => _isTestingAlert = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.isSuccess ? kPrimaryColor : kStatusDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Copied $label to clipboard: $text'),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _copyFullReport() {
    final stationIp = _service.savedStationIp ?? _service.targetDeviceIp;
    final homeSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? 'WenNikk-2.4Ghz';
    final alertTopic = NtfyNotificationService().topic;

    final report = '''
========================================
URBANGREEN IOT DIAGNOSTIC REPORT
========================================
Device Name:      ${widget.device.name}
Device ID:        ${widget.device.id}
Microcontroller:  ESP32-WROOM-32 (Xtensa 32-bit LX6 Dual-Core @ 240MHz)
SRAM / Flash:     520 KB SRAM / 4 MB SPI Flash
Firmware Build:   ${widget.device.firmwareVersion}
Connected Wi-Fi:  $homeSsid
Station IP (LAN): $stationIp
SoftAP Gateway:   192.168.4.1
Telemetry URL:    http://$stationIp/telemetry
Water Pump URL:   http://$stationIp/pump?action=pulse
Ping Latency:     ${_currentLatency > 0 ? "${_currentLatency}ms" : "Active"}
Alert Broker:     ntfy.sh ($alertTopic)
Main Host Phone:  Registered / Primary Dispatcher
========================================
Generated on: ${DateTime.now().toLocal()}
''';

    Clipboard.setData(ClipboardData(text: report.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📋 Full hardware & network report copied to clipboard!'),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationIp = _service.savedStationIp ?? _service.targetDeviceIp;
    final homeSsid = widget.device.wifiSsid ?? _service.registeredHomeSsid ?? 'WenNikk-2.4Ghz';
    final isOnline = _service.isRealHardwareConnected || widget.isConnected;

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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diagnostics & Specs 📡',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF616161),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hardware & Network',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 44x44 Circular Copy Report Action
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
                          icon: const Icon(Icons.copy_all_rounded, color: kTextPrimary, size: 21),
                          tooltip: 'Copy Full Report',
                          onPressed: _copyFullReport,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Diagnostic Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overview Live Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? kStatusSuccess.withValues(alpha: 0.12)
                                  : kStatusWarning.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isOnline
                                    ? kStatusSuccess.withValues(alpha: 0.3)
                                    : kStatusWarning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                              color: isOnline ? kStatusSuccess : const Color(0xFFB45309),
                              size: 24,
                            ),
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
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: kTextPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOnline ? kStatusSuccess : const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isOnline ? 'ONLINE' : 'LOCAL LINK',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Node ID: ${widget.device.id} • Latency: ${_currentLatency > 0 ? "$_currentLatency ms" : "Direct Link"}',
                                  style: const TextStyle(fontSize: 12, color: kTextSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Microcontroller & Hardware Specifications
                    _buildSectionHeader('Microcontroller & Silicon Architecture', Icons.memory_rounded),
                    const SizedBox(height: 8),
                    _buildInfoCard([
                      _buildDetailItem(
                        icon: Icons.developer_board_rounded,
                        label: 'Device Model',
                        value: 'ESP32-WROOM-32 (38-Pin DevKit)',
                        subtitle: 'Dual-core 32-bit Xtensa LX6 microprocessor',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.speed_rounded,
                        label: 'CPU Clock Frequency',
                        value: '240 MHz',
                        subtitle: 'Dynamic frequency scaling with ultra-low power coprocessor',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.storage_rounded,
                        label: 'Internal Memory',
                        value: '520 KB SRAM / 4 MB SPI Flash',
                        subtitle: 'Non-volatile EEPROM partitions for persistent Wi-Fi credentials',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.system_update_rounded,
                        label: 'Firmware Build Version',
                        value: widget.device.firmwareVersion,
                        subtitle: 'ESP-IDF v5.1 / Arduino Core framework',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.sensors_rounded,
                        label: 'Moisture Sensor Pin (ADC)',
                        value: 'GPIO 34 (Analog ADC1_CH6)',
                        subtitle: '12-bit resolution: 0 (dry, 3.3V) to 4095 (submerged, 0V)',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.water_drop_rounded,
                        label: 'Water Pump Relay Pin',
                        value: 'GPIO 23 (Active HIGH)',
                        subtitle: 'Drives Optocoupled Relay / MOSFET for DC Submersible Pump',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.straighten_rounded,
                        label: 'ADC Calibration Thresholds',
                        value: 'Dry: ${IotHybridConnectivityService.dryAdcValue} | Wet: ${IotHybridConnectivityService.wetAdcValue}',
                        subtitle: 'Configured for capacitive soil moisture sensor v1.2 / v2.0',
                      ),
                    ]),
                    const SizedBox(height: 18),

                    // Section 2: Wi-Fi & IP Network Configuration
                    _buildSectionHeader('Wi-Fi & Local Network Topology', Icons.wifi_rounded),
                    const SizedBox(height: 8),
                    _buildInfoCard([
                      _buildDetailItem(
                        icon: Icons.wifi_rounded,
                        label: 'Connected Wi-Fi SSID',
                        value: homeSsid,
                        subtitle: '2.4 GHz IEEE 802.11 b/g/n wireless link',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.router_rounded,
                        label: 'Station IP (Home LAN)',
                        value: stationIp,
                        subtitle: 'Assigned via local home router DHCP reservation',
                        onCopy: () => _copyToClipboard(stationIp, 'Station IP'),
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.wifi_tethering_rounded,
                        label: 'SoftAP Provisioning Gateway',
                        value: '192.168.4.1 (SSID: Plant-IoT-Setup)',
                        subtitle: 'Captive setup portal when disconnected from home Wi-Fi',
                        onCopy: () => _copyToClipboard('192.168.4.1', 'SoftAP Gateway IP'),
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.http_rounded,
                        label: 'Live Telemetry REST Endpoint',
                        value: 'http://$stationIp/telemetry',
                        subtitle: 'Returns live JSON payload (moisture, raw ADC, pump, mode)',
                        onCopy: () => _copyToClipboard('http://$stationIp/telemetry', 'Telemetry URL'),
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Remote Pump Activation Endpoint',
                        value: 'http://$stationIp/pump?action=pulse',
                        subtitle: 'Trigger a calibrated 3-second watering pulse via HTTP GET',
                        onCopy: () => _copyToClipboard('http://$stationIp/pump?action=pulse', 'Pump Endpoint'),
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.settings_ethernet_rounded,
                        label: 'Subnet Mask & DNS Resolution',
                        value: '255.255.255.0 • DNS: 8.8.8.8',
                        subtitle: 'Standard Class C private IPv4 addressing',
                      ),
                    ]),
                    const SizedBox(height: 18),

                    // Section 3: Cloud Telemetry & Alert Dispatch
                    _buildSectionHeader('Cloud Alerting & Remote Dispatch', Icons.cloud_done_rounded),
                    const SizedBox(height: 8),
                    _buildInfoCard([
                      _buildDetailItem(
                        icon: Icons.phone_android_rounded,
                        label: 'Primary Paired Host',
                        value: 'This Device (Authorized Controller)',
                        subtitle: 'Receives instant telemetry push packets and pump controls',
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.notifications_active_rounded,
                        label: 'Push Broker Gateway',
                        value: 'ntfy.sh (High-Reliability Cloud Broker)',
                        subtitle: 'Topic: ${NtfyNotificationService().topic}',
                        onCopy: () => _copyToClipboard(NtfyNotificationService().topic, 'ntfy Topic'),
                      ),
                      _buildDivider(),
                      _buildDetailItem(
                        icon: Icons.speed_rounded,
                        label: 'Ping & Latency Status',
                        value: _pingResult ?? (_currentLatency > 0 ? 'Online (${_currentLatency}ms)' : 'Untested'),
                        subtitle: 'Round-trip response time measured over local Wi-Fi link',
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Diagnostic Actions
                    ElevatedButton.icon(
                      icon: _isPinging
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.network_ping_rounded, size: 18),
                      label: Text(_isPinging ? 'Pinging ESP32 Hardware...' : 'Ping ESP32 (Check Real Latency)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isPinging ? null : _runPing,
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      icon: _isTestingAlert
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.notification_add_rounded, size: 18),
                      label: Text(_isTestingAlert ? 'Sending Test Alert...' : 'Send End-to-End Test Push Notification'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isTestingAlert ? null : _sendTestAlert,
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.wifi_protected_setup_rounded, size: 18),
                      label: const Text('Reconfigure Wi-Fi Network Credentials'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextPrimary,
                        side: const BorderSide(color: kBorderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IotSetupWizardScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Complete Diagnostic Report'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextPrimary,
                        side: const BorderSide(color: kBorderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _copyFullReport,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kPrimaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
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
        children: children,
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                    height: 1.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: kPrimaryColor),
              tooltip: 'Copy',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onCopy,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: kBorderSubtle),
    );
  }
}
