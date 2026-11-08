import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../models/plant_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import '../../services/plant_service.dart';
import 'iot_activity_logs_screen.dart';
import 'iot_details_screen.dart';
import 'iot_scanning_screen.dart';
import 'iot_setup_wizard_screen.dart';
import '../../components/iot_connection_guide_sheet.dart';

class IotManagementScreen extends StatefulWidget {
  final String? plantId; // Optional plantId when opened from Plant Details

  const IotManagementScreen({super.key, this.plantId});

  @override
  State<IotManagementScreen> createState() => _IotManagementScreenState();
}

class _IotManagementScreenState extends State<IotManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
    _plantService.addListener(_onPlantServiceChanged);
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

  void _onViewLogs() {
    _tabController.animateTo(1);
  }

  void _onBackToDevices() {
    _tabController.animateTo(0);
  }

  void _openDeviceDetails(IotDevice device) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IotDetailsScreen(device: device)),
    );
    if (mounted) setState(() {});
  }

  void _openScanner() async {
    final newDevice = await Navigator.push<IotDevice>(
      context,
      MaterialPageRoute(builder: (_) => const IotScanningScreen()),
    );
    if (newDevice != null && mounted) {
      _openDeviceDetails(newDevice);
    }
  }

  void _openSetupWizard() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const IotSetupWizardScreen()),
    );
    if (res == true && mounted) {
      setState(() {});
    }
  }

  void _attachDeviceToPlant(IotDevice device) {
    if (widget.plantId == null) return;
    _plantService.assignDeviceToPlant(plantId: widget.plantId!, deviceId: device.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Linked ${device.name} to this botanical specimen!'),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _unpairDevice(IotDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unpair ${device.name}?'),
        content: const Text(
          'This will remove this probe from your Devices & Hub list and unlink it from any botanical specimen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger, foregroundColor: Colors.white),
            child: const Text('Unpair & Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _service.removeIotDevice(device.id);
      _plantService.unassignDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlinked ${device.name} from hub.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Standardized Botanical Header (Uniform with Garden & Shop)
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
                      if (canPop) ...[
                        StandardBackButton(onPressed: () => Navigator.maybePop(context)),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.plantId != null ? 'Attach Specimen Sensor 🔗' : 'Smart Gardening Hub 🌱',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.plantId != null ? 'Sensor Pairing' : 'My Plant Sensors',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Connection Modes Help Guide Button
                      IconButton(
                        tooltip: 'IoT Hotspot vs Wi-Fi Guide',
                        icon: const Icon(Icons.help_outline_rounded, color: kPrimaryColor, size: 22),
                        onPressed: () => showIotConnectionModesGuide(context),
                      ),
                      const SizedBox(width: 4),
                      // Live Status Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _service.isRealHardwareConnected
                              ? kStatusSuccess.withValues(alpha: 0.12)
                              : kStatusWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _service.isRealHardwareConnected
                                ? kStatusSuccess.withValues(alpha: 0.3)
                                : kStatusWarning.withValues(alpha: 0.3),
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
                                color: _service.isRealHardwareConnected ? kStatusSuccess : kStatusWarning,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _service.isRealHardwareConnected ? 'ONLINE' : 'STANDBY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _service.isRealHardwareConnected ? kStatusSuccess : const Color(0xFFB45309),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // TabBar Container in capsule style
                  Container(
                    padding: const EdgeInsets.all(4),
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
                      unselectedLabelColor: kTextSecondary,
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
                                Text('Plant Sensors'),
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

            // TabBarView Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDevicesHubTab(),
                  IotActivityLogsScreen(
                    onBackToSetup: _onBackToDevices,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 0: Clean, Stable Devices & Hub List (No flickering setup wizard)
  Widget _buildDevicesHubTab() {
    return RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: () async {
        await _service.fetchLiveHardwareTelemetry();
        if (mounted) setState(() {});
      },
      child: ValueListenableBuilder<List<IotDevice>>(
        valueListenable: _service.connectedDevicesNotifier,
        builder: (context, dynamicDevices, _) {
          final devices = dynamicDevices.isNotEmpty
              ? dynamicDevices
              : _service.connectedIotDevices;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hub Status & Scanner Card
                _buildHubHeaderCard(devices.length),
                const SizedBox(height: 16),

                // Specimen Attachment Mode Alert (if opened with plantId)
                if (widget.plantId != null) ...[
                  _buildAttachmentInstructionCard(),
                  const SizedBox(height: 14),
                ],

                // Section Header: Devices List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Plant Sensors (${devices.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openScanner,
                      icon: const Icon(Icons.wifi_find_rounded, size: 16, color: kPrimaryColor),
                      label: const Text(
                        'Find Sensors',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Device List or Empty State
                if (devices.isEmpty)
                  _buildEmptyDevicesCard()
                else
                  ...devices.map((device) => _buildDeviceCard(device)),

                const SizedBox(height: 20),

                // Hub Utilities & Quick Links
                _buildHubUtilitiesCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Top Hub Header Summary with quick action to scan for devices
  Widget _buildHubHeaderCard(int deviceCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryColor, Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
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
                            'Plant Sensor Hub',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: kTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _service.isRealHardwareConnected
                                ? kStatusSuccess.withValues(alpha: 0.12)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _service.isRealHardwareConnected ? 'SYSTEM ACTIVE' : 'HOST READY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _service.isRealHardwareConnected ? kStatusSuccess : kTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$deviceCount Sensor${deviceCount == 1 ? '' : 's'} Active • Ready for Live Telemetry',
                      style: const TextStyle(fontSize: 11, color: kTextSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openSetupWizard,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Sensor (Wizard)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(Icons.wifi_find_rounded, size: 18),
                label: const Text('Find Nearby', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
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
              'Select an IoT probe below and tap "Attach to Plant" to link live hardware telemetry to your plant.',
              style: TextStyle(fontSize: 12, color: kPrimaryDark, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Card representation for each registered IoT probe in the list
  Widget _buildDeviceCard(IotDevice device) {
    final Plant? pairedPlant = _plantService.getPlantForDevice(device.id);
    final bool hasWifi = device.isWifiConnected && device.wifiSsid != null && device.wifiSsid!.isNotEmpty;
    final int moisture = (device.moistureLevel != null)
        ? (device.moistureLevel! * 100).round().clamp(0, 100)
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDeviceDetails(device),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Device Avatar with Status Indicator
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
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
                              color: hasWifi ? kStatusSuccess : const Color(0xFFD97706),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Device Name & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  device.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: kTextPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasWifi
                                      ? kStatusSuccess.withValues(alpha: 0.12)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasWifi ? 'ONLINE' : 'NEEDS WI-FI',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasWifi ? kStatusSuccess : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasWifi
                                ? 'Wi-Fi: ${device.wifiSsid}'
                                : 'Wi-Fi: Not connected • SoftAP Ready',
                            style: TextStyle(
                              fontSize: 11,
                              color: hasWifi ? kTextSecondary : const Color(0xFFB45309),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Paired Plant Status
                          Row(
                            children: [
                              Icon(
                                pairedPlant != null ? Icons.eco_rounded : Icons.eco_outlined,
                                size: 13,
                                color: pairedPlant != null ? kPrimaryColor : kTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  pairedPlant != null
                                      ? 'Paired to: ${pairedPlant.name}'
                                      : 'No Plant Linked (Unassigned)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: pairedPlant != null ? FontWeight.bold : FontWeight.normal,
                                    color: pairedPlant != null ? kPrimaryColor : kTextSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Trailing Action: Popup Menu for unpair / details
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: kTextSecondary),
                      onSelected: (val) {
                        if (val == 'details') {
                          _openDeviceDetails(device);
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
                              Text('Details & Network', style: TextStyle(fontSize: 13)),
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
                const SizedBox(height: 12),

                // Bottom Strip: Moisture gauge & Details link or Attach Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: kBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.water_drop_rounded, size: 12, color: kPrimaryColor),
                            const SizedBox(width: 3),
                            Text(
                              device.moistureLevel != null ? '$moisture%' : 'Live',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pairedPlant != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (moisture >= 25 ? kStatusSuccess : const Color(0xFFD97706)).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            moisture >= 25 ? 'Optimal' : 'Needs Water',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: moisture >= 25 ? kStatusSuccess : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      const Spacer(),
                      if (widget.plantId != null) ...[
                        ElevatedButton.icon(
                          onPressed: () => _attachDeviceToPlant(device),
                          icon: const Icon(Icons.link_rounded, size: 14),
                          label: const Text('Attach', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ] else ...[
                        const Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Plant Care',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kPrimaryColor),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Empty state when no IoT probes are connected
  Widget _buildEmptyDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sensors_off_rounded, color: kPrimaryColor, size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            'No IoT Probes in Hub',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan your local Wi-Fi subnet or follow the setup wizard to connect your ESP32 soil probe for real-time monitoring and irrigation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.radar_rounded, size: 18),
                  label: const Text('Scan Local Wi-Fi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openSetupWizard,
                  icon: const Icon(Icons.handyman_rounded, size: 18),
                  label: const Text('Setup Wizard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Utility tiles at bottom of screen
  Widget _buildHubUtilitiesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hub Management & Tools',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
        ),
        const SizedBox(height: 10),
        _buildUtilityTile(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Hardware Setup Wizard',
          subtitle: 'Step-by-step guidance to connect probe hotspot and configure 2.4GHz Wi-Fi',
          onTap: _openSetupWizard,
        ),
        const SizedBox(height: 8),
        _buildUtilityTile(
          icon: Icons.compare_arrows_rounded,
          title: 'Connection Modes Guide',
          subtitle: 'Distinct breakdown: IoT Hotspot vs Home Wi-Fi Network',
          onTap: () => showIotConnectionModesGuide(context),
        ),
        const SizedBox(height: 8),
        _buildUtilityTile(
          icon: Icons.receipt_long_rounded,
          title: 'Activity & Telemetry Logs',
          subtitle: 'Inspect sensing, watering, alert, and hardware event history',
          onTap: _onViewLogs,
        ),
        const SizedBox(height: 8),
        _buildUtilityTile(
          icon: Icons.radar_rounded,
          title: 'Subnet Discovery Scanner (Advanced)',
          subtitle: 'Scan local Wi-Fi subnet to detect new ESP32 probe nodes',
          onTap: _openScanner,
        ),
      ],
    );
  }

  Widget _buildUtilityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSubtle),
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
          child: Icon(icon, color: kPrimaryColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: kTextSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 20),
      ),
    );
  }
}
