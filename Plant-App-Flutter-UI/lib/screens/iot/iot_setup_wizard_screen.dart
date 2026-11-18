import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../services/iot_provisioning_service.dart';

/// Standalone Isolated Wi-Fi Provisioning Screen
/// Seamlessly detects the ESP32 setup hotspot, requests the chip to scan
/// nearby 2.4GHz Wi-Fi networks, and transmits credentials without requiring
/// the user to manually invent or type a Device ID.
class IotSetupWizardScreen extends StatefulWidget {
  final String? initialDeviceId;

  const IotSetupWizardScreen({super.key, this.initialDeviceId});

  @override
  State<IotSetupWizardScreen> createState() => _IotSetupWizardScreenState();
}

class _IotSetupWizardScreenState extends State<IotSetupWizardScreen> {
  final IotProvisioningService _provisioningService = IotProvisioningService();

  // Wizard Steps:
  // 0: Detect ESP32 Hotspot Connection
  // 1: Scan & Select 2.4GHz Wi-Fi Network (+ Enter Password)
  // 2: Buffering & Cloud Verification
  // 3: Result (Success or Failure)
  int _currentStep = 0;

  // Hotspot Detection & Hardware Metadata
  bool _isCheckingHotspot = false;
  String? _detectedDeviceId;
  String? _hotspotState;
  Timer? _autoDetectionTimer;

  // Wi-Fi Scan & Selection State
  bool _isScanningWifi = false;
  List<Map<String, dynamic>> _scannedNetworks = [];
  String? _selectedSsid;
  bool _isManualSsid = false;
  final TextEditingController _manualSsidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Provisioning execution state
  String? _setupToken;
  bool _isSendingToSoftAp = false;
  int _countdownSeconds = 20;
  Timer? _countdownTimer;

  bool _isSuccess = false;
  String _statusMessage = '';
  String? _assignedIp;
  String? _connectedSsid;

  @override
  void initState() {
    super.initState();
    _detectedDeviceId = widget.initialDeviceId;
    _startHotspotAutoDetection();
  }

