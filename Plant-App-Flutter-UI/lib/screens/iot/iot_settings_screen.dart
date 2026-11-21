import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../models/plant_model.dart';
import '../../services/iot_firestore_service.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/plant_service.dart';
import '../../services/weather_service.dart';
import '../../services/low_moisture_decision_service.dart';
import 'low_moisture_decision_screen.dart';
import 'iot_setup_wizard_screen.dart';

/// Dedicated IoT & Plant Care Settings Screen
/// Groups all notification, watering mode, environment, and hardware configuration options.
class IotSettingsScreen extends StatefulWidget {
  final IotDevice device;
  final Plant? plant;
  final WeatherData? weatherData;

  const IotSettingsScreen({
    super.key,
    required this.device,
    this.plant,
    this.weatherData,
  });

  @override
  State<IotSettingsScreen> createState() => _IotSettingsScreenState();
}

class _IotSettingsScreenState extends State<IotSettingsScreen> {
  final IotFirestoreService _firestoreService = IotFirestoreService();
  final IotHybridConnectivityService _connectivityService = IotHybridConnectivityService();
  final PlantService _plantService = PlantService();

  late bool _isIndoor;
  late bool _autoWaterEnabled;
  late bool _lowMoistureAlertEnabled;
  late bool _dynamicMoistureAlertEnabled;
  late int _customMoistureThreshold;
  late bool _dailyWeatherNotificationEnabled;
  bool _activeHigh = true;
  bool _isTestingPing = false;

  @override
  void initState() {
    super.initState();
    _isIndoor = widget.device.isIndoor;
    _autoWaterEnabled = widget.device.autoWaterEnabled;
    _lowMoistureAlertEnabled = widget.device.lowMoistureAlertEnabled;
    _dynamicMoistureAlertEnabled = widget.device.dynamicMoistureAlertEnabled;
    _customMoistureThreshold = widget.device.lowMoistureThreshold;
    _dailyWeatherNotificationEnabled = widget.device.dailyWeatherNotificationEnabled;
  }

