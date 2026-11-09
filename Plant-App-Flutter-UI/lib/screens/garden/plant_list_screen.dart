import 'dart:io';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/garden/add_plant_screen.dart';
import 'package:urbangreen/screens/garden/plant_detail_screen.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/plant_service.dart';

class PlantListScreen extends StatefulWidget {
  const PlantListScreen({super.key});

  @override
  State<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  final IotHybridConnectivityService _iotService = IotHybridConnectivityService();
  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
    _plantService.addListener(_onPlantsChanged);
  }

  @override
  void dispose() {
    _plantService.removeListener(_onPlantsChanged);
    super.dispose();
  }

  void _onPlantsChanged() {
    if (mounted) setState(() {});
  }

  String _searchFilter = '';

  void _addPlant(Plant plant) {
    _plantService.addPlant(plant);
  }

  void _updatePlant(Plant plant) {
    _plantService.updatePlant(plant);
  }

  void _deletePlant(Plant plant) {
    _plantService.deletePlant(plant.id);
  }

  void _navigateAndAddPlant(BuildContext context) async {
    final newPlant = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPlantScreen(),
      ),
    );

    if (newPlant != null) {
      _addPlant(newPlant);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myPlants = _plantService.myPlants;
    final filteredPlants = myPlants.where((p) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return p.name.toLowerCase().contains(q) || p.species.toLowerCase().contains(q);
    }).toList();

    final monitoredCount = myPlants.where((p) => p.iotDeviceId != null && p.iotDeviceId!.isNotEmpty).length;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Standardized Botanical Header (Uniform with Sensors & Shop)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, Botanist 🌿',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Urban Sanctuary',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 22),
                          tooltip: 'Add Plant',
                          onPressed: () => _navigateAndAddPlant(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Garden Vital Metrics Strip
                  Row(
                    children: [
                      _buildMetricChip(
                        icon: Icons.eco,
                        label: '${myPlants.length} Plants',
                        color: isDark ? kSecondaryColor : kPrimaryColor,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricChip(
                        icon: Icons.bluetooth_connected_rounded,
                        label: '$monitoredCount Monitored',
                        color: monitoredCount > 0 ? (isDark ? const Color(0xFF66BB6A) : Colors.green.shade800) : (isDark ? const Color(0xFF90CAF9) : Colors.blue.shade700),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricChip(
                        icon: Icons.health_and_safety,
                        label: '98% Health',
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Garden Content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Search Field
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? kDarkSurfaceColor : kSurfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setState(() {
                              _searchFilter = val.trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search my botanical collection...',
                            hintStyle: TextStyle(fontSize: 13, color: isDark ? kDarkTextSecondary : kTextSecondary),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? kSecondaryColor : kPrimaryColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          style: TextStyle(fontSize: 13, color: isDark ? kDarkTextPrimary : kTextPrimary),
                        ),
                      ),
                    ),
                  ),

          // Plant Grid / List
          if (filteredPlants.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.yard_outlined, size: 72, color: isDark ? Colors.white24 : Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No Plants Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try searching for another species or add a new plant to your collection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: isDark ? kDarkTextSecondary : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final plant = filteredPlants[index];
                    return _buildPlantCard(context, plant);
                  },
                  childCount: filteredPlants.length,
                ),
              ),
            ),
        ],
      ),
    ),
  ],
),
),
);
  }

  Widget _buildPlantImage(String imageUrl, {double width = 80, double height = 80, BoxFit fit = BoxFit.cover}) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholderImage(width, height),
      );
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholderImage(width, height),
      );
    } else {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _placeholderImage(width, height),
        );
      }
      return _placeholderImage(width, height);
    }
  }

  Widget _placeholderImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: kPrimaryColor.withValues(alpha: 0.1),
      child: const Icon(Icons.eco_rounded, color: kPrimaryColor, size: 36),
    );
  }

  Widget _buildPlantCard(BuildContext context, Plant plant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasIot = plant.iotDeviceId != null && plant.iotDeviceId!.isNotEmpty;
    IotDevice? probeDev;
    if (hasIot) {
      for (final d in _iotService.connectedIotDevices) {
        if (d.id == plant.iotDeviceId) {
          probeDev = d;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasIot
              ? kPrimaryColor.withValues(alpha: 0.35)
              : (isDark ? kDarkBorderSubtle : kBorderSubtle),
        ),
        boxShadow: [
          BoxShadow(
            color: hasIot
                ? kPrimaryColor.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlantDetailScreen(
                  plant: plant,
                  onDelete: _deletePlant,
                  onUpdate: _updatePlant,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Plant Avatar Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildPlantImage(plant.imageUrl),
                ),
                const SizedBox(width: 14),
                // Plant Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            plant.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasIot) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sensors, size: 10, color: kPrimaryColor),
                                      SizedBox(width: 3),
                                      Text(
                                        'IoT Probe',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasIot
                                      ? kPrimaryColor.withValues(alpha: 0.12)
                                      : (plant.reminderEnabled
                                          ? plant.wateringStatusColor.withValues(alpha: 0.12)
                                          : (isDark ? Colors.white10 : Colors.grey.shade200)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasIot
                                        ? kPrimaryColor.withValues(alpha: 0.3)
                                        : (plant.reminderEnabled
                                            ? plant.wateringStatusColor.withValues(alpha: 0.3)
                                            : (isDark ? Colors.white24 : Colors.grey.shade400)),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasIot
                                          ? Icons.sensors
                                          : (plant.reminderEnabled
                                              ? (plant.isWateringDue ? Icons.water_drop : Icons.check_circle_rounded)
                                              : Icons.notifications_off_outlined),
                                      size: 10,
                                      color: hasIot
                                          ? kPrimaryColor
                                          : (plant.reminderEnabled ? plant.wateringStatusColor : (isDark ? Colors.white60 : Colors.grey.shade600)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasIot
                                          ? 'IoT Active'
                                          : (plant.reminderEnabled
                                              ? (plant.isWateringDue ? 'Water Due' : 'Healthy')
                                              : 'No Reminder'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: hasIot
                                            ? kPrimaryColor
                                            : (plant.reminderEnabled ? plant.wateringStatusColor : (isDark ? Colors.white70 : Colors.grey.shade700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plant.species,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? kDarkTextSecondary : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (hasIot) ...[
                            _buildMiniBadge(
                              Icons.sensors,
                              probeDev != null
                                  ? '${probeDev.name}: ${(probeDev.moistureLevel ?? 0).round()}%'
                                  : plant.iotDeviceId!,
                              kPrimaryColor,
                            ),
                          ] else ...[
                            if (plant.reminderEnabled) ...[
                              _buildMiniBadge(
                                Icons.alarm,
                                plant.wateringScheduleSummary,
                                plant.wateringStatusColor,
                              ),
                              _buildMiniBadge(
                                Icons.notifications_active_outlined,
                                plant.reminderTime,
                                Colors.teal.shade700,
                              ),
                            ] else ...[
                              _buildMiniBadge(
                                Icons.notifications_off_outlined,
                                'No notification setup',
                                Colors.grey.shade600,
                              ),
                            ],
                          ],
                          _buildMiniBadge(Icons.water_drop_outlined, 'Every ${plant.wateringIntervalDays}d', Colors.blue.shade700),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
