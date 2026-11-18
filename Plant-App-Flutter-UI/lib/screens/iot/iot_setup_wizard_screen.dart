import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../services/iot_provisioning_service.dart';

/// Standalone Isolated Wi-Fi Provisioning Screen
/// Exclusively handles one-time SoftAP configuration to onboard the ESP32
/// chip onto the user's local network and verify its Cloud Firestore registration.
class IotSetupWizardScreen extends StatefulWidget {
  final String? initialDeviceId;

  const IotSetupWizardScreen({super.key, this.initialDeviceId});

  @override
  State<IotSetupWizardScreen> createState() => _IotSetupWizardScreenState();
}

class _IotSetupWizardScreenState extends State<IotSetupWizardScreen> {
  final IotProvisioningService _provisioningService = IotProvisioningService();

  // Wizard Steps:
  // 0: Input Home Wi-Fi Credentials (while phone has internet)
  // 1: Connect to ESP32 SoftAP Hotspot & Transmit
  // 2: Buffering & Cloud Verification
  // 3: Result (Success or Failure)
  int _currentStep = 0;

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController(text: 'esp32_soil_01');
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
    if (widget.initialDeviceId != null && widget.initialDeviceId!.isNotEmpty) {
      _deviceIdController.text = widget.initialDeviceId!;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  /// Step 0 -> Step 1: Pre-setup token in Firestore
  Future<void> _proceedToHotspotStep() async {
    final ssid = _ssidController.text.trim();
    final deviceId = _deviceIdController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your 2.4GHz Home Wi-Fi Network Name (SSID).'),
          backgroundColor: kStatusWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify a Device ID (e.g. esp32_soil_01).'),
          backgroundColor: kStatusWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSendingToSoftAp = true;
      _statusMessage = 'Creating pending session in Cloud Firestore...';
    });

    try {
      _setupToken = await _provisioningService.createPendingProvisioningSession(
        deviceId: deviceId,
        ssid: ssid,
      );
    } catch (_) {
      // If phone already lacks internet or offline, generate local fallback token
      _setupToken = _provisioningService.generateSetupToken();
    }

