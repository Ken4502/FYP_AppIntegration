import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';

/// Displays a modal bottom sheet that clearly and distinctively separates:
/// 1) Features requiring direct connection to the ESP32 Hotspot (SoftAP 192.168.4.1)
/// 2) Features requiring a regular Wi-Fi network connection (Local LAN & Cloud)
void showIotConnectionModesGuide(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _IotConnectionModesGuideSheet(),
  );
}

class _IotConnectionModesGuideSheet extends StatelessWidget {
  const _IotConnectionModesGuideSheet();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.88),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceColor : kSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: kPrimaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IoT Connection Modes Guide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Which features use IoT Hotspot vs Home Wi-Fi?',
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: kTextSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: kBorderSubtle),

          // Scrollable Content
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              children: [
                // Quick Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C243B) : Colors.blue.shade50.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: isDark ? Colors.blue.shade300 : Colors.blue.shade800, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The Golden Rule',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '• Connect to the IoT Hotspot ONLY during initial setup or to reconfigure/delete Wi-Fi.\n'
                              '• Keep both phone and ESP32 on your Wi-Fi Network for all daily plant care, live sensor data, and watering!',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.blue.shade100 : const Color(0xFF1E3A8A), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // MODE 1: IoT HOTSPOT
                _buildModeSection(
                  context: context,
                  badgeColor: const Color(0xFFD97706),
                  badgeText: 'SETUP ONLY • DIRECT PEER-TO-PEER',
                  icon: Icons.wifi_tethering_rounded,
                  title: '1. IoT Hotspot Mode (SoftAP)',
                  subtitle: 'Phone connects directly to "SmartPlant-ESP32" (192.168.4.1). No internet connection.',
                  features: const [
                    _FeatureItem(
                      icon: Icons.settings_power_rounded,
                      title: 'First-Time Hardware Setup Wizard',
                      description: 'Establishes direct initial contact with unconfigured ESP32 board in Step 1.',
                    ),
                    _FeatureItem(
                      icon: Icons.send_rounded,
                      title: 'Wi-Fi Credential Provisioning',
                      description: 'Sending your home Wi-Fi SSID and password to ESP32 flash memory (/api/wifi/config).',
                    ),
                    _FeatureItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Deleting / Resetting Saved Wi-Fi',
                      description: 'Wiping stored Wi-Fi when switching to a new router or clearing old credentials.',
                    ),
                    _FeatureItem(
                      icon: Icons.perm_device_information_rounded,
                      title: 'Main Host Phone Registration',
                      description: 'Registering your phone ID directly into hardware flash as the owner device.',
                    ),
                    _FeatureItem(
                      icon: Icons.offline_bolt_outlined,
                      title: 'Direct Offline Pin & Pump Diagnostics',
                      description: 'Emergency offline pump pulsing and sensor test when no router exists.',
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // MODE 2: WI-FI NETWORK CONNECTION
                _buildModeSection(
                  context: context,
                  badgeColor: kStatusSuccess,
                  badgeText: 'EVERYDAY USE • FULL ONLINE TELEMETRY',
                  icon: Icons.wifi_rounded,
                  title: '2. Wi-Fi Network Connection (Local LAN & Cloud)',
                  subtitle: 'Phone & ESP32 both connect to the same 2.4GHz Wi-Fi router or hotspot (192.168.1.x) with internet access.',
                  features: const [
                    _FeatureItem(
                      icon: Icons.water_drop_outlined,
                      title: 'Real-Time Soil Moisture & Telemetry',
                      description: 'Live moisture %, ambient temperature, water tank level, and pump status streaming.',
                    ),
                    _FeatureItem(
                      icon: Icons.shower_rounded,
                      title: 'Manual Irrigation Controls ("Water Plant 5s")',
                      description: 'Tapping the water button in app to trigger irrigation over fast local LAN or cloud.',
                    ),
                    _FeatureItem(
                      icon: Icons.autorenew_rounded,
                      title: 'Automated Soil Irrigation (Auto Mode)',
                      description: 'ESP32 autonomously monitors dry soil (<25%) and pulses water pump automatically.',
                    ),
                    _FeatureItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Low Moisture Alerts & Ignore Decisions',
                      description: 'Receives alerts with choices: [Water Now] or [Ignore for 1h / 1d / 1w / 1m / always].',
                    ),
                    _FeatureItem(
                      icon: Icons.history_rounded,
                      title: 'Plant Hydration Logs & Reports in Firebase',
                      description: 'Syncing weekly watering totals, milliliters dispensed, and botanical health records.',
                    ),
                    _FeatureItem(
                      icon: Icons.link_rounded,
                      title: 'Plant-to-Probe Specimen Pairing',
                      description: 'Strict 1-to-1 linkage between plants and IoT probes stored safely in Cloud Firestore.',
                    ),
                    _FeatureItem(
                      icon: Icons.cloud_done_rounded,
                      title: 'Remote / Away-from-Home Cloud Sync',
                      description: 'Receiving probe alerts anywhere via ntfy.sh cloud bridge even on cellular data.',
                    ),
                    _FeatureItem(
                      icon: Icons.local_florist_rounded,
                      title: 'UrbanGreen Store, Orders & Weather',
                      description: 'Plant nursery shopping, ordering, checkout, and live weather conditions.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSection({
    required BuildContext context,
    required Color badgeColor,
    required String badgeText,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<_FeatureItem> features,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceColor : kBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? kDarkTextPrimary : kTextPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? kDarkCardColor : kSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
            ),
            child: Column(
              children: features.map((f) => _buildFeatureRow(f)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(_FeatureItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: kPrimaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: kTextPrimary),
                ),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 10.5, color: kTextSecondary, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