  @override
  void dispose() {
    _autoDetectionTimer?.cancel();
    _countdownTimer?.cancel();
    _manualSsidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Automatically polls the ESP32 SoftAP at 192.168.4.1/status
  void _startHotspotAutoDetection() {
    _checkHotspotNow();
    _autoDetectionTimer?.cancel();
    _autoDetectionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_currentStep == 0 && !_isCheckingHotspot) {
        _checkHotspotNow();
      }
    });
  }

  Future<void> _checkHotspotNow() async {
    if (!mounted || _isCheckingHotspot) return;
    setState(() => _isCheckingHotspot = true);

    try {
      final status = await _provisioningService.checkHotspotStatus(
        timeout: const Duration(seconds: 2),
      );

      if (!mounted) return;

      if (status != null) {
        final devId = status['deviceId'] as String?;
        final state = status['state'] as String?;

        setState(() {
          _isCheckingHotspot = false;
          _detectedDeviceId = (devId != null && devId.isNotEmpty) ? devId : (_detectedDeviceId ?? 'SmartPlant-ESP32');
          _hotspotState = state;
          _currentStep = 1; // Advance directly to Wi-Fi selection!
        });

        _autoDetectionTimer?.cancel();
        // Trigger initial Wi-Fi scan via ESP32
        _triggerWifiScan();
      } else {
        setState(() => _isCheckingHotspot = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingHotspot = false);
    }
  }

  /// Ask the ESP32 to scan for nearby 2.4GHz Wi-Fi networks
  Future<void> _triggerWifiScan() async {
    if (!mounted || _isScanningWifi) return;
    setState(() {
      _isScanningWifi = true;
      _scannedNetworks = [];
    });

    try {
      final networks = await _provisioningService.scanWifiNetworks(
        timeout: const Duration(seconds: 8),
      );

      if (!mounted) return;

      setState(() {
        _scannedNetworks = networks;
        _isScanningWifi = false;
        if (networks.isNotEmpty && _selectedSsid == null) {
          _selectedSsid = networks.first['ssid'] as String?;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isScanningWifi = false);
    }
  }

  /// Transmit selected credentials to ESP32 SoftAP & begin verification
  Future<void> _transmitCredentialsToSoftAP() async {
    final ssid = _isManualSsid ? _manualSsidController.text.trim() : (_selectedSsid ?? '').trim();
    final pass = _passwordController.text.trim();
    final deviceId = _detectedDeviceId ?? (widget.initialDeviceId ?? 'SmartPlant-ESP32');

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a 2.4GHz Wi-Fi Network Name (SSID).'),
          backgroundColor: kStatusWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSendingToSoftAp = true;
      _statusMessage = 'Transmitting network credentials to ESP32...';
    });

    // Create pending session in Firestore if online, or generate fallback token
    try {
      _setupToken = await _provisioningService.createPendingProvisioningSession(
        deviceId: deviceId,
        ssid: ssid,
      );
    } catch (_) {
      _setupToken = _provisioningService.generateSetupToken();
    }

    if (!mounted) return;
    _showConnectingDialog(context, ssid);

    try {
      await _provisioningService.sendCredentialsToSoftAP(
        ssid: ssid,
        password: pass,
        setupToken: _setupToken!,
        deviceId: deviceId,
      );

      // Dismiss connecting dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      // Upon 200 OK, transition to Buffering & Cloud Verification state
      setState(() {
        _isSendingToSoftAp = false;
        _currentStep = 2;
        _countdownSeconds = 20;
        _statusMessage = 'ESP32 shut down SoftAP. Verifying Cloud Firestore connection...';
      });

      _startVerificationCountdown(_setupToken!, deviceId, ssid);
    } catch (e) {
      // Dismiss connecting dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      setState(() => _isSendingToSoftAp = false);
      final errMsg = e.toString().replaceFirst('Exception: ', '');
      _showErrorDialog(
        'Wi-Fi Connection Failed',
        '$errMsg\n\nPlease check your Wi-Fi password and try again. Your phone is still connected to the ESP32 setup hotspot.',
      );
    }
  }

  void _showConnectingDialog(BuildContext context, String ssid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? kDarkCardColor : kSurfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verifying Wi-Fi Connection...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ESP32 is testing connection to\n"$ssid"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kTextSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock_rounded, size: 16, color: kPrimaryColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Handshaking with router & verifying password...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '⚡ Fast test (takes ~2s). SoftAP stays active.',
                  style: TextStyle(fontSize: 11, color: kPrimaryColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startVerificationCountdown(String setupToken, String deviceId, String ssid) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        }
      });
    });

    _provisioningService.verifyConnectionInCloud(
      setupToken: setupToken,
      deviceId: deviceId,
      timeout: const Duration(seconds: 20),
    ).then((result) {
      _countdownTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _currentStep = 3;
        _isSuccess = result.isSuccess;
        _statusMessage = result.message;
        _assignedIp = result.ip;
        _connectedSsid = result.ssid ?? ssid;
      });
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: kStatusWarning),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetToStart() {
    _countdownTimer?.cancel();
    setState(() {
      _currentStep = 0;
      _isSendingToSoftAp = false;
      _isSuccess = false;
      _statusMessage = '';
      _scannedNetworks = [];
      _selectedSsid = null;
    });
    _startHotspotAutoDetection();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'ESP32 Wi-Fi Setup',
        subtitle: 'Auto-Discovery & SoftAP Provisioning',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Restart Wizard',
            onPressed: _resetToStart,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wizard Progress Header
              _buildProgressIndicator(isDark),
              const SizedBox(height: 24),

              // Step Content
              if (_currentStep == 0) _buildStep0HotspotDetection(isDark),
              if (_currentStep == 1) _buildStep1WifiSelection(isDark),
              if (_currentStep == 2) _buildStep2CloudVerification(isDark),
              if (_currentStep == 3) _buildStep3Result(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Visual 4-Step Indicator
  Widget _buildProgressIndicator(bool isDark) {
    final steps = ['Hotspot', 'Wi-Fi Scan', 'Verifying', 'Done'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep || (_currentStep == 3 && _isSuccess);

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? kStatusSuccess
                        : (isActive ? kPrimaryColor : Colors.grey.shade300),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? kPrimaryColor
                          : (isCompleted ? kStatusSuccess : Colors.grey),
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 12,
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// STEP 0: Auto-Detect Connection to ESP32 Hotspot
  Widget _buildStep0HotspotDetection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Connect to ESP32 Hotspot',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Connect your phone to the probe\'s setup Wi-Fi.',
                      style: TextStyle(fontSize: 11, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Checklist
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceColor : kBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructionRow('1', 'Turn on your ESP32 module (ensure power LED is active).'),
                const SizedBox(height: 12),
                _buildInstructionRow('2', 'Open phone Wi-Fi Settings and connect to network:\n"ESP32_Plant_Irrigation" (Open / No password).'),
                const SizedBox(height: 12),
                _buildInstructionRow('3', 'Return to this app. Hotspot connection will be auto-detected!'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Hotspot Detection Status Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isCheckingHotspot
                  ? kPrimaryColor.withValues(alpha: 0.08)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isCheckingHotspot
                    ? kPrimaryColor.withValues(alpha: 0.3)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: _isCheckingHotspot
                      ? const CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor)
                      : const Icon(Icons.search_rounded, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isCheckingHotspot
                        ? 'Searching for ESP32 at 192.168.4.1...'
                        : 'Waiting for phone to connect to "ESP32_Plant_Irrigation"...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isCheckingHotspot ? kPrimaryDark : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Manual check button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCheckingHotspot ? null : _checkHotspotNow,
              icon: _isCheckingHotspot
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.wifi_find_rounded, size: 20),
              label: Text(
                _isCheckingHotspot ? 'Checking Connection...' : 'Check Hotspot Connection',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// STEP 1: Scanned Wi-Fi Networks & Password Entry
  Widget _buildStep1WifiSelection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detected Device Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kStatusSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kStatusSuccess.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: kStatusSuccess, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connected to Hotspot • ${_detectedDeviceId ?? "ESP32 Device"}${_hotspotState != null ? " ($_hotspotState)" : ""}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kStatusSuccess),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('2. Select Wi-Fi Network', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Choose a 2.4GHz network for the ESP32.', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                ],
              ),
              IconButton(
                tooltip: 'Scan Again',
                icon: _isScanningWifi
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded, color: kPrimaryColor),
                onPressed: _isScanningWifi ? null : _triggerWifiScan,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scanned Wi-Fi List
          if (_isScanningWifi) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: kPrimaryColor),
                  SizedBox(height: 12),
                  Text('ESP32 is scanning nearby 2.4GHz networks...', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
              ),
            ),
          ] else if (_scannedNetworks.isEmpty && !_isManualSsid) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('No networks discovered by ESP32.', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Scan Again'),
                    onPressed: _triggerWifiScan,
                  ),
                ],
              ),
            ),
          ] else if (!_isManualSsid) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _scannedNetworks.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                itemBuilder: (ctx, idx) {
                  final net = _scannedNetworks[idx];
                  final ssid = (net['ssid'] as String?) ?? '';
                  final rssi = (net['rssi'] as num?)?.toInt() ?? -70;
                  final secure = (net['secure'] as bool?) ?? true;
                  final isSelected = (_selectedSsid == ssid);

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      rssi >= -65 ? Icons.wifi_rounded : (rssi >= -75 ? Icons.wifi_2_bar_rounded : Icons.wifi_1_bar_rounded),
                      color: isSelected ? kPrimaryColor : Colors.grey,
                      size: 20,
                    ),
                    title: Text(
                      ssid,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                        color: isSelected ? kPrimaryColor : (isDark ? kDarkTextPrimary : kTextPrimary),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (secure) const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        if (isSelected) const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 18),
                      ],
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedSsid = ssid;
                        _isManualSsid = false;
                      });
                    },
                  );
                },
              ),
            ),
          ],

          // Toggle Manual SSID Input
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _isManualSsid = !_isManualSsid);
              },
              child: Text(
                _isManualSsid ? 'Select from Scanned Networks' : 'Or Enter Wi-Fi Name Manually',
                style: const TextStyle(fontSize: 11, color: kPrimaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_isManualSsid) ...[
            const Text('Manual Wi-Fi SSID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _manualSsidController,
              decoration: InputDecoration(
                hintText: 'e.g. MyHomeWiFi_2.4G',
                prefixIcon: const Icon(Icons.wifi_lock_rounded, size: 20),
                filled: true,
                fillColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Password Input
          const SizedBox(height: 6),
          Text(
            'Password for "${_isManualSsid ? _manualSsidController.text : (_selectedSsid ?? 'Selected Wi-Fi')}"',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter Wi-Fi password (leave empty if open)',
              prefixIcon: const Icon(Icons.key_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),

          // Connect Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSendingToSoftAp ? null : _transmitCredentialsToSoftAP,
              icon: _isSendingToSoftAp
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSendingToSoftAp ? 'Connecting...' : 'Connect ESP32 to Wi-Fi',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: kPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }

  /// STEP 2: Buffering & Verification
  Widget _buildStep2CloudVerification(bool isDark) {
    final targetSsid = _isManualSsid ? _manualSsidController.text : (_selectedSsid ?? 'configured Wi-Fi');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 3.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Verifying Cloud Connection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The ESP32 shut down SoftAP and is connecting to "$targetSsid". '
            'Listening to Cloud Firestore for status confirmation...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Countdown Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: kPrimaryColor),
                const SizedBox(width: 6),
                Text(
                  'Verification Timeout: ${_countdownSeconds}s',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: kTextSecondary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  /// STEP 3: Final Result (Success or Timeout/Failure)
  Widget _buildStep3Result(bool isDark) {
    if (_isSuccess) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? kDarkCardColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kStatusSuccess.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kStatusSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: kStatusSuccess, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'ESP32 Connected Successfully! 🎉',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your sensor probe is registered in Cloud Firestore. Automatic watering is turned OFF by default for safety until you configure it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Connection Details Pill
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Device ID', _detectedDeviceId ?? 'SmartPlant-ESP32'),
                  const Divider(height: 16),
                  _buildDetailRow('Connected Wi-Fi', _connectedSsid ?? 'Home Network'),
                  if (_assignedIp != null) ...[
                    const Divider(height: 16),
                    _buildDetailRow('Local Station IP', _assignedIp!),
                  ],
                  const Divider(height: 16),
                  _buildDetailRow('Watering Mode', 'MANUAL (Off by default)'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.dashboard_rounded, size: 18),
                label: const Text('Open IoT Dashboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Failure / Timeout View
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kStatusDanger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kStatusDanger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: kStatusDanger, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connection Timed Out',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage.isNotEmpty
                ? _statusMessage
                : 'The ESP32 failed to reach the router or Cloud Firestore after 20 seconds. It will automatically reopen its grace hotspot.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetToStart,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary)),
      ],
    );
  }
}
