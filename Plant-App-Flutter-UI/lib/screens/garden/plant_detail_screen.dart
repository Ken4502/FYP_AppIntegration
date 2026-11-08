import 'dart:io';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/garden/edit_plant_screen.dart';
import 'package:urbangreen/screens/iot/iot_details_screen.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/plant_service.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;
  final Function(Plant) onDelete;
  final Function(Plant) onUpdate;

  const PlantDetailScreen({
    super.key,
    required this.plant,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  PlantDetailScreenState createState() => PlantDetailScreenState();
}

class PlantDetailScreenState extends State<PlantDetailScreen> {
  late Plant _plant;
  late TextEditingController _descriptionController;
  final IotHybridConnectivityService _iotService = IotHybridConnectivityService();
  final PlantService _plantService = PlantService();
  final CareLogService _careLogService = CareLogService();

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _descriptionController = TextEditingController(text: _plant.description);
    _plantService.addListener(_onPlantServiceChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _plantService.removeListener(_onPlantServiceChanged);
    super.dispose();
  }

  void _onPlantServiceChanged() {
    final updated = _plantService.getPlantById(_plant.id);
    if (updated != null && mounted) {
      setState(() {
        _plant = updated;
      });
    }
  }

  void _navigateAndEditPlant(BuildContext context) async {
    final updatedPlant = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlantScreen(plant: _plant),
      ),
    );

    if (updatedPlant != null) {
      setState(() {
        _plant = updatedPlant;
        _descriptionController.text = _plant.description;
      });
      _plantService.updatePlant(updatedPlant);
      widget.onUpdate(updatedPlant);
    }
  }

  void _waterPlant() async {
    final now = DateTime.now();
    final updatedPlant = _plant.copyWith(lastWatered: now);
    _plantService.updatePlant(updatedPlant);
    widget.onUpdate(updatedPlant);
    setState(() {
      _plant = updatedPlant;
    });

    final linkedDeviceId = _plant.iotDeviceId;
    final IotDevice? linkedDev = (linkedDeviceId != null && linkedDeviceId.isNotEmpty)
        ? _iotService.connectedIotDevices.firstWhere(
            (d) => d.id == linkedDeviceId,
            orElse: () => IotDevice(id: linkedDeviceId, name: linkedDeviceId),
          )
        : null;

    if (linkedDev != null) {
      final moisture = linkedDev.moistureLevel?.round() ?? 35;
      final newMoisture = (moisture + 20).clamp(0, 100);
      _careLogService.logWatering(
        plantId: _plant.id,
        plantName: _plant.name,
        species: _plant.species,
        imageUrl: _plant.imageUrl,
        volumeMl: 50,
        careMode: 'Hardware Pump Pulse',
        moistureBeforePct: moisture,
        moistureAfterPct: newMoisture,
        notes: 'Dispensed 50ml via ${linkedDev.name}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💧 Actuating hardware pump on ${linkedDev.name}... (Care log updated)'),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _iotService.pulseWater(linkedDev.id);
    } else {
      _careLogService.logWatering(
        plantId: _plant.id,
        plantName: _plant.name,
        species: _plant.species,
        imageUrl: _plant.imageUrl,
        volumeMl: 200,
        careMode: 'Manual Hydration',
        notes: _plant.reminderEnabled
            ? 'Manual watering by botanist • Schedule reset for ${_plant.wateringIntervalDays} days'
            : 'Manual watering by botanist • (No reminder configured)',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_plant.reminderEnabled
              ? '💧 Hydrated ${_plant.name}! Next watering due in ${_plant.wateringIntervalDays} days.'
              : '💧 Hydrated ${_plant.name}! (No reminder set)'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildHeaderImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderHeader(),
      );
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderHeader(),
      );
    } else {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholderHeader(),
        );
      }
      return _placeholderHeader();
    }
  }

  Widget _placeholderHeader() {
    return Container(
      color: kPrimaryColor.withValues(alpha: 0.1),
      child: const Icon(Icons.eco_rounded, size: 80, color: kPrimaryColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkedDeviceId = _plant.iotDeviceId;
    final bool hasIot = _plant.hasIot;

    final IotDevice? linkedDevice = hasIot
        ? _iotService.connectedIotDevices.firstWhere(
            (d) => d.id == linkedDeviceId,
            orElse: () => IotDevice(
              id: linkedDeviceId!,
              name: linkedDeviceId,
              isWifiConnected: _iotService.isRealHardwareConnected,
            ),
          )
        : null;

    final int moisturePct = (linkedDevice?.moistureLevel != null)
        ? (linkedDevice!.moistureLevel! > 1.0
            ? linkedDevice.moistureLevel!.toInt()
            : (linkedDevice.moistureLevel! * 100).toInt())
        : 0;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Cinematic App Bar Image Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  onPressed: () => _navigateAndEditPlant(context),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Plant'),
                        content: Text('Remove ${_plant.name} from your garden collection?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onDelete(_plant);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger),
                            child: const Text('Remove', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeaderImage(_plant.imageUrl),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kPrimaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _plant.species,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasIot
                                    ? Colors.teal.shade700
                                    : (_plant.reminderEnabled ? Colors.blueGrey.shade800 : Colors.blueGrey.shade600),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasIot
                                        ? Icons.sensors
                                        : (_plant.reminderEnabled ? Icons.schedule : Icons.yard_outlined),
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasIot
                                        ? 'IoT Monitored'
                                        : (_plant.reminderEnabled ? 'Manual Schedule' : 'Manual Care'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _plant.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Body Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Care Quick-Action Strip (Overflow-Proof)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _waterPlant,
                          icon: const Icon(Icons.water_drop, size: 18, color: Colors.white),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              hasIot ? 'Pulse Pump (50ml)' : 'Watered Today',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (hasIot && linkedDevice != null) {
                              _showLinkedSensorOptions(linkedDevice);
                            } else {
                              _showSensorPickerModal();
                            }
                          },
                          icon: Icon(
                            hasIot ? Icons.sensors_rounded : Icons.add_link_rounded,
                            size: 18,
                            color: hasIot ? kPrimaryColor : kTextPrimary,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              hasIot ? 'Sensor Linked' : 'Pair IoT Probe',
                              style: TextStyle(
                                color: hasIot ? kPrimaryColor : kTextPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: hasIot ? kPrimaryColor : kBorderSubtle,
                              width: hasIot ? 1.5 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // =========================================================
                  // CASE A: PLANT WITH IOT PROBE (Real-time Telemetry Hub)
                  // =========================================================
                  if (hasIot && linkedDevice != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                                      child: const Icon(Icons.bluetooth_connected_rounded, size: 18, color: kPrimaryColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            linkedDevice.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Probe ID: ${linkedDevice.id}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.show_chart_rounded, size: 16),
                                    label: const Text('Live Graph', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: kPrimaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => IotDetailsScreen(device: linkedDevice),
                                        ),
                                      ).then((_) {
                                        if (mounted) setState(() {});
                                      });
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    onSelected: (val) {
                                      if (val == 'change') {
                                        _showSensorPickerModal();
                                      } else if (val == 'unlink') {
                                        _confirmUnlinkSensor();
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'change',
                                        child: Row(
                                          children: [
                                            Icon(Icons.swap_horiz, size: 18),
                                            SizedBox(width: 8),
                                            Text('Change Sensor'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'unlink',
                                        child: Row(
                                          children: [
                                            Icon(Icons.link_off, size: 18, color: kStatusDanger),
                                            SizedBox(width: 8),
                                            Text('Unlink Sensor', style: TextStyle(color: kStatusDanger)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Real-Time Soil Hydration', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              Text('$moisturePct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (moisturePct / 100.0).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    // =========================================================
                    // CASE B: PLANT WITHOUT IOT (Watering Reminder & Schedule)
                    // (Strictly NO fake IoT statistics, sensors, or charts!)
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _plant.wateringStatusColor.withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: _plant.reminderEnabled
                                          ? _plant.wateringStatusColor.withValues(alpha: 0.12)
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        _plant.reminderEnabled ? Icons.alarm_on_rounded : Icons.notifications_off_outlined,
                                        color: _plant.reminderEnabled ? _plant.wateringStatusColor : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Watering Reminder',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _plant.reminderEnabled
                                                ? 'Daily at ${_plant.reminderTime} • Every ${_plant.wateringIntervalDays}d'
                                                : 'No notification setup',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _plant.reminderEnabled ? Colors.grey.shade700 : Colors.grey.shade600,
                                              fontWeight: _plant.reminderEnabled ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_plant.reminderEnabled) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _plant.wateringStatusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _plant.wateringStatusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    _plant.wateringScheduleSummary,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _plant.wateringStatusColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_plant.reminderEnabled && _plant.nextWateringDate != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: kBackgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorderSubtle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 15, color: kPrimaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Next scheduled watering: ${_formatDate(_plant.nextWateringDate!)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showWateringReminderConfigSheet,
                                  icon: const Icon(Icons.tune_rounded, size: 16),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _plant.reminderEnabled ? 'Edit Reminder' : 'Set Up Reminder',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kPrimaryColor,
                                    side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _waterPlant,
                                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Mark Watered', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // =========================================================
                  // SHARED GENERIC BOTANICAL INFORMATION
                  // (Included in BOTH IoT and non-IoT specimens)
                  // =========================================================
                  const Text(
                    'Botanical Profile & Care Guide',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCareStatCard(
                          icon: Icons.wb_sunny_outlined,
                          title: 'Sunlight',
                          value: _plant.sunlight,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCareStatCard(
                          icon: Icons.water_drop_outlined,
                          title: 'Hydration Target',
                          value: 'Every ${_plant.wateringIntervalDays} Days',
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCareStatCard(
                          icon: Icons.thermostat_outlined,
                          title: 'Ideal Temperature',
                          value: _plant.idealTemperature,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCareStatCard(
                          icon: Icons.pets_outlined,
                          title: 'Pet Safety',
                          value: _plant.petToxicity,
                          color: _plant.petToxicity.contains('Safe') ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildCareStatCard(
                    icon: Icons.grass_rounded,
                    title: 'Recommended Substrate',
                    value: _plant.soilType,
                    color: Colors.brown.shade600,
                  ),
                  const SizedBox(height: 20),

                  // Species Care Recommendation Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 18, color: kPrimaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_plant.species} Care Notes',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _plant.wateringRecommendation,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                        ),
                        if (_plant.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _plant.description,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Care History Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kBorderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Care Record',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextPrimary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.history, size: 18, color: kPrimaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _plant.lastWatered != null
                                    ? 'Last Watered: ${_formatRelativeDate(_plant.lastWatered!)} (${_plant.lastWatered!.toLocal().toString().split(" ")[0]})'
                                    : 'Not yet recorded. Tap "Watered Today" to begin log.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // =========================================================================
  // WATERING REMINDER MODAL CONFIGURATION
  // =========================================================================
  void _showWateringReminderConfigSheet() {
    int selectedInterval = _plant.wateringIntervalDays;
    String selectedTime = _plant.reminderTime;
    bool reminderEnabled = _plant.reminderEnabled;
    final notesController = TextEditingController(text: _plant.careNotes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.alarm_add_rounded, color: kPrimaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Watering Schedule & Reminder',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Configure automated care reminders for ${_plant.name}',
                                style: const TextStyle(fontSize: 12, color: kTextSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Interval Presets
                    const Text('Watering Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildIntervalChoiceChip('Daily (1d)', 1, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('Every 2d', 2, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('Every 3d', 3, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('Every 5d', 5, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('Weekly (7d)', 7, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('10 Days', 10, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('Bi-weekly (14d)', 14, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                        _buildIntervalChoiceChip('Monthly (30d)', 30, selectedInterval, (v) => setSheetState(() => selectedInterval = v)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Reminder Time of Day
                    const Text('Daily Alert Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary)),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) {
                          final hr = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
                          final min = time.minute.toString().padLeft(2, '0');
                          final period = time.period == DayPeriod.am ? 'AM' : 'PM';
                          setSheetState(() {
                            selectedTime = '${hr.toString().padLeft(2, '0')}:$min $period';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: kBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 20, color: kPrimaryColor),
                                const SizedBox(width: 10),
                                Text(
                                  selectedTime,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                                ),
                              ],
                            ),
                            const Text('Change Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Reminder Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: kBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderSubtle),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable Reminder Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary)),
                                Text('Notify when watering is due', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                              ],
                            ),
                          ),
                          Switch(
                            value: reminderEnabled,
                            activeTrackColor: kPrimaryColor,
                            onChanged: (val) => setSheetState(() => reminderEnabled = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Care notes
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Personal Watering Instructions',
                        hintText: 'e.g. Check top 2 inches of soil; water until it drains.',
                        prefixIcon: Icon(Icons.notes, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: Text(
                          reminderEnabled ? 'Save Active Reminder' : 'Save (Notification Off)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final updated = _plant.copyWith(
                            wateringIntervalDays: selectedInterval,
                            reminderTime: selectedTime,
                            reminderEnabled: reminderEnabled,
                            careNotes: notesController.text.trim(),
                          );
                          _plantService.updatePlant(updated);
                          widget.onUpdate(updated);
                          setState(() {
                            _plant = updated;
                          });
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(reminderEnabled
                                  ? '⏰ Watering reminder set for every $selectedInterval days at $selectedTime!'
                                  : 'Schedule saved for every $selectedInterval days (Notification Off).'),
                              backgroundColor: kPrimaryColor,
                              behavior: SnackBarBehavior.floating,
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
      },
    );
  }

  Widget _buildIntervalChoiceChip(String label, int value, int current, Function(int) onSelected) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: kPrimaryColor,
      backgroundColor: kBackgroundColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : kTextPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? kPrimaryColor : kBorderSubtle),
      ),
    );
  }

  // =========================================================================
  // IOT SENSOR PROBE LINKING (STRICT 1-TO-1 MAPPING)
  // =========================================================================
  void _showLinkedSensorOptions(IotDevice linkedDevice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
                  child: const Icon(Icons.sensors, color: kPrimaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linkedDevice.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Assigned to ${_plant.name} (1-to-1 link)',
                        style: const TextStyle(fontSize: 12, color: kTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.show_chart_rounded, color: kPrimaryColor),
              title: const Text('View Live Sensor Telemetry & Controls', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => IotDetailsScreen(device: linkedDevice)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
              title: const Text('Change Sensor Probe', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _showSensorPickerModal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded, color: kStatusDanger),
              title: const Text('Unlink Sensor Probe', style: TextStyle(color: kStatusDanger, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmUnlinkSensor();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSensorPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final devices = _iotService.connectedIotDevices;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sensors, color: kPrimaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pair Sensor with ${_plant.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Each sensor probe can only be assigned to 1 plant',
                            style: TextStyle(fontSize: 12, color: kTextSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.sensors_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No IoT Hardware Discovered',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ensure your ESP32 probe is powered on and connected to Wi-Fi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const IotManagementScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                        child: const Text('Open IoT Hub', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final dev = devices[idx];
                      final isCurrent = dev.id == _plant.iotDeviceId;
                      final otherPlant = _plantService.getPlantForDevice(dev.id);
                      final isAssignedToOther = otherPlant != null && otherPlant.id != _plant.id;

                      return Container(
                        decoration: BoxDecoration(
                          color: isCurrent ? kPrimaryColor.withValues(alpha: 0.08) : kBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? kPrimaryColor
                                : (isAssignedToOther ? Colors.orange.shade300 : kBorderSubtle),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isCurrent ? kPrimaryColor : Colors.grey.shade300,
                            foregroundColor: isCurrent ? Colors.white : Colors.black87,
                            child: const Icon(Icons.sensors, size: 20),
                          ),
                          title: Text(
                            dev.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${dev.id}', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                              const SizedBox(height: 2),
                              if (isCurrent)
                                const Text(
                                  '✓ Currently assigned to this plant',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                )
                              else if (isAssignedToOther)
                                Text(
                                  '⚠️ Currently monitoring: ${otherPlant.name}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                )
                              else
                                const Text(
                                  'Available for pairing',
                                  style: TextStyle(fontSize: 11, color: Colors.green),
                                ),
                            ],
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.check_circle, color: kPrimaryColor)
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            if (isCurrent) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${dev.name} is already assigned to ${_plant.name}.')),
                              );
                              return;
                            }

                            if (isAssignedToOther) {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dlgContext) => AlertDialog(
                                  title: const Text('Reassign Probe?'),
                                  content: Text(
                                    'Probe "${dev.name}" is currently monitoring "${otherPlant.name}". '
                                    'Reassigning will unlink it from "${otherPlant.name}" and assign it to "${_plant.name}". '
                                    'Each probe can only monitor 1 plant. Proceed?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dlgContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                                      onPressed: () => Navigator.pop(dlgContext, true),
                                      child: const Text('Reassign', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                            }

                            _plantService.assignDeviceToPlant(
                              plantId: _plant.id,
                              deviceId: dev.id,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🌿 Successfully assigned probe ${dev.name} to ${_plant.name}!'),
                                  backgroundColor: kPrimaryColor,
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmUnlinkSensor() {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: const Text('Unlink Sensor?'),
        content: Text(
          'Are you sure you want to unlink the hardware sensor from ${_plant.name}? '
          'This will remove all real-time telemetry from ${_plant.name} and switch it back to manual watering reminder mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger),
            onPressed: () {
              Navigator.pop(dlgContext);
              _plantService.unassignDeviceFromPlant(_plant.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unlinked sensor probe from ${_plant.name}. Switched to manual care reminders.'),
                    backgroundColor: Colors.black87,
                  ),
                );
              }
            },
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
