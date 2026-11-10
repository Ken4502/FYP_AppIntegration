import 'dart:io';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/low_moisture_decision_service.dart';
import 'package:urbangreen/services/plant_service.dart';

class LowMoistureDecisionScreen extends StatefulWidget {
  final IotDevice device;
  final Plant plant;

  const LowMoistureDecisionScreen({
    super.key,
    required this.device,
    required this.plant,
  });

  @override
  State<LowMoistureDecisionScreen> createState() => _LowMoistureDecisionScreenState();
}

class _LowMoistureDecisionScreenState extends State<LowMoistureDecisionScreen> {
  final IotHybridConnectivityService _iotService = IotHybridConnectivityService();
  final PlantService _plantService = PlantService();
  final CareLogService _careLogService = CareLogService();
  final LowMoistureDecisionService _decisionService = LowMoistureDecisionService();

  bool _isWatering = false;
  late IotDevice _device;
  late Plant _plant;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _plant = widget.plant;
  }

  double get _currentMoisturePct {
    final m = _device.moistureLevel ?? 0.0;
    return (m > 1.0 ? m : m * 100.0).clamp(0.0, 100.0);
  }

  Color get _moistureStatusColor {
    final pct = _currentMoisturePct;
    if (pct < 20) return Colors.red.shade700;
    if (pct < 30) return Colors.orange.shade800;
    if (pct < 45) return Colors.amber.shade800;
    return const Color(0xFF2E7D32);
  }

  String get _moistureStatusText {
    final pct = _currentMoisturePct;
    if (pct < 15) return 'Critically Depleted ⚠️';
    if (pct < 25) return 'Dry Soil • Hydration Urgently Due ⚠️';
    if (pct < 35) return 'Moisture Low • Below Optimal Range';
    return 'Moisture Level Recovering';
  }

  Future<void> _handleWaterPlant() async {
    setState(() => _isWatering = true);

    try {
      // 1. Actuate hardware pump via IoT service
      final feedback = await _iotService.pulseWater(_device.id);
      final String resultMsg = feedback.message;

      // 2. Log hydration care event
      await _careLogService.logWatering(
        plantId: _plant.id,
        plantName: _plant.name,
        species: _plant.species,
        imageUrl: _plant.imageUrl,
        volumeMl: 200,
        careMode: 'Decision Hydration (Pump Actuation)',
        notes: 'Watered via Low Moisture Decision prompt (Moisture was ${_currentMoisturePct.round()}%)',
      );

      // 3. Update plant record with new lastWatered date
      final updatedPlant = _plant.copyWith(
        lastWatered: DateTime.now(),
      );
      _plantService.updatePlant(updatedPlant);

      // 4. Reset any pending snooze/ignore
      _decisionService.resetIgnore(deviceId: _device.id);

      if (mounted) {
        setState(() {
          _plant = updatedPlant;
          _isWatering = false;
        });

        // Show celebratory success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.15),
                  child: const Icon(Icons.water_drop_rounded, color: kPrimaryColor, size: 42),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hydrated ${_plant.name}!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  resultMsg.isNotEmpty ? resultMsg : 'Water pump ran for 3 seconds. Soil hydration registered.',
                  style: const TextStyle(fontSize: 13, color: kTextSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.pop(context); // Exit decision screen
                    },
                    child: const Text('Back to Garden', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWatering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hydration error: $e'),
            backgroundColor: kStatusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showIgnoreDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = context.isDarkMode;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? kDarkSurfaceColor : kSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.snooze_rounded, color: Colors.orange.shade800, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ignore Dry Soil Alert',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                        ),
                        Text(
                          'How long would you like to snooze alerts for ${_plant.name}?',
                          style: const TextStyle(fontSize: 12, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildIgnoreOptionTile(
                icon: Icons.timer_outlined,
                title: '1 Hour',
                subtitle: 'Snooze alerts temporarily for 60 minutes',
                onTap: () => _applyIgnore(sheetContext, const Duration(hours: 1), '1 hour', false),
              ),
              const SizedBox(height: 8),
              _buildIgnoreOptionTile(
                icon: Icons.today_outlined,
                title: '1 Day',
                subtitle: 'Silence alerts for the next 24 hours',
                onTap: () => _applyIgnore(sheetContext, const Duration(days: 1), '1 day', false),
              ),
              const SizedBox(height: 8),
              _buildIgnoreOptionTile(
                icon: Icons.date_range_outlined,
                title: '1 Week',
                subtitle: 'Silence alerts for 7 full days',
                onTap: () => _applyIgnore(sheetContext, const Duration(days: 7), '1 week', false),
              ),
              const SizedBox(height: 8),
              _buildIgnoreOptionTile(
                icon: Icons.calendar_month_outlined,
                title: '1 Month',
                subtitle: 'Silence alerts for 30 calendar days',
                onTap: () => _applyIgnore(sheetContext, const Duration(days: 30), '1 month', false),
              ),
              const SizedBox(height: 8),
              _buildIgnoreOptionTile(
                icon: Icons.notifications_off_outlined,
                title: 'Always (Indefinite)',
                subtitle: 'Mute alerts permanently until manually re-enabled in IoT settings',
                isDangerous: true,
                onTap: () => _applyIgnore(sheetContext, null, 'Always (Muted)', true),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyIgnore(BuildContext sheetContext, Duration? duration, String label, bool always) {
    Navigator.pop(sheetContext);

    _decisionService.setIgnoreDuration(
      deviceId: _device.id,
      duration: duration,
      always: always,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏸️ Low moisture alerts for "${_plant.name}" will be ignored for $label.'),
        backgroundColor: Colors.blueGrey.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'SETTINGS',
          textColor: Colors.orangeAccent,
          onPressed: () {
            // Can be adjusted in IoT settings
          },
        ),
      ),
    );

    Navigator.pop(context); // Pop decision screen
  }

  Widget _buildIgnoreOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDangerous
              ? (isDark ? const Color(0xFF3B1E1E) : Colors.red.shade50.withValues(alpha: 0.4))
              : (isDark ? kDarkCardColor : kBackgroundColor),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDangerous
                ? (isDark ? const Color(0xFF6B2B2B) : Colors.red.shade200)
                : (isDark ? kDarkBorderSubtle : kBorderSubtle),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDangerous ? Colors.red.shade100 : Colors.blueGrey.shade100,
              child: Icon(icon, size: 18, color: isDangerous ? Colors.red.shade700 : Colors.blueGrey.shade800),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDangerous ? Colors.red.shade800 : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: isDangerous ? Colors.red.shade700 : kTextSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: isDangerous ? Colors.red.shade400 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantThumbnail(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _plantPlaceholder(),
      );
    }
    if (imageUrl.startsWith('/') || imageUrl.contains('\\')) {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _plantPlaceholder(),
        );
      }
    }
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _plantPlaceholder(),
    );
  }

  Widget _plantPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.local_florist_rounded, size: 40, color: kPrimaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _moistureStatusColor;
    final moisturePct = _currentMoisturePct;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: AppBar(
        title: const Text('Plant Hydration Decision', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        elevation: 0,
        backgroundColor: isDark ? kDarkSurfaceColor : kSurfaceColor,
        foregroundColor: isDark ? kDarkTextPrimary : kTextPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Announcement Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                    child: Icon(Icons.warning_amber_rounded, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soil Moisture Alert Triggered',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Current moisture (${moisturePct.round()}%) dropped below your set ${_device.lowMoistureThreshold}% threshold.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Specimen Identity Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: _buildPlantThumbnail(_plant.imageUrl),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _plant.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _plant.species,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sensors, size: 11, color: kPrimaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      _device.name,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Probe Signal: ${_device.signalStrength} dBm',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
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
            const SizedBox(height: 16),

            // Live Moisture Condition Gauge Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Live Soil Moisture',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${moisturePct.round()}% Sensed',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (moisturePct / 100.0).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0% (Bone Dry)', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        Text('Threshold: ${_device.lowMoistureThreshold}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        Text('100% (Saturated)', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _moistureStatusText,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ESP32 moisture sensor reading indicates root zone dry-out. Immediate watering is recommended to prevent cellular foliage stress.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botanical Care & Requirements Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Botanical Care Reference',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCareDetail(Icons.wb_sunny_outlined, 'Sunlight', _plant.sunlight, Colors.orange.shade800),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCareDetail(Icons.thermostat_outlined, 'Ideal Temp', _plant.idealTemperature, Colors.teal.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCareDetail(Icons.water_drop_outlined, 'Cycle', _plant.wateringRecommendation, Colors.blue.shade700),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCareDetail(Icons.grass_outlined, 'Soil Type', _plant.soilType, Colors.brown.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons Section (Overflow-proof)
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    onPressed: _isWatering ? null : _showIgnoreDurationPicker,
                    icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Ignore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey.shade800,
                      side: BorderSide(color: Colors.blueGrey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: ElevatedButton.icon(
                    onPressed: _isWatering ? null : _handleWaterPlant,
                    icon: _isWatering
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.water_drop_rounded, size: 18, color: Colors.white),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isWatering ? 'Hydrating...' : 'Water Plant Now',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCareDetail(IconData icon, String label, String value, Color color) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextPrimary),
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
}
