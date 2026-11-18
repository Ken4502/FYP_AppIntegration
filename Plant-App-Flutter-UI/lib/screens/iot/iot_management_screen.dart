import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../models/plant_model.dart';
import '../../services/iot_firestore_service.dart';
import '../../services/plant_service.dart';
import '../../services/weather_service.dart';
import 'iot_activity_logs_screen.dart';
import 'iot_details_screen.dart';
import 'iot_setup_wizard_screen.dart';
import '../../components/iot_connection_guide_sheet.dart';

/// Central IoT Management Screen
/// Strictly separates SoftAP Wi-Fi provisioning from operational IoT dashboard.
/// Operational IoT features are only unlocked after an ESP32 is successfully
/// provisioned and listed in Cloud Firestore.
class IotManagementScreen extends StatefulWidget {
  final String? plantId; // Optional plantId when opened from Plant Details to attach a probe

  const IotManagementScreen({super.key, this.plantId});

  @override
  State<IotManagementScreen> createState() => _IotManagementScreenState();
}

class _IotManagementScreenState extends State<IotManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IotFirestoreService _firestoreService = IotFirestoreService();
  final PlantService _plantService = PlantService();
  final WeatherService _weatherService = WeatherService();

  // Weather state
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;

  // Refresh feedback state
  bool _isManualRefreshing = false;

  // Active selected device for logs
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _plantService.addListener(_onPlantServiceChanged);
    _loadWeather();
  }

  void _onPlantServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _plantService.removeListener(_onPlantServiceChanged);
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

  Future<void> _handleRefresh() async {
    setState(() => _isManualRefreshing = true);
    await _loadWeather();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isManualRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Cloud telemetry & local weather refreshed from Firestore.'),
          backgroundColor: kPrimaryColor,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSetupWizard([String? targetDeviceId]) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IotSetupWizardScreen(initialDeviceId: targetDeviceId),
      ),
    );
    if (res == true && mounted) {
      setState(() {});
      _handleRefresh();
    }
  }

  void _openDeviceDetails(IotDevice device) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IotDetailsScreen(device: device)),
    );
    if (mounted) setState(() {});
  }

  void _attachDeviceToPlant(IotDevice device) async {
    if (widget.plantId == null) return;
    final plant = _plantService.myPlants.firstWhere(
      (p) => p.id == widget.plantId,
      orElse: () => Plant(
        id: widget.plantId!,
        name: 'Botanical Specimen',
        species: 'Indoor Specimen',
        imageUrl: 'assets/images/plant1.png',
      ),
    );

    await _firestoreService.linkPlant(
      device.id,
      plantId: plant.id,
      plantName: plant.name,
      plantImage: plant.imageUrl,
    );
    _plantService.assignDeviceToPlant(plantId: plant.id, deviceId: device.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Successfully linked ${device.name} to ${plant.name}!'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _unlinkPlant(IotDevice device) async {
    await _firestoreService.unlinkPlant(device.id);
    _plantService.unassignDevice(device.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unlinked plant from ${device.name}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _showPlantPickerSheet(IotDevice device) async {
    final plants = _plantService.myPlants;
    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No plants in your garden yet. Add a plant first!'),
          backgroundColor: kStatusWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? kDarkSurfaceColor : kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pair with Garden Specimen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a botanical specimen to bind live moisture readings and watering logs from ${device.name}:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: plants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, idx) {
                      final p = plants[idx];
                      final isCurrent = device.linkedPlantId == p.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                          backgroundImage: p.imageUrl.isNotEmpty ? AssetImage(p.imageUrl) : null,
                          child: p.imageUrl.isEmpty
                              ? const Icon(Icons.eco_rounded, color: kPrimaryColor)
                              : null,
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          p.species,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor)
                            : OutlinedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _firestoreService.linkPlant(
                                    device.id,
                                    plantId: p.id,
                                    plantName: p.name,
                                    plantImage: p.imageUrl,
                                  );
                                  _plantService.assignDeviceToPlant(plantId: p.id, deviceId: device.id);
                                  if (mounted) setState(() {});
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kPrimaryColor,
                                  side: const BorderSide(color: kPrimaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text('Pair', style: TextStyle(fontSize: 12)),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _quickWaterPulse(IotDevice device) async {
    await _firestoreService.triggerManualPulse(device.id, durationSeconds: 3);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('💧 Quick water pulse (3s) sent to Firestore for ${device.name}!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _toggleWateringMode(IotDevice device) async {
    final newMode = !device.autoWaterEnabled;
    await _firestoreService.setWateringMode(device.id, autoWaterEnabled: newMode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMode
                ? '🤖 ${device.name} switched to Automatic Threshold Watering.'
                : '🖐️ ${device.name} switched to Manual Decision Mode.',
          ),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _unpairDevice(IotDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Factory Reset & Unpair ${device.name}?'),
        content: const Text(
          'This will completely wipe and reset the device:\n\n'
          '• Sends a FACTORY_RESET command to erase Wi-Fi and NVS memory on the ESP32.\n'
          '• Removes the device and telemetry from Cloud Firestore.\n'
          '• Unbinds from any linked botanical specimen.\n\n'
          'The ESP32 will reboot into an unconfigured state, allowing you to repeat the setup cycle cleanly.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger, foregroundColor: Colors.white),
            child: const Text('Wipe & Unpair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _firestoreService.factoryResetDevice(device.id);
      _plantService.unassignDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unpaired ${device.name}. Factory reset sent to device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${monthNames[dt.month - 1]} ${dt.day}, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    return StreamBuilder<List<IotDevice>>(
      stream: _firestoreService.streamUserDevices(),
      builder: (context, snapshot) {
        final List<IotDevice> devices = snapshot.data ?? [];
        final bool hasDevices = devices.isNotEmpty;
        final bool isOnline = devices.any((d) => d.isOnline);

        return Scaffold(
          backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Standard Botanical Header
                _buildScreenHeader(isDark, canPop, hasDevices, isOnline),

                // Main Body: Strictly Gated vs Fully Unlocked Dashboard
                Expanded(
                  child: !hasDevices
                      ? _buildGatedSetupView(isDark)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOperationalDashboardTab(devices, isDark),
                            IotActivityLogsScreen(
                              deviceId: _selectedDeviceId ?? (devices.isNotEmpty ? devices.first.id : null),
                              onBackToSetup: () => _tabController.animateTo(0),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Screen Header with Dynamic Online Status and Built-in Refresh Button
  Widget _buildScreenHeader(bool isDark, bool canPop, bool hasDevices, bool isOnline) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
              if (canPop) ...[
                StandardBackButton(onPressed: () => Navigator.maybePop(context)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plantId != null ? 'Link Specimen Sensor 🔗' : 'Smart Gardening Hub 🌱',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.plantId != null ? 'Sensor Pairing' : 'My Plant Sensors',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Help Guide Button
              IconButton(
                tooltip: 'IoT Connection & SoftAP Guide',
                icon: Icon(Icons.help_outline_rounded, color: isDark ? kSecondaryColor : kPrimaryColor, size: 22),
                onPressed: () => showIotConnectionModesGuide(context),
              ),
              // Built-in Refresh Button
              IconButton(
                tooltip: 'Refresh Cloud Telemetry',
                icon: _isManualRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                      )
                    : Icon(Icons.refresh_rounded, color: isDark ? kSecondaryColor : kPrimaryColor, size: 22),
                onPressed: _isManualRefreshing ? null : _handleRefresh,
              ),
              const SizedBox(width: 4),
              // Dynamic Live Status Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnline
                      ? kStatusSuccess.withValues(alpha: 0.12)
                      : (hasDevices ? kStatusWarning.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? kStatusSuccess.withValues(alpha: 0.3)
                        : (hasDevices ? kStatusWarning.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? kStatusSuccess
                            : (hasDevices ? const Color(0xFFD97706) : Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'ONLINE' : (hasDevices ? 'STANDBY' : 'UNPAIRED'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline
                            ? kStatusSuccess
                            : (hasDevices ? const Color(0xFFB45309) : Colors.grey.shade600),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // If devices exist, render the clean capsule TabBar
          if (hasDevices) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : kSurfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Plant Sensors & Care'),
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
                          Icon(Icons.receipt_long_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Activity & Logs'),
                        ],
                      ),
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

  /// STRICT GATING STATE:
  /// Displayed when NO ESP32 chip has been configured or listed in Cloud Firestore.
  /// Explains clearly that Wi-Fi configuration is a dedicated prerequisite before
  /// normal IoT features can be used.
  Widget _buildGatedSetupView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Graphic Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? kDarkCardColor : kSurfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: kPrimaryColor,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No IoT Sensor Added Yet 🌱',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pair your ESP32 Smart Plant Probe to unlock real-time soil moisture monitoring, plant health telemetry, and automatic watering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // Main CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openSetupWizard(),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text(
                      'Add IoT Device',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _handleRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Already Configured? Tap to Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4-Step Process Guide Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? kDarkCardColor : kSurfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist_rtl_rounded, color: kPrimaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'How One-Time Setup Works',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildProcessStep(
                  stepNum: '1',
                  title: 'Connect to Setup Hotspot',
                  description: 'Turn on the ESP32 and connect your phone to "ESP32_Plant_Irrigation". Connection is auto-detected.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildProcessStep(
                  stepNum: '2',
                  title: 'Select Wi-Fi from Auto-Scan',
                  description: 'The ESP32 searches nearby 2.4GHz networks. Simply select yours and enter the password.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildProcessStep(
                  stepNum: '3',
                  title: 'Autonomous Cloud Registration',
                  description: 'The ESP32 shuts down the hotspot, connects to your router, and registers in Cloud Firestore. (Watering is turned OFF by default for safety).',
                  isDark: isDark,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Architectural Assurance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_done_rounded, color: kPrimaryColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloud-Mediated Architecture',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimaryDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Once configured, your mobile app never communicates directly with the ESP32 chip. All telemetry, watering pulses, and thresholds operate securely through Cloud Firestore from anywhere in the world.',
                        style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : Colors.grey.shade700, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep({
    required String stepNum,
    required String title,
    required String description,
    required bool isDark,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNum,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
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
    );
  }

  /// FULLY UNLOCKED OPERATIONAL IOT DASHBOARD:
  /// Active when configured ESP32 device(s) are listed in Cloud Firestore.
  Widget _buildOperationalDashboardTab(List<IotDevice> devices, bool isDark) {
    return RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Real-Time Local Weather Card
            _buildWeatherSummaryCard(isDark),
            const SizedBox(height: 14),

            // 2. Specimen Attachment Mode Alert (if opened with plantId)
            if (widget.plantId != null) ...[
              _buildAttachmentInstructionCard(),
              const SizedBox(height: 14),
            ],

            // 3. Section Header: Active Sensors Count & Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configured Probes (${devices.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openSetupWizard(),
                  icon: const Icon(Icons.add_rounded, size: 16, color: kPrimaryColor),
                  label: const Text(
                    'Configure Another',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 4. Configured Device Cards
            ...devices.map((device) => _buildOperationalDeviceCard(device, isDark)),

            const SizedBox(height: 20),

            // 5. Hub Management Tools Card
            _buildHubManagementCard(isDark),
          ],
        ),
      ),
    );
  }

  /// Real-Time Local Weather of the User's City with Rain Guard Status
  Widget _buildWeatherSummaryCard(bool isDark) {
    final w = _weatherData;

    return Container(
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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_queue_rounded, color: Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          w != null ? w.locationName : 'Local City Weather',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVE REST',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      w != null
                          ? '${w.weatherCondition} • ${w.temperature.toStringAsFixed(1)}°C • ${w.relativeHumidity}% Humidity'
                          : 'Fetching live meteorological data...',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingWeather)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                ),
            ],
          ),
          if (w != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (w.isRainGuardActive ? const Color(0xFFFEF3C7) : kPrimaryColor.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    w.isRainGuardActive ? Icons.umbrella_rounded : Icons.eco_rounded,
                    size: 14,
                    color: w.isRainGuardActive ? const Color(0xFFB45309) : kPrimaryDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w.rainGuardMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: w.isRainGuardActive ? const Color(0xFFB45309) : kPrimaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  /// Banner when opened from plant detail screen to link an IoT sensor
  Widget _buildAttachmentInstructionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.link_rounded, color: kPrimaryColor, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select an ESP32 sensor below and tap "Attach to Plant" to link its live moisture readings and watering logs.',
              style: TextStyle(fontSize: 12, color: kPrimaryDark, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Comprehensive Operational Card for each Configured ESP32
  Widget _buildOperationalDeviceCard(IotDevice device, bool isDark) {
    final bool isOnline = device.isOnline;
    final int moisture = (device.moistureLevel != null)
        ? (device.moistureLevel! * 100).round().clamp(0, 100)
        : 0;

    // Moisture status classification
    final bool isDry = moisture < device.lowMoistureThreshold;
    final bool isOptimal = moisture >= device.lowMoistureThreshold && moisture <= device.highMoistureThreshold;
    final Color moistureColor = isDry
        ? const Color(0xFFD97706)
        : (isOptimal ? kStatusSuccess : const Color(0xFF0284C7));
    final String moistureStatusText = isDry
        ? 'Dry (Needs Water)'
        : (isOptimal ? 'Optimal Moisture' : 'Sufficient Moisture');

    // Linked plant lookup
    Plant? pairedPlant;
    if (device.linkedPlantId != null) {
      pairedPlant = _plantService.myPlants.firstWhere(
        (p) => p.id == device.linkedPlantId,
        orElse: () => Plant(
          id: device.linkedPlantId!,
          name: device.linkedPlantName ?? 'Linked Specimen',
          species: 'Botanical Specimen',
          imageUrl: device.linkedPlantImage ?? 'assets/images/plant1.png',
        ),
      );
    } else {
      pairedPlant = _plantService.getPlantForDevice(device.id);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnline
              ? kPrimaryColor.withValues(alpha: 0.3)
              : (isDark ? kDarkBorderSubtle : kBorderSubtle),
          width: isOnline ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDeviceDetails(device),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Chip Icon, Device Name, ID, Dynamic Status Badge, Overflow
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.developer_board_rounded, color: kPrimaryColor, size: 22),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? kStatusSuccess : const Color(0xFFD97706),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Name & ID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  device.name,
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
                                  color: device.isGraceHotspotActive
                                      ? const Color(0xFFFEF3C7)
                                      : (isOnline
                                          ? kStatusSuccess.withValues(alpha: 0.12)
                                          : const Color(0xFFFEF3C7)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  device.stateDisplayLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: device.isGraceHotspotActive
                                        ? const Color(0xFFD97706)
                                        : (isOnline ? kStatusSuccess : const Color(0xFFB45309)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${device.id} • Wi-Fi: ${device.wifiSsid ?? "Connected"}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Overflow Menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: kTextSecondary),
                      onSelected: (val) {
                        if (val == 'details') {
                          _openDeviceDetails(device);
                        } else if (val == 'reconfigure') {
                          _openSetupWizard(device.id);
                        } else if (val == 'unpair') {
                          _unpairDevice(device);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, size: 16, color: kPrimaryColor),
                              SizedBox(width: 8),
                              Text('Settings & Details', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'reconfigure',
                          child: Row(
                            children: [
                              Icon(Icons.wifi_tethering_rounded, size: 16, color: Color(0xFF0284C7)),
                              SizedBox(width: 8),
                              Text('Reconfigure Wi-Fi (SoftAP)', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'unpair',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: kStatusDanger),
                              SizedBox(width: 8),
                              Text('Unpair Device', style: TextStyle(fontSize: 13, color: kStatusDanger)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Telemetry Metrics Grid: Moisture % and Health Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.water_drop_rounded, size: 18, color: moistureColor),
                              const SizedBox(width: 6),
                              Text(
                                '$moisture%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: moistureColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: moistureColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  moistureStatusText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: moistureColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Mode Indicator
                          GestureDetector(
                            onTap: () => _toggleWateringMode(device),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: device.autoWaterEnabled
                                    ? kPrimaryColor.withValues(alpha: 0.12)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: device.autoWaterEnabled ? kPrimaryColor : Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    device.autoWaterEnabled ? Icons.smart_toy_rounded : Icons.touch_app_rounded,
                                    size: 13,
                                    color: device.autoWaterEnabled ? kPrimaryColor : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    device.autoWaterEnabled ? 'AUTO' : 'MANUAL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: device.autoWaterEnabled ? kPrimaryColor : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Linear Progress Indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (moisture / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(moistureColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Reading and Watered Timestamps
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Last Reading: ${_formatDateTime(device.lastReadingAt ?? device.lastSeen)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
                          ),
                          Text(
                            'Last Watered: ${_formatDateTime(device.lastWateredAt)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Paired Plant Row or Link Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: pairedPlant != null
                        ? kPrimaryColor.withValues(alpha: 0.06)
                        : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pairedPlant != null
                          ? kPrimaryColor.withValues(alpha: 0.2)
                          : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pairedPlant != null ? Icons.eco_rounded : Icons.eco_outlined,
                        size: 18,
                        color: pairedPlant != null ? kPrimaryColor : kTextSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pairedPlant != null
                              ? 'Paired Specimen: ${pairedPlant.name}'
                              : 'No Plant Linked (Unassigned)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: pairedPlant != null ? FontWeight.bold : FontWeight.normal,
                            color: pairedPlant != null ? kPrimaryColor : kTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pairedPlant != null) ...[
                        TextButton(
                          onPressed: () => _unlinkPlant(device),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Unlink', style: TextStyle(fontSize: 11, color: kStatusDanger)),
                        ),
                      ] else ...[
                        TextButton.icon(
                          onPressed: () => _showPlantPickerSheet(device),
                          icon: const Icon(Icons.add_link_rounded, size: 14),
                          label: const Text('Pair Plant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Actions Row: Quick Water (3s Pulse) & Details Button
                Row(
                  children: [
                    if (widget.plantId != null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _attachDeviceToPlant(device),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Attach to This Plant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Quick Water 3s Pulse Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _quickWaterPulse(device),
                          icon: const Icon(Icons.water_drop_rounded, size: 16),
                          label: const Text(
                            'Quick Water (3s)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Settings & Details Button
                      OutlinedButton.icon(
                        onPressed: () => _openDeviceDetails(device),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          'Settings & Thresholds',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimaryColor,
                          side: const BorderSide(color: kPrimaryColor, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hub Management & Utilities at bottom of screen
  Widget _buildHubManagementCard(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hub Management & Tools',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _buildUtilityTile(
          icon: Icons.wifi_tethering_rounded,
          title: 'ESP32 Wi-Fi Setup Wizard (SoftAP)',
          subtitle: 'Step-by-step guidance to onboard a new ESP32 probe onto your 2.4GHz network',
          onTap: () => _openSetupWizard(),
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildUtilityTile(
          icon: Icons.compare_arrows_rounded,
          title: 'Connection Modes Guide',
          subtitle: 'Distinct breakdown: One-time SoftAP Setup vs Cloud Firestore Operations',
          onTap: () => showIotConnectionModesGuide(context),
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildUtilityTile(
          icon: Icons.receipt_long_rounded,
          title: 'Activity & Telemetry Logs',
          subtitle: 'View real-time watering, sensing, and system events streamed from Firestore',
          onTap: () => _tabController.animateTo(1),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildUtilityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isDark ? kSecondaryColor : kPrimaryColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? kDarkTextPrimary : kTextPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? kDarkTextSecondary : kTextSecondary, size: 20),
      ),
    );
  }
}
