import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';
import 'package:urbangreen/screens/reports/plant_health_report_screen.dart';
import 'package:urbangreen/screens/reports/watering_report_screen.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/iot_hybrid_connectivity_service.dart';
import 'package:urbangreen/services/plant_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final PlantService _plantService = PlantService();
  final CareLogService _careLogService = CareLogService();
  final IotHybridConnectivityService _iotService = IotHybridConnectivityService();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: const StandardAppBar(
        title: 'Garden Analytics & Reports',
        subtitle: 'Comprehensive environmental telemetry',
        toolbarHeight: 68,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_plantService, _careLogService]),
        builder: (context, _) {
          final plants = _plantService.myPlants;
          final logs = _careLogService.wateringLogs;
          final totalVolume = _careLogService.totalWeeklyVolumeMl;
          final int iotCount = _iotService.connectedIotDevices.length;

          // Compute health score
          int healthyCount = 0;
          for (final plant in plants) {
            final dev = _iotService.connectedIotDevices.cast<dynamic>().firstWhere(
              (d) => d.id == plant.iotDeviceId,
              orElse: () => null,
            );
            if (dev == null || (dev.moistureLevel ?? 0.5) >= 0.25) {
              healthyCount++;
            }
          }
          final int healthIndex = plants.isNotEmpty ? ((healthyCount / plants.length) * 100).round() : 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kDefaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dynamic Overview Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryLight, kPrimaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.25),
                        blurRadius: 14,
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
                          const Row(
                            children: [
                              Icon(Icons.insights, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Garden Health Index',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$healthIndex% Optimal',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        plants.isEmpty
                            ? 'Your botanical collection is currently empty. Add specimens to unlock live telemetry analytics.'
                            : '${plants.length} specimen(s) registered in sanctuary. $totalVolume ml hydrated across ${logs.length} logged events this week.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Diagnostic Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
                const SizedBox(height: 12),

                // Report 1: Watering
                _buildReportCard(
                  context,
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.blue.shade700,
                  title: 'Irrigation & Watering History',
                  subtitle: '$totalVolume ml consumed this week • ${logs.length} care cycle logs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WateringReportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Report 2: Health
                _buildReportCard(
                  context,
                  icon: Icons.health_and_safety_outlined,
                  iconColor: const Color(0xFF2E7D32),
                  title: 'Plant Pathology & Vitals Report',
                  subtitle: '${plants.length} specimens monitored • $healthIndex% vigor score • AI leaf diagnosis',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PlantHealthReportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Report 3: IoT Gateway
                _buildReportCard(
                  context,
                  icon: Icons.sensors,
                  iconColor: Colors.teal.shade700,
                  title: 'IoT Sensor Gateway & Diagnostics',
                  subtitle: '$iotCount telemetry node(s) configured • Hardware pump pulse actuation',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const IotManagementScreen()),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Report 4: Export Summary Card
                Card(
                  color: isDark ? kDarkCardColor : kSurfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark ? const BorderSide(color: kDarkBorderSubtle) : BorderSide.none,
                  ),
                  elevation: isDark ? 0 : 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isDark ? const Color(0xFF3E2723) : Colors.amber.shade100,
                          child: Icon(
                            Icons.share_outlined,
                            color: isDark ? const Color(0xFFFFB74D) : Colors.amber.shade900,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export Botanical Audit Report',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Generate and copy a comprehensive summary of all plants, hydration logs and hardware metrics',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_all, color: kPrimaryColor),
                          tooltip: 'Copy Report',
                          onPressed: () => _exportBotanicalReport(context, healthIndex, totalVolume),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _exportBotanicalReport(BuildContext context, int healthIndex, int totalVolume) {
    final plants = _plantService.myPlants;
    final logs = _careLogService.wateringLogs;

    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln('  URBANGREEN BOTANICAL AUDIT & HEALTH REPORT  ');
    buffer.writeln('==============================================');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String().substring(0, 19)}');
    buffer.writeln('Garden Health Index: $healthIndex% Optimal');
    buffer.writeln('Total Specimens: ${plants.length}');
    buffer.writeln('7-Day Hydration Volume: $totalVolume ml');
    buffer.writeln('----------------------------------------------');
    buffer.writeln('REGISTERED SPECIMENS:');
    for (int i = 0; i < plants.length; i++) {
      final p = plants[i];
      buffer.writeln('${i + 1}. ${p.name} (${p.species}) - IoT Device: ${p.iotDeviceId ?? "None"}');
    }
    buffer.writeln('----------------------------------------------');
    buffer.writeln('RECENT HYDRATION LOGS (Last 5):');
    for (final l in logs.take(5)) {
      buffer.writeln('• ${l.timestamp.toIso8601String().substring(0, 16)} | ${l.plantName} | ${l.volumeMl}ml | ${l.careMode}');
    }
    buffer.writeln('==============================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Botanical audit report copied to clipboard!'),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDarkMode;
    return Card(
      color: isDark ? kDarkCardColor : kSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? const BorderSide(color: kDarkBorderSubtle) : BorderSide.none,
      ),
      elevation: isDark ? 0 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: isDark ? kDarkTextSecondary : Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
