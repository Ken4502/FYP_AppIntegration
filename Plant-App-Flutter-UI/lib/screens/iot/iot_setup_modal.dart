import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/platform/web_hardware_bridge.dart';

/// Native In-App Wi-Fi Configuration Modal
///
/// Verifies ESP32 network connectivity (http://192.168.4.1/api/data) before unlocking
/// native in-app Wi-Fi network scanning, credential input, and router connection.
class Esp32CaptivePortalSetupModal extends StatefulWidget {
  const Esp32CaptivePortalSetupModal({super.key});

  static Future<IotDevice?> show(BuildContext context) {
    return showModalBottomSheet<IotDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const Esp32CaptivePortalSetupModal(),
    );
  }

  @override
  State<Esp32CaptivePortalSetupModal> createState() => _Esp32CaptivePortalSetupModalState();
}

class _Esp32CaptivePortalSetupModalState extends State<Esp32CaptivePortalSetupModal> {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();

  bool _isCheckingConnection = false;
  bool _isEsp32Connected = false;
  Map<String, dynamic>? _espData;

  // Wi-Fi Form Controllers
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isScanningWifi = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  List<String> _scannedSsids = [];

  @override
  void initState() {
    super.initState();
    _checkEsp32Connection();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  /// Verification Guard: Checks if phone is connected to ESP32 network
  Future<void> _checkEsp32Connection() async {
    if (!mounted) return;
    setState(() {
      _isCheckingConnection = true;
    });

    try {
      final res = await WebHardwareBridge.sendHttpRequest(
        'http://192.168.4.1/api/data',
        timeout: const Duration(milliseconds: 1800),
      );

      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isEsp32Connected = true;
            _espData = data;
            _isCheckingConnection = false;
          });
          _scanNearbyWifiFromEsp32();
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isEsp32Connected = false;
        _isCheckingConnection = false;
      });
    }
  }

  Future<void> _scanNearbyWifiFromEsp32() async {
    if (!_isEsp32Connected || _isScanningWifi) return;
    setState(() {
      _isScanningWifi = true;
    });

    try {
      final res = await WebHardwareBridge.sendHttpRequest(
        'http://192.168.4.1/api/wifi/scan',
        timeout: const Duration(seconds: 4),
      );

      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;
        if (data.containsKey('networks') && data['networks'] is List) {
          final List netList = data['networks'] as List;
          final Set<String> ssids = {};
          for (final item in netList) {
            if (item is Map && item['ssid'] != null) {
              final s = item['ssid'].toString().trim();
              if (s.isNotEmpty) ssids.add(s);
            }
          }
          if (mounted) {
            setState(() {
              _scannedSsids = ssids.toList();
              if (_scannedSsids.isNotEmpty && _ssidController.text.isEmpty) {
                _ssidController.text = _scannedSsids.first;
              }
              _isScanningWifi = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isScanningWifi = false;
      });
    }
  }

  Future<void> _submitNativeWifiConfig() async {
    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim();

    final validation = IotHybridConnectivityService.validateWifiCredentials(ssid, pass);
    if (!validation.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${validation.message}'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (IotHybridConnectivityService.isPotential5GhzSsid(ssid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Warning: ESP32 only supports 2.4GHz Wi-Fi bands. If this network is 5GHz-only, connection will fail.'),
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final feedback = await _service.provisionDeviceWifi(
        deviceId: 'SmartPlant-ESP32',
        wifiSsid: ssid,
        wifiPassword: pass,
      );

      if (feedback.isSuccess) {
        final device = IotDevice(
          id: 'SmartPlant-ESP32',
          name: 'SmartPlant-ESP32',
          isWifiConnected: true,
          wifiSsid: ssid,
          supportsMoistureSensor: true,
          supportsAutoWater: true,
          firmwareVersion: 'v3.2.0-DualCloud-ntfy',
        );

        await _service.connectIotDevice(device);

        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${feedback.message}'),
              backgroundColor: kPrimaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, device);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${feedback.message}'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Configuration error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.settings_remote_rounded,
                    color: kPrimaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESP32 Wi-Fi Setup',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Stage 1: Provisioning 2.4GHz Wi-Fi',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // CONNECTION GUARD BANNER
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isEsp32Connected ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isEsp32Connected ? Colors.green.shade300 : Colors.amber.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEsp32Connected ? Icons.check_circle_rounded : Icons.wifi_find_rounded,
                    color: _isEsp32Connected ? Colors.green.shade800 : Colors.amber.shade900,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCheckingConnection
                              ? 'Checking Connection to ESP32...'
                              : (_isEsp32Connected
                                  ? 'ESP32 Connected ("ESP32-Setup" at 192.168.4.1)'
                                  : 'Not Connected to "ESP32-Setup" Wi-Fi'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isEsp32Connected ? Colors.green.shade900 : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEsp32Connected
                              ? 'MAC: ${_espData?['mac'] ?? '8C:94:DF:6D:8B:98'} • Direct REST API Communication Verified ✅'
                              : 'Connect phone Wi-Fi to "ESP32-Setup" hotspot to unlock in-app configuration.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                  if (_isCheckingConnection)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Re-check Connection',
                      onPressed: _checkEsp32Connection,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // IF NOT CONNECTED TO ESP32: SHOW INSTRUCTIONS & SYSTEM WI-FI BUTTON
            if (!_isEsp32Connected) ...[
              const Text(
                'Connect to ESP32 Hotspot First:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Swipe down and open System Wi-Fi settings.\n2. Connect your phone to "ESP32-Setup" (no password needed).\n3. Return to this screen and tap "Re-check Connection".',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Open System Wi-Fi Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => WebHardwareBridge.openWifiSettings(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Check Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _checkEsp32Connection,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // UNLOCKED NATIVE CONFIGURATION FORM
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Home 2.4GHz Wi-Fi Network:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                  ),
                  if (_isScanningWifi)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor))
                  else
                    InkWell(
                      onTap: _scanNearbyWifiFromEsp32,
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 14, color: kPrimaryColor),
                          SizedBox(width: 4),
                          Text('Rescan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Scanned SSIDs Chip Dropdown / Quick Select
              if (_scannedSsids.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _scannedSsids.map((s) {
                      final bool isSelected = _ssidController.text == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(s, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                          selected: isSelected,
                          selectedColor: kPrimaryColor.withValues(alpha: 0.15),
                          onSelected: (_) {
                            setState(() {
                              _ssidController.text = s;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),

              // SSID Text Field
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Network Name (SSID)',
                  hintText: 'e.g. Home-2.4Ghz',
                  prefixIcon: const Icon(Icons.wifi_rounded, color: kPrimaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Password Text Field
              TextField(
                controller: _passController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Password',
                  hintText: 'Type your Wi-Fi password (min 8 chars)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: kPrimaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Connect Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.wifi_protected_setup_rounded),
                  label: Text(
                    _isSubmitting ? 'Transmitting & Testing Connection (15s)...' : 'Connect ESP32 to Home Wi-Fi',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _isSubmitting ? null : _submitNativeWifiConfig,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
