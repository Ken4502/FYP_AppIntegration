import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/components/my_bottom_nav_bar.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';
import 'package:urbangreen/screens/garden/plant_list_screen.dart';
import 'package:urbangreen/screens/camera/camera_screen.dart';
import 'package:urbangreen/screens/shop/plant_ecommerce_screen.dart';
import 'package:urbangreen/screens/account/account_screen.dart';
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
    PlantEcommerceScreen(), // This one cannot be const
    const AccountScreen(),
  ];

  static const List<String> _titles = [
    'My Garden',
    'IoT Management',
    'Shop',
    'Account',
  ];

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
            backgroundColor: Theme.of(context).colorScheme.error,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.biotech, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Plant Diagnosis & Identification',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Snap a clear photo of the leaf or plant foliage to identify its species and clinical health condition.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
                  ),
                  title: const Text(
                    'Snap Photo with Phone Camera',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Capture live leaf picture in real time'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.12),
                    child: Icon(Icons.photo_library, color: theme.colorScheme.secondary),
                  ),
                  title: const Text(
                    'Select from Photo Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Pick an existing leaf photo from storage'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureImage(ImageSource.gallery);
                  },
                ),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.dns_outlined, size: 20, color: Colors.grey),
                  title: Text(
                    'AI Server: ${PlantApiService.serverUrl}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.edit, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showServerConfigDialog();
                  },
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
            Icon(Icons.settings_ethernet),
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
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Android Emulator: http://10.0.2.2:8001\n'
              '• Physical Android: http://<Your-PC-IP>:8001\n'
              '• Firebase/Cloud Run: https://<service>.a.run.app',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "main_fab",
        onPressed: _showCameraActionSheet,
        tooltip: "Snap Plant Photo",
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: MyBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
