import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/camera/camera_screen.dart';
import 'package:urbangreen/screens/garden/plant_detail_screen.dart';
import 'package:urbangreen/screens/iot/iot_details_screen.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/plant_service.dart';

class PlantHealthReportScreen extends StatefulWidget {
  const PlantHealthReportScreen({super.key});

  @override
  State<PlantHealthReportScreen> createState() => _PlantHealthReportScreenState();
}

class _PlantHealthReportScreenState extends State<PlantHealthReportScreen> {
  final PlantService _plantService = PlantService();
  final IotHybridConnectivityService _iotService = IotHybridConnectivityService();
  final CareLogService _careLogService = CareLogService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Botanical Health Report',
        subtitle: 'Canopy vigor, sensor telemetry & care schedules',
        toolbarHeight: 68,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined, color: kPrimaryColor, size: 24),
            tooltip: 'AI Leaf Scan',
            onPressed: () => _pickAndScanLeaf(ImageSource.camera),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_plantService, _careLogService]),
        builder: (context, _) {
          final plants = _plantService.myPlants;
          final int totalPlants = plants.length;

          final iotPlants = plants.where((p) => p.hasIot).toList();
          final manualPlants = plants.where((p) => !p.hasIot).toList();

          // Compute garden health index logically:
          // For IoT plants: moisture < 30% needs attention
          // For manual plants: isWateringDue needs attention
          int attentionNeeded = 0;
          for (final plant in iotPlants) {
            final dev = _findLinkedDevice(plant.iotDeviceId);
            if (dev?.moistureLevel != null) {
              final double moisture = dev!.moistureLevel! > 1.0 ? dev.moistureLevel! : dev.moistureLevel! * 100;
              if (moisture < 30) {
                attentionNeeded++;
              }
            }
          }
          for (final plant in manualPlants) {
            if (plant.isWateringDue) {
              attentionNeeded++;
            }
          }

          final int healthyCount = totalPlants > 0 ? (totalPlants - attentionNeeded) : 0;
          final int healthIndex = totalPlants > 0 ? ((healthyCount / totalPlants) * 100).round() : 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kDefaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Garden Health Summary Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 74,
                              height: 74,
                              child: CircularProgressIndicator(
                                value: totalPlants == 0 ? 1.0 : (healthIndex / 100.0).clamp(0.05, 1.0),
                                strokeWidth: 8,
                                backgroundColor: Colors.grey.shade100,
                                color: healthIndex >= 80
                                    ? kPrimaryColor
                                    : (healthIndex >= 50 ? Colors.orange.shade700 : kStatusDanger),
                              ),
                            ),
                            Text(
                              '$healthIndex%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: healthIndex >= 80
                                    ? kPrimaryColor
                                    : (healthIndex >= 50 ? Colors.orange.shade700 : kStatusDanger),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Garden Health Index',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalPlants == 0
                                    ? 'No plants registered yet. Add specimens to begin monitoring.'
                                    : '$healthyCount of $totalPlants specimens at optimal vigor. (${iotPlants.length} IoT monitored, ${manualPlants.length} on manual care)${attentionNeeded > 0 ? " • $attentionNeeded need hydration." : " • All hydration schedules on track."}',
                                style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // AI Foliage Scan Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kAccentMint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.biotech, color: kPrimaryColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PhytoCare AI Pathology Scanner',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Diagnose foliage blight, chlorosis or insect pests with a photo.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _showScanSourceSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Scan Leaf', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (plants.isEmpty) ...[
                  _buildEmptyGardenState(),
                ] else ...[
                  // =========================================================
                  // SECTION 1: SMART IOT MONITORED SPECIMENS
                  // =========================================================
                  if (iotPlants.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sensors, size: 18, color: kPrimaryColor),
                            const SizedBox(width: 6),
                            const Text(
                              'IoT Monitored Specimens',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${iotPlants.length} active probe${iotPlants.length > 1 ? "s" : ""}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...iotPlants.map((plant) => _buildIotPlantCard(plant)),
                    const SizedBox(height: 16),
                  ],

                  // =========================================================
                  // SECTION 2: MANUAL CARE & SCHEDULED SPECIMENS
                  // (Plants WITHOUT IoT: Only generic info & watering reminders!)
                  // =========================================================
                  if (manualPlants.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 18, color: Colors.blueGrey.shade700),
                            const SizedBox(width: 6),
                            const Text(
                              'Botanical Schedules & Reminders',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${manualPlants.length} specimen${manualPlants.length > 1 ? "s" : ""}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...manualPlants.map((plant) => _buildManualCarePlantCard(plant)),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  IotDevice? _findLinkedDevice(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return null;
    return _iotService.connectedIotDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => IotDevice(id: deviceId, name: deviceId),
    );
  }

  // =========================================================================
  // CARD A: IOT MONITORED SPECIMEN (Real-Time Sensor Telemetry)
  // =========================================================================
  Widget _buildIotPlantCard(Plant plant) {
    final linkedDevice = _findLinkedDevice(plant.iotDeviceId);
    double moistureFraction = 0.50;
    if (linkedDevice?.moistureLevel != null) {
      final m = linkedDevice!.moistureLevel!;
      moistureFraction = (m > 1.0 ? m / 100.0 : m).clamp(0.0, 1.0);
    }

    String healthStatus = 'Optimal Moisture';
    Color healthColor = const Color(0xFF2E7D32);
    if (moistureFraction < 0.25) {
      healthStatus = 'Moisture Critical';
      healthColor = kStatusDanger;
    } else if (moistureFraction < 0.40) {
      healthStatus = 'Hydration Due';
      healthColor = Colors.orange.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPlantThumbnail(plant.imageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plant.species,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: healthColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    healthStatus,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: healthColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // IoT Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.sensors, size: 15, color: Colors.teal.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Live Probe: ${linkedDevice?.name ?? plant.iotDeviceId} (${_iotService.isRealHardwareConnected ? "Online" : "Cached"})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Real IoT Moisture Progress Bar
            _buildMetricBar('Real-Time Soil Hydration', moistureFraction, kPrimaryColor, '${(moistureFraction * 100).toInt()}%'),
            const SizedBox(height: 14),

            // Actions Strip
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlantDetailScreen(
                            plant: plant,
                            onDelete: (p) => _plantService.deletePlant(p.id),
                            onUpdate: (p) => _plantService.updatePlant(p),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (linkedDevice != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => IotDetailsScreen(device: linkedDevice)),
                      );
                    },
                    icon: const Icon(Icons.show_chart_rounded, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Live Graph', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pulseWaterIot(plant, linkedDevice),
                    icon: const Icon(Icons.water_drop, size: 15, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Pulse Pump', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CARD B: MANUAL CARE SPECIMEN (Plants without IoT: strictly NO IoT telemetry!)
  // =========================================================================
  Widget _buildManualCarePlantCard(Plant plant) {
    final statusColor = plant.wateringStatusColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPlantThumbnail(plant.imageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plant.species,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (plant.reminderEnabled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      plant.wateringScheduleSummary,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Reminder & Schedule Banner (NO fake IoT readings)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    plant.reminderEnabled ? Icons.alarm_on_rounded : Icons.notifications_off_outlined,
                    size: 16,
                    color: plant.reminderEnabled ? kPrimaryColor : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plant.reminderEnabled
                          ? 'Reminder active: Daily at ${plant.reminderTime} • Every ${plant.wateringIntervalDays}d'
                          : 'No notification setup • Tap to configure',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: plant.reminderEnabled ? FontWeight.w600 : FontWeight.normal,
                        color: plant.reminderEnabled ? kTextPrimary : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Generic Botanical Specs (Sunlight & Temperature)
            Row(
              children: [
                Expanded(
                  child: _buildGenericMiniInfo(Icons.wb_sunny_outlined, 'Sunlight', plant.sunlight, Colors.orange.shade800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildGenericMiniInfo(Icons.thermostat_outlined, 'Environment', plant.idealTemperature, Colors.teal.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions Strip (Overflow-Proof)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlantDetailScreen(
                            plant: plant,
                            onDelete: (p) => _plantService.deletePlant(p.id),
                            onUpdate: (p) => _plantService.updatePlant(p),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _quickWaterManual(plant),
                    icon: const Icon(Icons.water_drop, size: 15, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Watered Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericMiniInfo(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                Text(
                  value,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pulseWaterIot(Plant plant, IotDevice? dev) async {
    try {
      await _careLogService.logWatering(
        plantId: plant.id,
        plantName: plant.name,
        species: plant.species,
        imageUrl: plant.imageUrl,
        volumeMl: 50,
        careMode: 'Hardware Pump Pulse',
        notes: 'Pulsed hardware pump from Botanical Health Report',
      );

      final now = DateTime.now();
      final updated = plant.copyWith(lastWatered: now);
      _plantService.updatePlant(updated);

      if (dev != null) {
        await _iotService.pulseWater(dev.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💧 Hardware pump actuated for ${plant.name}! Care log updated.'),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hardware error: $e'),
            backgroundColor: kStatusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _quickWaterManual(Plant plant) async {
    try {
      final now = DateTime.now();
      final updated = plant.copyWith(lastWatered: now);
      _plantService.updatePlant(updated);

      await _careLogService.logWatering(
        plantId: plant.id,
        plantName: plant.name,
        species: plant.species,
        imageUrl: plant.imageUrl,
        volumeMl: 200,
        careMode: 'Manual Hydration',
        notes: 'Manual watering logged from Botanical Health Report',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(plant.reminderEnabled
                ? '💧 Hydrated ${plant.name}! Next watering due in ${plant.wateringIntervalDays} days.'
                : '💧 Hydrated ${plant.name}! (No reminder set)'),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hydration failure: $e'),
            backgroundColor: kStatusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildMetricBar(String title, double pct, Color color, String valueText) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            Text(
              valueText,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPlantThumbnail(String imageUrl) {
    const double size = 48;
    Widget imageWidget;

    if (imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    } else if (imageUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    } else if (imageUrl.isNotEmpty && File(imageUrl).existsSync()) {
      imageWidget = Image.file(
        File(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    } else {
      imageWidget = _fallbackIcon();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: kPrimaryColor.withValues(alpha: 0.08),
        child: imageWidget,
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: kPrimaryColor.withValues(alpha: 0.1),
      child: const Icon(Icons.eco, color: kPrimaryColor, size: 24),
    );
  }

  Widget _buildEmptyGardenState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.yard_outlined, size: 48, color: kPrimaryLight),
            const SizedBox(height: 12),
            const Text(
              'No Garden Specimens Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first plant to your sanctuary or use the AI Leaf Scanner to assess botanical vigor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose Image Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: kPrimaryLight, child: Icon(Icons.camera_alt, color: Colors.white)),
                  title: const Text('Capture with Camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndScanLeaf(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Icon(Icons.photo_library, color: Colors.blue.shade800)),
                  title: const Text('Select from Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndScanLeaf(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndScanLeaf(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(image: pickedFile),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera/gallery error: $e. Please verify camera permissions in device settings.'),
            backgroundColor: kStatusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
