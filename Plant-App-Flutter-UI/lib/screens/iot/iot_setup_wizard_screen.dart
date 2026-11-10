import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../components/iot_connection_guide_sheet.dart';
import '../../constants.dart';
import '../../models/iot_connection_mode.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/platform/web_hardware_bridge.dart';

class IotSetupWizardScreen extends StatefulWidget {
  const IotSetupWizardScreen({super.key});

  @override
  State<IotSetupWizardScreen> createState() => _IotSetupWizardScreenState();
}

class _IotSetupWizardScreenState extends State<IotSetupWizardScreen>
    with WidgetsBindingObserver {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();

  // Wizard Steps: 0 = Hotspot Check, 1 = Home Wi-Fi Setup, 2 = Host Pairing & Success
  int _currentStep = 0;

  // Step 1: Hotspot Check State
  bool _isCheckingHotspot = false;
  bool? _isHotspotConnected;
  String? _detectedPhoneSsid;
  String? _hotspotCheckError;
  Map<String, dynamic>? _esp32Telemetry;
  String? _existingSsid;
  String? _existingStationIp;
  bool _isEspWifiConnected = false;
  String? _existingHostName;

  // Step 2: Wi-Fi Provisioning State
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isScanningNetworks = false;
  bool _hasScannedAtLeastOnce = false;
  List<WifiNetwork> _scannedNetworks = [];
  bool _isConnecting = false;
  String? _provisionError;
  String? _assignedStationIp;

  // Step 3: Host Pairing State
  bool _isPairingHost = false;
  bool _pairingCanceled = false;
  String? _pairingCanceledHostName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHotspotConnection();
  }

  @override
  void dispose() {
    WebHardwareBridge.bindProcessToWifi(false);
    WidgetsBinding.instance.removeObserver(this);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentStep == 0) {
      // User may have returned from Wi-Fi settings
      _checkHotspotConnection();
    }
  }

  // =========================================================================
  // STEP 1: HOTSPOT CONNECTION CHECK
  // =========================================================================

  Future<void> _checkHotspotConnection() async {
    if (_isCheckingHotspot) return;
    setState(() {
      _isCheckingHotspot = true;
      _hotspotCheckError = null;
    });

    try {
      // 1. Force process sockets to route through Wi-Fi interface (bypasses Mobile Data on Android)
      await WebHardwareBridge.bindProcessToWifi(true);

      // 2. Query Wi-Fi gateway details and SSID
      final gatewayInfo = await WebHardwareBridge.getWifiGatewayDetails();
      final bool isGatewayEsp = gatewayInfo != null && gatewayInfo['isEspGateway'] == true;

      final phoneSsid = await WebHardwareBridge.getWifiSsid();
      _detectedPhoneSsid = phoneSsid;

      // 3. Direct HTTP probe to ESP32 SoftAP gateway (192.168.4.1)
      bool canReachSoftAp = false;
      for (final ip in ['192.168.4.1', '192.168.1.18']) {
        try {
          final res = await WebHardwareBridge.sendHttpRequest(
            'http://$ip/api/data',
            timeout: const Duration(seconds: 3),
          );
          if (res['success'] == true) {
            canReachSoftAp = true;
            if (res['data'] is Map<String, dynamic>) {
              _esp32Telemetry = res['data'] as Map<String, dynamic>;
              final rawSavedSsid = (_esp32Telemetry?['savedSsid'] ?? _esp32Telemetry?['ssid'] ?? '').toString().trim();
              if (rawSavedSsid.isNotEmpty) {
                _existingSsid = rawSavedSsid;
                if (_ssidController.text.isEmpty) {
                  _ssidController.text = rawSavedSsid;
                }
              }
              final rawStaIp = (_esp32Telemetry?['stationIp'] ?? '').toString().trim();
              if (rawStaIp.isNotEmpty && rawStaIp != '0.0.0.0') {
                _existingStationIp = rawStaIp;
              }
              _isEspWifiConnected = _esp32Telemetry?['wifiConnected'] == true;
              final rawHostName = (_esp32Telemetry?['hostName'] ?? '').toString().trim();
              if (rawHostName.isNotEmpty) {
                _existingHostName = rawHostName;
              }
            }
            break;
          }
        } catch (_) {}
      }

      // 4. Dynamic check: SoftAP reachable, OR Gateway is 192.168.4.1, OR SSID matches ESP32 pattern
      final lowerSsid = (phoneSsid ?? '').toLowerCase();
      final isEsp32Ssid = lowerSsid.contains('smartplant') ||
          lowerSsid.contains('esp32') ||
          lowerSsid.contains('esp-');

      final isConnected = canReachSoftAp || isGatewayEsp || isEsp32Ssid;

      if (mounted) {
        setState(() {
          _isCheckingHotspot = false;
          _isHotspotConnected = isConnected;
          if (!isConnected) {
            _hotspotCheckError =
                'Your phone is not connected to the ESP32 setup hotspot. Please connect to "SmartPlant-ESP32" in your phone\'s Wi-Fi settings.\n\nTip: If Mobile Data is ON, Android may route traffic away from Wi-Fi. Turn off Mobile Data temporarily, or tap "Already Connected / Continue to Step 2" below.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingHotspot = false;
          _isHotspotConnected = false;
          _hotspotCheckError = 'Unable to verify connection: $e';
        });
      }
    }
  }

  // =========================================================================
  // STEP 2: SCAN & PROVISION HOME WI-FI
  // =========================================================================

  void _proceedToStep2() {
    setState(() {
      _currentStep = 1;
    });
    // Only automatically scan if no Wi-Fi is currently saved on the ESP32.
    // If the ESP32 is already connected to a Wi-Fi, background scanning disrupts the radio.
    if (_existingSsid == null || _existingSsid!.isEmpty) {
      _scanNearbyNetworks();
    }
  }

  Future<void> _removeWifiNetwork({bool andReAdd = false}) async {
    final currentSsid = _existingSsid ?? 'configured network';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
              ? 'This will delete "$currentSsid" from the ESP32 first so its 2.4GHz radio is completely unencumbered to scan and connect to your new Wi-Fi or Hotspot right here in Step 2.'
              : 'Are you sure you want to delete and forget the Wi-Fi network "$currentSsid"? The ESP32 will disconnect, return to standalone SoftAP mode ("ESP32-Setup" at 192.168.4.1), and you will return to the main IoT page.',
          style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: andReAdd ? kPrimaryColor : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(andReAdd ? 'Delete & Reconfigure' : 'Delete Wi-Fi', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isConnecting = true;
      _provisionError = null;
    });

    try {
      final res = await _service.resetDeviceWifi('SmartPlant-ESP32');
      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _existingSsid = null;
        _existingStationIp = null;
        _isEspWifiConnected = false;
        _ssidController.clear();
        _passwordController.clear();
        _scannedNetworks = [];
        _hasScannedAtLeastOnce = false;
      });

      if (andReAdd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Previous Wi-Fi deleted! Scanning for surrounding 2.4GHz networks...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        // Retains back at step 2 and initiates clean scan!
        await _scanNearbyNetworks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Wi-Fi network deleted from ESP32.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        // Go back to main IoT page!
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _provisionError = 'Failed to delete Wi-Fi: $e';
        });
      }
    }
  }

  Future<void> _scanNearbyNetworks() async {
    setState(() {
      _isScanningNetworks = true;
      _provisionError = null;
    });

    try {
      final networks = await _service.scanNearbyWifiNetworks();
      if (mounted) {
        // Filter out already configured Wi-Fi, empty SSIDs, and deduplicate
        final configuredSsid = (_existingSsid ?? '').trim().toLowerCase();
        final seen = <String>{};
        final filtered = <WifiNetwork>[];

        for (final net in networks) {
          final clean = net.ssid.trim();
          if (clean.isNotEmpty && clean.toLowerCase() != configuredSsid && !seen.contains(clean.toLowerCase())) {
            seen.add(clean.toLowerCase());
            filtered.add(net);
          }
        }

        setState(() {
          _isScanningNetworks = false;
          _scannedNetworks = filtered;
          _hasScannedAtLeastOnce = true;
        });

        if (filtered.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No other surrounding 2.4GHz Wi-Fi found. (For iPhone Hotspot, turn ON "Maximize Compatibility").'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanningNetworks = false;
          _hasScannedAtLeastOnce = true;
        });
      }
    }
  }

  Future<void> _submitWifiCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    final validation = IotHybridConnectivityService.validateWifiCredentials(ssid, password);
    if (!validation.isSuccess) {
      setState(() {
        _provisionError = validation.message;
      });
      return;
    }

    // Network Overwrite Check: If ESP32 is already configured to another network, ask if they want to overwrite and replace it
    if (_existingSsid != null &&
        _existingSsid!.isNotEmpty &&
        ssid.toLowerCase() != _existingSsid!.toLowerCase()) {
      final shouldOverwrite = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Overwrite Wi-Fi Network?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The ESP32 is currently configured for the Wi-Fi network "$_existingSsid".',
                style: const TextStyle(fontSize: 13, color: kTextPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Current: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        Expanded(child: Text('$_existingSsid', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('New: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        Expanded(child: Text(ssid, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to overwrite and replace the Wi-Fi credentials on the ESP32 with this new network?',
                style: TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Overwrite & Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldOverwrite != true) {
        return;
      }
    }

    setState(() {
      _isConnecting = true;
      _provisionError = null;
    });

    try {
      final res = await _service.provisionDeviceWifi(
        deviceId: 'SmartPlant-ESP32',
        wifiSsid: ssid,
        wifiPassword: password,
      );

      if (!mounted) return;

      if (res.isSuccess) {
        final assignedIp = (res.data?['ip'] ?? '192.168.1.18').toString();
        setState(() {
          _isConnecting = false;
          _assignedStationIp = assignedIp;
          _currentStep = 2; // Advance to Step 3 (Host Pairing)
        });
        _pairDeviceAsHost(ssid, assignedIp);
      } else {
        setState(() {
          _isConnecting = false;
          _provisionError = res.message.isNotEmpty
              ? res.message
              : 'Failed to connect. Please verify your Wi-Fi password and ensure the network is 2.4GHz.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _provisionError =
              'Connection timed out. Check that your Wi-Fi password is correct and your router is operating on 2.4GHz.';
        });
      }
    }
  }

  // =========================================================================
  // STEP 3: HOST PAIRING
  // =========================================================================

  Future<void> _pairDeviceAsHost(String ssid, String stationIp) async {
    setState(() {
      _isPairingHost = true;
      _pairingCanceled = false;
      _pairingCanceledHostName = null;
    });

    try {
      // 1. Detect if ESP32 is already claimed by another host device
      final hostInfo = await _service.detectExistingHost(esp32Data: _esp32Telemetry);

      if (hostInfo.isPaired && !hostInfo.isCurrentPhone && mounted) {
        final shouldOverwrite = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: kPrimaryColor, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Overwrite Host Device?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This ESP32 is currently registered to another host device:',
                  style: TextStyle(fontSize: 13, color: kTextPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phonelink_lock_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Main Host:',
                              style: TextStyle(fontSize: 10, color: Color(0xFF1E40AF)),
                            ),
                            Text(
                              hostInfo.hostName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Overwriting will make this phone the new Main Host for real-time notifications, soil telemetry, and remote watering controls.\n\nDo you want to overwrite and set this phone as the Main Host?',
                  style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.3),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Overwrite Host', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldOverwrite != true) {
          if (mounted) {
            setState(() {
              _isPairingHost = false;
              _pairingCanceled = true;
              _pairingCanceledHostName = hostInfo.hostName;
            });
          }
          return;
        }
      }

      // 2. Claim device as host (sends /api/host to ESP32 & persists locally + in cloud)
      await _service.claimDeviceAsHost(
        deviceId: 'SmartPlant-ESP32',
        name: 'SmartPlant-ESP32',
        homeSsid: ssid,
        stationIp: stationIp,
      );

      // 3. Dispatch native notification banner immediately on device
      await WebHardwareBridge.showNativeNotification(
        title: '🌱 SmartPlant-ESP32 Paired!',
        body: 'This phone is now registered as the Main Host for SmartPlant-ESP32.',
      );

      // 4. Dispatch cloud test alert in background (non-blocking)
      unawaited(
        _service.testConnectionAndNotify(
          customMessage: 'SmartPlant-ESP32 paired! This phone is now the Main Host for alerts & watering.',
        ).catchError((_) => OperationFeedback.fail('', '')),
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isPairingHost = false;
        });
      }
    }
  }

  void _finishWizard() {
    Navigator.pop(context, true);
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: StandardAppBar(
        title: 'IoT Setup Wizard',
        subtitle: 'Step-by-step device provisioning',
        toolbarHeight: 68,
        actions: [
          IconButton(
            tooltip: 'Connection Modes Guide',
            icon: const Icon(Icons.help_outline_rounded, color: kPrimaryColor, size: 22),
            onPressed: () => showIotConnectionModesGuide(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.surfaceBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.borderSubtleColor, width: 1.2),
                ),
                child: Icon(Icons.close_rounded, size: 20, color: context.textPrimaryColor),
              ),
              tooltip: 'Cancel Setup',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper indicator
            _buildStepperHeader(),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kDefaultPadding),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      color: context.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _buildStepCircle(0, '1', 'Hotspot Check'),
          _buildStepDivider(0),
          _buildStepCircle(1, '2', 'Wi-Fi Setup'),
          _buildStepDivider(1),
          _buildStepCircle(2, '3', 'Host Pairing'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int stepIndex, String number, String label) {
    final bool isActive = _currentStep == stepIndex;
    final bool isDone = _currentStep > stepIndex;

    final Color bgColor = isDone
        ? kStatusSuccess
        : isActive
            ? kPrimaryColor
            : Colors.grey.shade300;
    final Color textColor = isDone || isActive ? Colors.white : Colors.grey.shade600;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      number,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? kPrimaryColor : kTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int afterStep) {
    final bool isDone = _currentStep > afterStep;
    return Container(
      width: 24,
      height: 2,
      color: isDone ? kStatusSuccess : Colors.grey.shade300,
      margin: const EdgeInsets.only(bottom: 16),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1HotspotCheck();
      case 1:
        return _buildStep2WifiSetup();
      case 2:
        return _buildStep3HostPairing();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1 WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildStep1HotspotCheck() {
    final bool isConnected = _isHotspotConnected == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Icon & Title
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: (isConnected ? kStatusSuccess : kPrimaryColor).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.wifi_tethering_rounded : Icons.sensors_rounded,
              size: 48,
              color: isConnected ? kStatusSuccess : kPrimaryColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isConnected ? 'ESP32 Hotspot Detected!' : 'Connect to ESP32 Hotspot',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isConnected
              ? 'Your phone is connected to "SmartPlant-ESP32". We can now configure your home Wi-Fi.'
              : 'Before configuring Wi-Fi, your phone must be connected directly to the ESP32 setup network.',
          style: const TextStyle(fontSize: 13, color: kTextSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Connection status card
        if (_isCheckingHotspot) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderSubtleColor),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 14),
                Text('Checking hotspot at 192.168.4.1...', style: TextStyle(fontSize: 13, color: kTextSecondary)),
              ],
            ),
          ),
        ] else if (!isConnected) ...[
          // ERROR CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Not Connected to IoT Hotspot',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hotspotCheckError ?? 'No ESP32 hotspot found at 192.168.4.1.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                ),
                if (_detectedPhoneSsid != null && _detectedPhoneSsid!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Current Phone Network: "$_detectedPhoneSsid"',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Instructions card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderSubtleColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Follow these steps:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                ),
                const SizedBox(height: 12),
                _buildInstructionRow('1', 'Turn on your ESP32 board.'),
                const SizedBox(height: 10),
                _buildInstructionRow('2', 'Open phone Wi-Fi settings and connect to:\nSSID: SmartPlant-ESP32\nPassword: 12345678'),
                const SizedBox(height: 10),
                _buildInstructionRow('3', 'Return to this app and tap "Check Connection Again".'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          ElevatedButton.icon(
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open Wi-Fi Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _service.openWifiSettings(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check Connection Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              side: const BorderSide(color: kPrimaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _checkHotspotConnection,
          ),
          const SizedBox(height: 12),
          // Direct bypass option if phone is connected in settings but OS conceals SSID
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Already Connected? Continue to Step 2 →'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kStatusSuccess,
              side: const BorderSide(color: kStatusSuccess, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _proceedToStep2,
          ),
        ] else ...[
          // SUCCESS CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: kStatusSuccess, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hotspot Verified!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connected to ESP32 gateway at 192.168.4.1.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
                ),
                if (_existingSsid != null && _existingSsid!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '• Configured Wi-Fi: "$_existingSsid"${_isEspWifiConnected ? " (Online)" : ""}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                  ),
                ],
                if (_existingHostName != null && _existingHostName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '• Current Host: "$_existingHostName"',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Proceed to Wi-Fi Setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kStatusSuccess,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _proceedToStep2,
          ),
        ],
      ],
    );
  }

  Widget _buildInstructionRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kPrimaryColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: kTextPrimary, height: 1.3),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2 WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildStep2WifiSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi_rounded, color: kPrimaryColor, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Connect ESP32 to Home Wi-Fi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
              ),
            ),
            IconButton(
              icon: _isScanningNetworks
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Scan Networks',
              onPressed: _isScanningNetworks ? null : _scanNearbyNetworks,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Select your 2.4GHz home Wi-Fi network so the ESP32 can connect to the internet and transmit soil telemetry.',
          style: TextStyle(fontSize: 12, color: kTextSecondary),
        ),
        const SizedBox(height: 16),

        // 2.4GHz Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '2.4GHz Wi-Fi Only: ESP32 hardware does not support 5GHz networks.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Configured Wi-Fi State vs Unconfigured Setup State
        if (_existingSsid != null && _existingSsid!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wifi_lock_rounded, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Configured Wi-Fi: "$_existingSsid"',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                    if (_isEspWifiConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Online',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isEspWifiConnected && _existingStationIp != null
                      ? 'ESP32 is connected to this network at $_existingStationIp. The radio cannot discover other 2.4GHz Wi-Fi networks (including hotspots) while holding an active connection.'
                      : 'ESP32 has "$_existingSsid" saved. The radio cannot discover other 2.4GHz Wi-Fi networks (including hotspots) while holding this configuration.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                ),
                const SizedBox(height: 14),
                // 1. Keep "$_existingSsid"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      'Keep "$_existingSsid"',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _assignedStationIp = _existingStationIp ?? '192.168.1.18';
                      setState(() {
                        _currentStep = 2;
                      });
                      _pairDeviceAsHost(_existingSsid!, _assignedStationIp!);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 2 & 3: Delete Wi-Fi & Delete and Reconfigure Wi-Fi
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
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
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isConnecting ? null : () => _removeWifiNetwork(andReAdd: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_protected_setup_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Delete & Reconfigure Wi-Fi',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: _isConnecting ? null : () => _removeWifiNetwork(andReAdd: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          // Prominent Scan for Available Wi-Fi Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isScanningNetworks ? null : _scanNearbyNetworks,
              icon: _isScanningNetworks
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.radar_rounded, size: 18),
              label: Text(
                _isScanningNetworks ? 'Scanning 2.4GHz Networks...' : 'Scan for Available Wi-Fi Networks',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryColor,
                side: const BorderSide(color: kPrimaryColor, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Scanned Networks List
          if (_isScanningNetworks) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 10),
                    Text('Scanning for 2.4GHz networks nearby...', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                  ],
                ),
              ),
            ),
          ] else if (_scannedNetworks.isNotEmpty) ...[
            Text(
              'Available Networks Found (${_scannedNetworks.length}) - Tap to select:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderSubtleColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _scannedNetworks.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kBorderSubtle),
                itemBuilder: (ctx, idx) {
                  final net = _scannedNetworks[idx];
                  final isSelected = _ssidController.text == net.ssid;
                  final is5G = IotHybridConnectivityService.isPotential5GhzSsid(net.ssid);

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      net.signalStrength > 60 ? Icons.wifi_rounded : Icons.wifi_2_bar_rounded,
                      color: isSelected ? kPrimaryColor : kTextSecondary,
                      size: 18,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            net.ssid,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? kPrimaryColor : kTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (is5G) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('5G', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    trailing: Text(
                      '${net.signalStrength}%',
                      style: const TextStyle(fontSize: 11, color: kTextSecondary),
                    ),
                    selected: isSelected,
                    selectedTileColor: kPrimaryColor.withValues(alpha: 0.08),
                    onTap: () {
                      setState(() {
                        _ssidController.text = net.ssid;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_hasScannedAtLeastOnce && !_isScanningNetworks) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No other 2.4GHz Wi-Fi networks detected nearby.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• If connecting to iPhone Hotspot, turn ON "Maximize Compatibility" in iPhone Settings > Personal Hotspot.\n'
                    '• Keep the "Personal Hotspot" screen open on your phone while searching.\n'
                    '• You can also enter your Wi-Fi name and password manually below.',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // iPhone Hotspot helper tip banner
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_iphone_rounded, size: 16, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'iPhone Hotspot Tip: Turn ON "Maximize Compatibility" in iPhone Settings > Personal Hotspot to enable 2.4GHz Wi-Fi broadcast.',
                    style: TextStyle(fontSize: 10.5, color: Colors.blue.shade900, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // SSID Field
          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
              labelText: 'Wi-Fi Network Name (SSID)',
              hintText: 'e.g. My-Hotspot-2.4GHz',
              prefixIcon: const Icon(Icons.wifi_rounded, size: 20),
              filled: true,
              fillColor: context.surfaceBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderSubtleColor)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Password Field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Wi-Fi Password',
              hintText: 'Enter WPA2/WPA3 password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: context.surfaceBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderSubtleColor)),
            ),
          ),
          const SizedBox(height: 14),

          // Error message if any
          if (_provisionError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connection Failed',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _provisionError!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Submit Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isConnecting ? null : _submitWifiCredentials,
            child: _isConnecting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Connecting ESP32 to Wi-Fi (up to 20s)...'),
                    ],
                  )
                : const Text('Connect IoT to Wi-Fi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3 WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildStep3HostPairing() {
    if (_isPairingHost) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 60),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 20),
          Text(
            'Pairing ESP32 to this phone as Main Host...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Registering device credentials & establishing global alert bridge...',
            style: TextStyle(fontSize: 12, color: kTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_pairingCanceled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 60, color: Color(0xFFD97706)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Host Pairing Canceled',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The ESP32 remains paired to "${_pairingCanceledHostName ?? "its current host device"}". This phone was not set as the Main Host.',
            style: const TextStyle(fontSize: 13, color: kTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderSubtleColor),
            ),
            child: Column(
              children: [
                _buildSummaryRow(Icons.developer_board_rounded, 'Device', 'SmartPlant-ESP32'),
                const Divider(height: 20, color: kBorderSubtle),
                _buildSummaryRow(Icons.phonelink_lock_rounded, 'Current Host', _pairingCanceledHostName ?? 'Existing Device'),
                const Divider(height: 20, color: kBorderSubtle),
                _buildSummaryRow(Icons.wifi_rounded, 'Wi-Fi Network', _ssidController.text.isNotEmpty ? _ssidController.text : (_existingSsid ?? 'Not Configured')),
                const Divider(height: 20, color: kBorderSubtle),
                _buildSummaryRow(Icons.router_rounded, 'IP Address', _assignedStationIp ?? _existingStationIp ?? '192.168.1.18'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Pairing Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final targetSsid = _ssidController.text.isNotEmpty ? _ssidController.text : (_existingSsid ?? 'Home Wi-Fi');
              final targetIp = _assignedStationIp ?? _existingStationIp ?? '192.168.1.18';
              _pairDeviceAsHost(targetSsid, targetIp);
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextSecondary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Exit to IoT Hub', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: kStatusSuccess.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 60, color: kStatusSuccess),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'IoT Successfully Paired! 🎉',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'This phone is now registered as the Main Host for real-time notifications, soil moisture tracking, and remote watering controls.',
          style: TextStyle(fontSize: 13, color: kTextSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Pairing Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderSubtleColor),
          ),
          child: Column(
            children: [
              _buildSummaryRow(Icons.developer_board_rounded, 'Device Name', 'SmartPlant-ESP32'),
              const Divider(height: 20, color: kBorderSubtle),
              _buildSummaryRow(Icons.phonelink_setup_rounded, 'Host Role', 'This Phone (Main Host 🟢)'),
              const Divider(height: 20, color: kBorderSubtle),
              _buildSummaryRow(Icons.wifi_rounded, 'Connected Wi-Fi', _ssidController.text),
              const Divider(height: 20, color: kBorderSubtle),
              _buildSummaryRow(Icons.router_rounded, 'Assigned IP', _assignedStationIp ?? '192.168.1.18'),
              const Divider(height: 20, color: kBorderSubtle),
              _buildSummaryRow(Icons.notifications_active_rounded, 'Global Push Channel', 'urbangreen_esp32_alerts'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Reconnect Phone to Home Wi-Fi prompt
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Next Step: Reconnect Your Phone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Your phone may still be connected to "SmartPlant-ESP32". Reconnect your phone to "${_ssidController.text}" or use Mobile Data to communicate with your sensor.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.3),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Open Wi-Fi Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _service.openWifiSettings(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Finish button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kStatusSuccess,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _finishWizard,
          child: const Text('Finish & Go to IoT Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kPrimaryColor),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
