import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/components/my_bottom_nav_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';
import 'package:urbangreen/screens/garden/plant_list_screen.dart';
import 'package:urbangreen/screens/camera/camera_screen.dart';
import 'package:urbangreen/screens/shop/plant_ecommerce_screen.dart';
import 'package:urbangreen/screens/account/account_screen.dart';
import 'package:urbangreen/services/ntfy_notification_service.dart';
import 'package:urbangreen/services/low_moisture_decision_service.dart';
import 'package:urbangreen/services/plant_api_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PlantListScreen(),
    const IotManagementScreen(),
    const PlantEcommerceScreen(),
    const AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initGlobalNotificationListener();
  }

  void _initGlobalNotificationListener() async {
    // Start global push bridge listener (ntfy.sh) & request Android 13+ POST_NOTIFICATIONS
    await NtfyNotificationService().start();
  }



  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
        maxHeight: 1920,
      );

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
            content: Text('Error accessing camera/gallery: $e'),
            backgroundColor: kStatusDanger,
          ),
        );
      }
    }
  }

  void _showCameraActionSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kAccentMint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.biotech, color: kPrimaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PhytoCare Ultra AI Scanner',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pathology & Botanical Classification Engine',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Camera Card
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureImage(ImageSource.camera);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: kBorderSubtle),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.camera_alt, color: kPrimaryColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Snap Live Foliage',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Capture leaf symptoms in real time with pathology viewfinder',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Gallery Card
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureImage(ImageSource.gallery);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: kBorderSubtle),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: kSecondaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.photo_library, color: kSecondaryColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upload from Gallery',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select an existing plant photo from your device storage',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Backend Server Endpoint Status Tile
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Endpoint: ${PlantApiService.serverUrl}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showServerConfigDialog();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            'Configure',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
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
      },
    );
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: PlantApiService.serverUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet, color: kPrimaryColor),
            SizedBox(width: 8),
            Text('AI Backend Host'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the host where CoreTech FastAPI is running:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Online Cloud Tunnel (HTTPS)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  backgroundColor: const Color(0xFFF0F9FF),
                  onPressed: () => controller.text = 'https://backed-strengthening-oecd-pos.trycloudflare.com',
                ),
                ActionChip(
                  label: const Text('PC Wi-Fi (192.168.1.9)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => controller.text = 'http://192.168.1.9:8001',
                ),
                ActionChip(
                  label: const Text('Google Cloud Run', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => controller.text = 'https://phytonet-ai-792382083515.us-central1.run.app',
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 10)),
                  onPressed: () => controller.text = 'http://10.0.2.2:8001',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '• Host PC Wi-Fi: http://192.168.1.9:8001\n'
                '• Google Cloud Run: https://phytonet-ai-*.a.run.app\n'
                '• Android Emulator: http://10.0.2.2:8001',
                style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              PlantApiService.setServerUrl(controller.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('AI Host set to: ${PlantApiService.serverUrl}'),
                  backgroundColor: kPrimaryColor,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          ValueListenableBuilder<LowMoistureAlertEvent?>(
            valueListenable: LowMoistureDecisionService().activeAlertNotifier,
            builder: (context, alert, _) {
              if (alert == null) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade800, Colors.deepOrange.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.water_drop_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '⚠️ Low Moisture: ${alert.plant.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Soil at ${alert.moisture}% (Threshold: ${alert.device.lowMoistureThreshold}%). Tap to decide.',
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepOrange.shade900,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            LowMoistureDecisionService().openDecisionScreen(
                              device: alert.device,
                              plant: alert.plant,
                              context: context,
                            );
                          },
                          child: const Text('DECIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          onPressed: () {
                            LowMoistureDecisionService().activeAlertNotifier.value = null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kPrimaryLight, kPrimaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.38),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _showCameraActionSheet,
            child: const Center(
              child: Icon(
                Icons.document_scanner_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: MyBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