  Future<void> _toggleEnvironment(bool indoor) async {
    if (_isIndoor == indoor) return;
    setState(() => _isIndoor = indoor);
    widget.device.isIndoor = indoor;

    await _firestoreService.updateDeviceEnvironment(widget.device.id, isIndoor: indoor);

    // Keep assigned plant in sync if present
    final Plant? plant = _plantService.getPlantForDevice(widget.device.id);
    if (plant != null && plant.isIndoor != indoor) {
      final updated = plant.copyWith(environment: indoor ? 'indoor' : 'outdoor');
      _plantService.updatePlant(updated);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            indoor
                ? '🏠 Environment set to Indoor (Sheltered • Fixed 65% target)'
                : '🌳 Environment set to Outdoor (Weather-adaptive moisture target)',
          ),
          backgroundColor: indoor ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleWateringMode(bool auto) async {
    if (_autoWaterEnabled == auto) return;
    setState(() => _autoWaterEnabled = auto);
    widget.device.autoWaterEnabled = auto;

    await _firestoreService.setWateringMode(widget.device.id, autoWaterEnabled: auto);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? '🤖 Switched to Autonomous Auto-Watering Mode.'
                : '👆 Switched to Manual Decision Mode.',
          ),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleLowMoistureAlerts(bool enabled) async {
    setState(() => _lowMoistureAlertEnabled = enabled);
    widget.device.lowMoistureAlertEnabled = enabled;

    await _firestoreService.updateNotificationSettings(
      widget.device.id,
      lowMoistureAlertEnabled: enabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? '🔔 Soil moisture notifications enabled.'
              : '🔕 Soil moisture notifications muted.'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setAlertThresholdMode(bool dynamicMode) async {
    setState(() => _dynamicMoistureAlertEnabled = dynamicMode);
    widget.device.dynamicMoistureAlertEnabled = dynamicMode;

    await _firestoreService.updateNotificationSettings(
      widget.device.id,
      dynamicMoistureAlertEnabled: dynamicMode,
    );
  }

  Future<void> _setCustomThreshold(int val) async {
    setState(() => _customMoistureThreshold = val);
    widget.device.lowMoistureThreshold = val;

    await _firestoreService.updateNotificationSettings(
      widget.device.id,
      customMoistureAlertThreshold: val,
    );
  }

  Future<void> _toggleDailyWeatherNotification(bool enabled) async {
    setState(() => _dailyWeatherNotificationEnabled = enabled);
    widget.device.dailyWeatherNotificationEnabled = enabled;

    await _firestoreService.updateNotificationSettings(
      widget.device.id,
      dailyWeatherNotificationEnabled: enabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? '☀️ Daily 9:00 AM Weather Briefing enabled.'
              : 'Daily weather briefing disabled.'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleRelayPolarity() async {
    await _connectivityService.toggleRelayInvert();
    if (mounted) {
      setState(() => _activeHigh = !_activeHigh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Relay Polarity: ${_activeHigh ? "Active HIGH (3.3V)" : "Active LOW (0V)"}'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeviceIgnorePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? kDarkCardColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const Row(
                  children: [
                    Icon(Icons.snooze_rounded, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Text(
                      'Snooze Soil Alerts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Temporarily pause low-moisture alerts for this probe:',
                  style: TextStyle(fontSize: 12, color: kTextSecondary),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: kPrimaryColor),
                  title: const Text('Mute for 12 Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onTap: () {
                    setState(() => widget.device.ignoreAlertFor(const Duration(hours: 12)));
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: kPrimaryColor),
                  title: const Text('Mute for 24 Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onTap: () {
                    setState(() => widget.device.ignoreAlertFor(const Duration(hours: 24)));
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_rounded, color: Colors.red),
                  title: const Text('Mute Always (Until Un-muted)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                  onTap: () {
                    setState(() => widget.device.ignoreAlertAlways());
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runPing() async {
    setState(() => _isTestingPing = true);
    final sw = Stopwatch()..start();
    final dev = await _firestoreService.getDevice(widget.device.id);
    sw.stop();
    if (mounted) {
      setState(() => _isTestingPing = false);
      final isOnline = dev != null && dev.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline
              ? '✅ Device heartbeat verified in Cloud Firestore (${sw.elapsedMilliseconds}ms).'
              : '⚠️ Device is in standby or offline.'),
          backgroundColor: isOnline ? kStatusSuccess : kStatusWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _testAlertFlow() {
    final dev = widget.device;
    final plant = widget.plant ??
        Plant(
          id: 'sample',
          name: dev.name,
          species: 'Monitored Specimen',
          imageUrl: 'assets/images/image_1.png',
          iotDeviceId: dev.id,
        );
    LowMoistureDecisionService().dispatchLowMoistureAlert(
      device: dev,
      currentMoisture: 18,
      force: true,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LowMoistureDecisionScreen(device: dev, plant: plant),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int dynamicThreshold = widget.device.calculateDynamicAlertThreshold(
      plant: widget.plant,
      weatherData: widget.weatherData,
    );
    final String dynamicExplanation = widget.device.getDynamicAlertThresholdExplanation(
      plant: widget.plant,
      weatherData: widget.weatherData,
    );

    return Scaffold(
      appBar: StandardAppBar(
        title: '${widget.device.name} Settings',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===============================================================
            // 1. DEPLOYMENT ENVIRONMENT MODE
            // ===============================================================
            _buildSectionCard(
              isDark: isDark,
              title: 'Deployment Environment Mode',
              subtitle: 'Anchors watering target and alerts to indoor or outdoor weather',
              icon: Icons.roofing_rounded,
              color: const Color(0xFF0284C7),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _toggleEnvironment(true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isIndoor
                                ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                                : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isIndoor ? const Color(0xFF3B82F6) : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                              width: _isIndoor ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_rounded,
                                size: 16,
                                color: _isIndoor ? const Color(0xFF2563EB) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Indoor (Sheltered)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _isIndoor ? FontWeight.bold : FontWeight.normal,
                                    color: _isIndoor
                                        ? (isDark ? Colors.white : const Color(0xFF1D4ED8))
                                        : (isDark ? kDarkTextSecondary : kTextSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _toggleEnvironment(false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: !_isIndoor
                                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4))
                                : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_isIndoor ? const Color(0xFF10B981) : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                              width: !_isIndoor ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.park_rounded,
                                size: 16,
                                color: !_isIndoor ? const Color(0xFF059669) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Outdoor (Adaptive)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !_isIndoor ? FontWeight.bold : FontWeight.normal,
                                    color: !_isIndoor
                                        ? (isDark ? Colors.white : const Color(0xFF065F46))
                                        : (isDark ? kDarkTextSecondary : kTextSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _isIndoor
                      ? '🏠 Indoor Setting: Sheltered from rain, wind, and solar heat. Soil moisture target is held stable at 65%.'
                      : '🌳 Outdoor Setting: Dynamic RainGuard and heat compensation active. Moisture target dynamically adjusts between 50%–70%.',
                  style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.35),
                ),
              ],
            ),

            // ===============================================================
            // 2. WATERING AUTOMATION & PUMP CONTROL
            // ===============================================================
            _buildSectionCard(
              isDark: isDark,
              title: 'Watering Automation & Pump Mode',
              subtitle: 'Switch between autonomous irrigation and manual decision flow',
              icon: Icons.water_drop_rounded,
              color: kPrimaryColor,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _toggleWateringMode(true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _autoWaterEnabled ? Colors.teal.shade700 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.autorenew_rounded, size: 14, color: _autoWaterEnabled ? Colors.white : Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Autonomous (AUTO)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: _autoWaterEnabled ? FontWeight.bold : FontWeight.w500,
                                      color: _autoWaterEnabled ? Colors.white : Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _toggleWateringMode(false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_autoWaterEnabled ? kPrimaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app_outlined, size: 14, color: !_autoWaterEnabled ? Colors.white : Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Decision Flow (MANUAL)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: !_autoWaterEnabled ? FontWeight.bold : FontWeight.w500,
                                      color: !_autoWaterEnabled ? Colors.white : Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50.withValues(alpha: isDark ? 0.15 : 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueGrey.shade200.withValues(alpha: isDark ? 0.3 : 1.0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: isDark ? Colors.tealAccent : const Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anti-Flooding Cooldown: The ESP32 enforces a mandatory 15-minute cooldown between pump activations to allow water absorption and prevent flooding.',
                          style: TextStyle(fontSize: 10.5, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Relay Polarity',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                        ),
                        Text(
                          _activeHigh ? 'Active HIGH (3.3V)' : 'Active LOW (0V)',
                          style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _toggleRelayPolarity,
                      child: const Text('Invert Polarity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),

            // ===============================================================
            // 3. SOIL MOISTURE NOTIFICATION SETTINGS
            // ===============================================================
            _buildSectionCard(
              isDark: isDark,
              title: 'Soil Moisture Alert Settings',
              subtitle: 'Configure low moisture thresholds and plant-based dynamic triggers',
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFD97706),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable Soil Moisture Alerts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                  ),
                  subtitle: Text(
                    'Get phone notifications when soil moisture drops below threshold',
                    style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                  ),
                  value: _lowMoistureAlertEnabled,
                  activeThumbColor: kPrimaryColor,
                  onChanged: _toggleLowMoistureAlerts,
                ),

                if (_lowMoistureAlertEnabled) ...[
                  const Divider(height: 16, color: kBorderSubtle),
                  Text(
                    'Threshold Calculation Mode',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                  ),
                  const SizedBox(height: 8),

                  // Option A: Plant-Based Dynamic
                  InkWell(
                    onTap: () => _setAlertThresholdMode(true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _dynamicMoistureAlertEnabled
                            ? kPrimaryColor.withValues(alpha: 0.08)
                            : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _dynamicMoistureAlertEnabled ? kPrimaryColor : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                          width: _dynamicMoistureAlertEnabled ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _dynamicMoistureAlertEnabled ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                size: 16,
                                color: _dynamicMoistureAlertEnabled ? kPrimaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Plant-Based & Weather Dynamic (Recommended)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _dynamicMoistureAlertEnabled ? kPrimaryColor : (isDark ? kDarkTextPrimary : kTextPrimary),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$dynamicThreshold%',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kPrimaryColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dynamicExplanation,
                            style: TextStyle(fontSize: 10.5, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Option B: Custom Fixed Threshold
                  InkWell(
                    onTap: () => _setAlertThresholdMode(false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !_dynamicMoistureAlertEnabled
                            ? kPrimaryColor.withValues(alpha: 0.08)
                            : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_dynamicMoistureAlertEnabled ? kPrimaryColor : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                          width: !_dynamicMoistureAlertEnabled ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                !_dynamicMoistureAlertEnabled ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                size: 16,
                                color: !_dynamicMoistureAlertEnabled ? kPrimaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Custom Fixed Threshold',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: !_dynamicMoistureAlertEnabled ? kPrimaryColor : (isDark ? kDarkTextPrimary : kTextPrimary),
                                ),
                              ),
                            ],
                          ),
                          if (!_dynamicMoistureAlertEnabled) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [15, 20, 25, 30, 35].map((val) {
                                final isSel = _customMoistureThreshold == val;
                                return ChoiceChip(
                                  label: Text('< $val%'),
                                  selected: isSel,
                                  selectedColor: kPrimaryColor.withValues(alpha: 0.2),
                                  onSelected: (_) => _setCustomThreshold(val),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Snooze / Ignore Controls
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.device.isLowMoistureAlertIgnored
                          ? const Color(0xFFFEF3C7)
                          : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.device.isLowMoistureAlertIgnored ? const Color(0xFFFDE68A) : (isDark ? kDarkBorderSubtle : kBorderSubtle)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.device.isLowMoistureAlertIgnored ? Icons.snooze_rounded : Icons.notifications_active_rounded,
                          size: 16,
                          color: widget.device.isLowMoistureAlertIgnored ? const Color(0xFFD97706) : kPrimaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.device.lowMoistureIgnoreStatusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.device.isLowMoistureAlertIgnored ? const Color(0xFF92400E) : (isDark ? kDarkTextPrimary : kTextPrimary),
                            ),
                          ),
                        ),
                        if (widget.device.isLowMoistureAlertIgnored)
                          TextButton(
                            onPressed: () {
                              setState(() => widget.device.resetAlertIgnore());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🔔 Alerts resumed.')),
                              );
                            },
                            child: const Text('Resume', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        else
                          TextButton(
                            onPressed: _showDeviceIgnorePicker,
                            child: const Text('Snooze', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Test Alert Button
                  OutlinedButton.icon(
                    onPressed: _testAlertFlow,
                    icon: const Icon(Icons.touch_app_rounded, size: 16),
                    label: const Text('Test Low Moisture Alert & Decision Flow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),

            // ===============================================================
            // 4. DAILY WEATHER NOTIFICATION AT 9:00 AM
            // ===============================================================
            _buildSectionCard(
              isDark: isDark,
              title: 'Daily Weather Briefing',
              subtitle: 'Morning garden advisory delivered every morning at 9:00 AM',
              icon: Icons.wb_sunny_rounded,
              color: const Color(0xFFF59E0B),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Daily 9:00 AM Weather Notification',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                  ),
                  subtitle: Text(
                    'Receive morning weather conditions, rain forecast, and dynamic watering recommendations for ${widget.device.locationDisplayName}',
                    style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.3),
                  ),
                  value: _dailyWeatherNotificationEnabled,
                  activeThumbColor: const Color(0xFFF59E0B),
                  onChanged: _toggleDailyWeatherNotification,
                ),
              ],
            ),

            // ===============================================================
            // 5. HARDWARE & DIAGNOSTIC UTILITIES
            // ===============================================================
            _buildSectionCard(
              isDark: isDark,
              title: 'Hardware Utilities & Maintenance',
              subtitle: 'Ping tests, Wi-Fi pairing reconfiguration, and factory wipe',
              icon: Icons.build_circle_outlined,
              color: Colors.blueGrey,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.speed_rounded, color: kPrimaryColor),
                  title: const Text('Cloud Heartbeat Ping Test', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Verify roundtrip HTTPS communication with Firestore', style: TextStyle(fontSize: 11)),
                  trailing: _isTestingPing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: _runPing,
                ),
                const Divider(height: 1, color: kBorderSubtle),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Reconfigure Wi-Fi Network', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Open 3-step setup wizard to connect to another Wi-Fi', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IotSetupWizardScreen(initialDeviceId: widget.device.id),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
