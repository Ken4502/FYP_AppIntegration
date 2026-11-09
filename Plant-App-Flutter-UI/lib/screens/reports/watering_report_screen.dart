import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/plant_service.dart';

class WateringReportScreen extends StatefulWidget {
  const WateringReportScreen({super.key});

  @override
  State<WateringReportScreen> createState() => _WateringReportScreenState();
}

class _WateringReportScreenState extends State<WateringReportScreen> {
  final CareLogService _careLogService = CareLogService();
  final PlantService _plantService = PlantService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Watering & Irrigation',
        subtitle: 'Soil hydration cycles & consumption history',
        toolbarHeight: 68,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor, size: 26),
            tooltip: 'Log Hydration',
            onPressed: _showQuickLogDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickLogDialog,
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.water_drop, color: Colors.white),
        label: const Text(
          'Quick Log Hydration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_careLogService, _plantService]),
        builder: (context, _) {
          final weeklyData = _careLogService.getWeeklyHydrationList();
          final totalVolume = _careLogService.totalWeeklyVolumeMl;
          final logs = _careLogService.wateringLogs;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(kDefaultPadding, kDefaultPadding, kDefaultPadding, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekly Bar Visualization Card
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
                              'Weekly Hydration Volume',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: kTextPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? kDarkSurfaceColor : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? kDarkBorderSubtle : Colors.blue.shade200),
                              ),
                              child: Text(
                                '$totalVolume ml Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aggregated across all registered specimens for the past 7 days.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        _buildDynamicWeeklyBarChart(weeklyData),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Analytics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.opacity,
                        iconColor: Colors.blue.shade700,
                        title: 'Daily Average',
                        value: '${(totalVolume / 7).round()} ml',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.history,
                        iconColor: kPrimaryColor,
                        title: 'Logged Events',
                        value: '${logs.length} care logs',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section Title + Log Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hydration Logs',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextPrimary),
                    ),
                    Text(
                      '${logs.length} records',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // History List
                if (logs.isEmpty)
                  _buildEmptyState()
                else
                  _buildWateringList(logs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicWeeklyBarChart(List<Map<String, dynamic>> days) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int maxMl = 0;
    for (final d in days) {
      final ml = d['ml'] as int? ?? 0;
      if (ml > maxMl) maxMl = ml;
    }
    final int ceiling = max(maxMl, 300);

    return SizedBox(
      height: 145,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((d) {
          final ml = d['ml'] as int? ?? 0;
          final double fraction = ceiling > 0 ? (ml / ceiling).clamp(0.0, 1.0) : 0.0;
          final double barHeight = max(6.0, 85.0 * fraction);
          final bool hasWater = ml > 0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                ml > 0 ? '$ml' : '-',
                style: TextStyle(
                  fontSize: 10,
                  color: hasWater ? (isDark ? Colors.blue.shade300 : Colors.blue.shade900) : (isDark ? kDarkTextSecondary : Colors.grey.shade500),
                  fontWeight: hasWater ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 26,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: hasWater
                      ? LinearGradient(
                          colors: [Colors.blue.shade300, Colors.blue.shade700],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: hasWater ? null : (isDark ? kDarkBorderSubtle : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: hasWater
                      ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${d['day']}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasWater ? (isDark ? kDarkTextPrimary : kTextPrimary) : (isDark ? kDarkTextSecondary : Colors.grey.shade600),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWateringList(List<WateringLog> logs) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final event = logs[index];
        final isHardware = event.careMode.toLowerCase().contains('hardware') ||
            event.careMode.toLowerCase().contains('pump') ||
            event.careMode.toLowerCase().contains('auto');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildPlantThumbnail(event.imageUrl ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.plantName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatTimestamp(event.timestamp),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHardware ? kPrimaryLight.withValues(alpha: 0.15) : (isDark ? kDarkSurfaceColor : Colors.blue.shade50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event.careMode,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isHardware ? kPrimaryColor : (isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event.notes != null && event.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.notes!,
                          style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : Colors.grey.shade700, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? kDarkBorderSubtle : Colors.blue.shade100),
                  ),
                  child: Text(
                    '${event.volumeMl} ml',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlantThumbnail(String imageUrl) {
    const double size = 46;
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
      color: Colors.blue.shade50,
      child: Icon(Icons.water_drop, color: Colors.blue.shade700, size: 24),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.water_drop_outlined, size: 48, color: Colors.blue.shade300),
            const SizedBox(height: 12),
            Text(
              'No Hydration Logs Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? kDarkTextPrimary : kTextPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Water your garden specimens or tap "Quick Log Hydration" to start tracking consumption cycles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? kDarkTextSecondary : Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showQuickLogDialog,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Add Hydration Record', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 0 && now.day == dt.day) {
      return 'Today • $timeStr';
    } else if (diff.inDays == 1 || (now.day - dt.day == 1 && diff.inHours < 48)) {
      return 'Yesterday • $timeStr';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day} • $timeStr';
    }
  }

  void _showQuickLogDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plants = _plantService.myPlants;
    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your garden is empty. Please add a plant first to log care!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Plant selectedPlant = plants.first;
    int selectedVolume = 200;
    String selectedMode = 'Manual Hydration';
    final TextEditingController notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? kDarkCardColor : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Record Hydration Event',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? kDarkTextPrimary : kTextPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Select Plant
                  const Text('Select Specimen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? kDarkBorderSubtle : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Plant>(
                        isExpanded: true,
                        value: selectedPlant,
                        dropdownColor: isDark ? kDarkCardColor : Colors.white,
                        items: plants.map((p) {
                          return DropdownMenuItem<Plant>(
                            value: p,
                            child: Row(
                              children: [
                                const Icon(Icons.eco, color: kPrimaryColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.name} (${p.species})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (p) {
                          if (p != null) {
                            setModalState(() => selectedPlant = p);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Volume
                  const Text('Volume Dispensed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [100, 200, 300, 500].map((vol) {
                      final isSelected = selectedVolume == vol;
                      return ChoiceChip(
                        label: Text('$vol ml'),
                        selected: isSelected,
                        selectedColor: isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? (isDark ? Colors.blue.shade200 : Colors.blue.shade900) : (isDark ? kDarkTextPrimary : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => selectedVolume = vol);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Select Mode
                  const Text('Care Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Manual Hydration', 'Hardware Pump Pulse', 'Mist & Spray'].map((mode) {
                      final isSelected = selectedMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isSelected,
                        selectedColor: kPrimaryLight.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? kPrimaryColor : (isDark ? kDarkTextPrimary : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => selectedMode = mode);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Optional Notes
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g., Added liquid bio-fertilizer',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await _careLogService.logWatering(
                            plantId: selectedPlant.id,
                            plantName: selectedPlant.name,
                            species: selectedPlant.species,
                            imageUrl: selectedPlant.imageUrl,
                            volumeMl: selectedVolume,
                            careMode: selectedMode,
                            notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                          );

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('💧 Logged ${selectedVolume}ml for ${selectedPlant.name}!'),
                              backgroundColor: kPrimaryColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save hydration record: $e. Please verify local storage permissions.'),
                              backgroundColor: kStatusDanger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Save Hydration Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