    if (mounted) {
      setState(() {
        _isSendingToSoftAp = false;
        _currentStep = 1;
      });
    }
  }

  /// Step 1 -> Step 2: Transmit to ESP32 SoftAP & Begin Verification
  Future<void> _transmitCredentialsToSoftAP() async {
    final ssid = _ssidController.text.trim();
    final pass = _passwordController.text.trim();
    final deviceId = _deviceIdController.text.trim();
    final setupToken = _setupToken ?? _provisioningService.generateSetupToken();

    setState(() {
      _isSendingToSoftAp = true;
      _statusMessage = 'Transmitting network credentials to ESP32 at 192.168.4.1...';
    });

    try {
      await _provisioningService.sendCredentialsToSoftAP(
        ssid: ssid,
        password: pass,
        setupToken: setupToken,
        deviceId: deviceId,
      );

      if (!mounted) return;

      // Upon 200 OK, transition to Buffering & Cloud Verification state
      setState(() {
        _isSendingToSoftAp = false;
        _currentStep = 2;
        _countdownSeconds = 20;
        _statusMessage = 'ESP32 shut down SoftAP. Verifying Cloud Firestore connection...';
      });

      _startVerificationCountdown(setupToken, deviceId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingToSoftAp = false);
      _showErrorDialog(
        'Could Not Reach ESP32 Hotspot',
        'Failed to deliver credentials to http://192.168.4.1/provision.\n\n'
        'Please make sure:\n'
        '1. Your ESP32 is powered on and flashing SoftAP mode.\n'
        '2. Your phone is actively connected to the "ESP32_Plant_Irrigation" Wi-Fi network.\n'
        '3. Mobile data is temporarily toggled off if your phone refuses non-internet Wi-Fi.',
      );
    }
  }

  void _startVerificationCountdown(String setupToken, String deviceId) {
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
        _connectedSsid = result.ssid ?? _ssidController.text.trim();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'ESP32 Wi-Fi Setup',
        subtitle: 'One-Time SoftAP Provisioning Handshake',
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
              if (_currentStep == 0) _buildStep0NetworkInput(isDark),
              if (_currentStep == 1) _buildStep1HotspotHandshake(isDark),
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
    final steps = ['Network', 'Hotspot', 'Verification', 'Done'];

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

  /// STEP 0: Input Wi-Fi Credentials
  Widget _buildStep0NetworkInput(bool isDark) {
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
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_rounded, color: kPrimaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Enter Home Network',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Provide 2.4GHz Wi-Fi credentials for the ESP32 chip.',
                      style: TextStyle(fontSize: 11, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2.4GHz Notice Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Requires a 2.4GHz Wi-Fi band. Reconfiguring Wi-Fi preserves your linked botanical specimen, watering logs, and sensor history without overlap.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Device ID input
          const Text('Device ID / Identifier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _deviceIdController,
            decoration: InputDecoration(
              hintText: 'e.g. esp32_soil_01',
              prefixIcon: const Icon(Icons.developer_board_rounded, size: 20),
              filled: true,
              fillColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),

          // Wi-Fi SSID
          const Text('2.4GHz Network Name (SSID)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
              hintText: 'e.g. Home_WiFi_2.4G',
              prefixIcon: const Icon(Icons.wifi_lock_rounded, size: 20),
              filled: true,
              fillColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),

          // Wi-Fi Password
          const Text('Network Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter Wi-Fi password',
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
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSendingToSoftAp ? null : _proceedToHotspotStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSendingToSoftAp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Next: Connect to ESP32 Hotspot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// STEP 1: Connect to SoftAP & Transmit
  Widget _buildStep1HotspotHandshake(bool isDark) {
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
                      '2. Connect to ESP32 Hotspot',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Deliver credentials via local SoftAP handshake.',
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
                _buildInstructionRow('1', 'Turn on your ESP32 module (ensure status LED is active).'),
                const SizedBox(height: 12),
                _buildInstructionRow('2', 'Open phone settings and connect to Wi-Fi: "ESP32_Plant_Irrigation".'),
                const SizedBox(height: 12),
                _buildInstructionRow('3', 'Once connected to the ESP32 hotspot, tap "Deliver Credentials" below.'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payload Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payload Preview for ESP32 (192.168.4.1/provision):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryDark)),
                const SizedBox(height: 4),
                Text('• Target SSID: ${_ssidController.text}', style: const TextStyle(fontSize: 11, color: kTextPrimary)),
                Text('• Device ID: ${_deviceIdController.text}', style: const TextStyle(fontSize: 11, color: kTextPrimary)),
                Text('• Setup Token: ${_setupToken ?? "pending"}', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              OutlinedButton(
                onPressed: _isSendingToSoftAp ? null : () => setState(() => _currentStep = 0),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSendingToSoftAp ? null : _transmitCredentialsToSoftAP,
                  icon: _isSendingToSoftAp
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSendingToSoftAp ? 'Sending...' : 'Deliver Credentials',
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

  /// STEP 2: Buffering & Verification (Phone falls back to normal internet)
  Widget _buildStep2CloudVerification(bool isDark) {
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
            'The ESP32 shut down SoftAP and is connecting to "${_ssidController.text}". '
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
              child: const Icon(Icons.check_circle_rounded, color: kStatusSuccess, size: 52),
            ),
            const SizedBox(height: 16),
            const Text(
              'ESP32 Successfully Provisioned!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kStatusSuccess),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your sensor chip is now connected to your local network and actively syncing with Cloud Firestore.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Metadata card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              ),
              child: Column(
                children: [
                  _buildMetaRow('Device ID', _deviceIdController.text),
                  const Divider(height: 16),
                  _buildMetaRow('Wi-Fi SSID', _connectedSsid ?? _ssidController.text),
                  if (_assignedIp != null) ...[
                    const Divider(height: 16),
                    _buildMetaRow('Assigned Station IP', _assignedIp!),
                  ],
                  const Divider(height: 16),
                  _buildMetaRow('Cloud Sync', 'Active (Firestore)'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Success Action Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Proceed to IoT Dashboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Failure / Timeout State
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kStatusWarning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kStatusWarning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: kStatusWarning, size: 52),
          ),
          const SizedBox(height: 16),
          const Text(
            'Provisioning Timed Out',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage.isNotEmpty
                ? _statusMessage
                : 'The ESP32 failed to establish a connection with the local network within 20 seconds.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceColor : kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Troubleshooting Steps:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('1. Check if the Wi-Fi password was mistyped.', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                Text('2. Ensure the router band is 2.4GHz (ESP32 cannot connect to 5GHz).', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                Text('3. Reconnect your phone to "ESP32_Plant_Irrigation" and retry.', style: TextStyle(fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetToStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Try Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary)),
      ],
    );
  }
}
