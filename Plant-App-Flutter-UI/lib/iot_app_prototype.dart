import 'package:flutter/material.dart';
import 'constants.dart';
import 'models/iot_connection_mode.dart';
import 'models/plant_model.dart';
import 'screens/iot/iot_management_screen.dart';
import 'services/iot_hybrid_connectivity_service.dart';
import 'theme.dart';

/// Complete Mobile Application Prototype for UrbanGreen SmartPlant IoT Connectivity
class IotAppPrototype extends StatefulWidget {
  const IotAppPrototype({super.key});

  @override
  State<IotAppPrototype> createState() => _IotAppPrototypeState();
}

class _IotAppPrototypeState extends State<IotAppPrototype> {
  bool _useMobileFrame = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UrbanGreen IoT Mobile App',
      theme: AppTheme.lightTheme,
      home: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            return const Scaffold(
              body: SafeArea(
                child: _PrototypeMainNavigation(),
              ),
            );
          }

          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SafeArea(
              child: Column(
                children: [
                  _buildPrototypeControlBar(),
                  Expanded(
                    child: Center(
                      child: _useMobileFrame
                          ? const _SmartphoneDeviceShell(child: _PrototypeMainNavigation())
                          : const _PrototypeMainNavigation(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrototypeControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'MOBILE PROTOTYPE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'UrbanGreen IoT Hybrid Connectivity Flow',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() => _useMobileFrame = !_useMobileFrame);
            },
            icon: Icon(
              _useMobileFrame ? Icons.fullscreen_rounded : Icons.phone_android_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              _useMobileFrame ? 'Expand Fullscreen' : 'Smartphone Chassis',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Realistic Smartphone Chassis with Dynamic Island, Status Bar, and Glass Bezel
class _SmartphoneDeviceShell extends StatelessWidget {
  final Widget child;

  const _SmartphoneDeviceShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // If screen is already a narrow mobile viewport (< 460px), display directly
    if (screenWidth < 460) {
      return child;
    }

    // Otherwise wrap in a modern phone chassis (iPhone / Pixel form factor)
    return Container(
      width: 390,
      height: 844,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(52),
        border: Border.all(color: const Color(0xFF384252), width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 36,
            spreadRadius: 4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: Column(
          children: [
            // Smartphone Status Bar & Dynamic Island
            Container(
              height: 44,
              color: kSurfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9:41',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  // Dynamic Island / Camera Pill
                  Container(
                    width: 110,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.signal_cellular_alt_rounded, size: 14, color: Colors.black87),
                      SizedBox(width: 4),
                      Icon(Icons.wifi_rounded, size: 14, color: Colors.black87),
                      SizedBox(width: 4),
                      Icon(Icons.battery_full_rounded, size: 16, color: Colors.black87),
                    ],
                  ),
                ],
              ),
            ),

            // Main Mobile App Area
            Expanded(child: child),

            // Smartphone Home Gesture Bar
            Container(
              height: 20,
              color: kSurfaceColor,
              alignment: Alignment.center,
              child: Container(
                width: 130,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Bottom-Navigation Driven Mobile Experience
class _PrototypeMainNavigation extends StatefulWidget {
  const _PrototypeMainNavigation();

  @override
  State<_PrototypeMainNavigation> createState() => _PrototypeMainNavigationState();
}

class _PrototypeMainNavigationState extends State<_PrototypeMainNavigation> {
  int _currentIndex = 1; // Default to IoT Sensors Hub tab

  final IotHybridConnectivityService _service = IotHybridConnectivityService();

  late List<Plant> _gardenPlants;

  @override
  void initState() {
    super.initState();
    _gardenPlants = [
      Plant(
        id: 'p1',
        name: 'Samantha',
        species: 'Monstera Deliciosa',
        imageUrl: 'assets/images/image_1.png',
        description: 'Living room corner tropical plant. Thrives in moderate indirect light.',
        iotDeviceId: 'ESP32-NODE-01',
      ),
      Plant(
        id: 'p2',
        name: 'Angelica',
        species: 'Ficus Lyrata (Fiddle Leaf)',
        imageUrl: 'assets/images/image_2.png',
        description: 'Sensitive to cold drafts and overwatering. Requires careful moisture balance.',
      ),
      Plant(
        id: 'p3',
        name: 'Bob',
        species: 'Sansevieria Trifasciata',
        imageUrl: 'assets/images/image_3.png',
        description: 'Hardy air-purifier succulent. Very tolerant of dry conditions.',
      ),
      Plant(
        id: 'p4',
        name: 'Kitchen Basil',
        species: 'Ocimum basilicum',
        imageUrl: 'assets/images/img.png',
        description: 'Sweet culinary herb. Needs consistent moist soil.',
      ),
    ];
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _openPairingForPlant(Plant plant) {
    setState(() {
      _currentIndex = 1; // Jump to IoT tab
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: My Garden (AppIntegration Reference)
          _buildGardenTab(),

          // Tab 1: IoT Device Hub (The Generalized Connected IoT Hub)
          const IotManagementScreen(),

          // Tab 2: Botanical Hardware Shop
          _buildShopTab(),

          // Tab 3: Account & Diagnostics
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() => _currentIndex = 1);
        },
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.bluetooth_searching, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildPrototypeBottomBar(),
    );
  }

  Widget _buildPrototypeBottomBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: kSurfaceColor,
      elevation: 10,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBarItem(index: 0, icon: Icons.yard_outlined, activeIcon: Icons.yard, label: 'Garden'),
            _buildBarItem(index: 1, icon: Icons.sensors_outlined, activeIcon: Icons.sensors, label: 'IoT Hub'),
            const SizedBox(width: 48), // Notch space for center pairing FAB
            _buildBarItem(index: 2, icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Shop'),
            _buildBarItem(index: 3, icon: Icons.tune_rounded, activeIcon: Icons.tune, label: 'Config'),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? kPrimaryColor : kTextSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? kPrimaryColor : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: MY GARDEN (Showing how IoT probes link with plants)
  // ---------------------------------------------------------------------------
  Widget _buildGardenTab() {
    final config = _service.getDevice('ESP32-NODE-01');

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good day, Botanist', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('My Urban Garden', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
          ],
        ),
        backgroundColor: kSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner showing IoT Mesh Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimaryColor, kPrimaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart Soil Mesh Active',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.connectionMode == ConnectionMode.wifiCloud
                            ? 'Streaming cloud telemetry via "${config.wifiSsid ?? 'Wi-Fi'}"'
                            : config.connectionMode == ConnectionMode.bluetoothOnly
                                ? 'Direct Bluetooth local monitoring active'
                                : '1 Probe awaiting pairing & calibration',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _onTabTapped(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimaryColor,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Garden Plants (4)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextPrimary),
              ),
              Text(
                'Tap probe to configure',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Plant Cards
          ..._gardenPlants.map((plant) {
            final isLinked = config.linkedPlantId == plant.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLinked ? kPrimaryColor.withValues(alpha: 0.4) : kBorderSubtle,
                  width: isLinked ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: kAccentMint.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_florist_rounded, color: kPrimaryColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              plant.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLinked ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isLinked ? Colors.green.shade300 : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLinked ? Icons.sensors : Icons.sensors_off_rounded,
                                    size: 11,
                                    color: isLinked ? Colors.green.shade800 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLinked ? 'PROBE LINKED' : 'NO PROBE',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isLinked ? Colors.green.shade800 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          plant.species,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 6),
                        if (isLinked) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.water_drop, size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  'Live Moisture: 28% • Profile: ${config.speciesProfile.speciesName}',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(
                            plant.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => _openPairingForPlant(plant),
                              icon: const Icon(Icons.add_link_rounded, size: 14),
                              label: const Text('Pair & Link IoT Probe', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: BOTANICAL STORE (Contextual App Integration)
  // ---------------------------------------------------------------------------
  Widget _buildShopTab() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('UrbanGreen Botanical Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: kSurfaceColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Recommended Hardware for your Garden', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildShopItem(
            name: 'SmartPlant Soil Probe (ESP32 BLE & Wi-Fi)',
            price: '\$29.99',
            description: 'Capacitive corrosion-resistant moisture telemetry probe with BLE & Wi-Fi mesh.',
            icon: Icons.sensors_rounded,
          ),
          _buildShopItem(
            name: 'Micro-Pump Irrigation Drip Kit',
            price: '\$19.50',
            description: '5V USB submersible water pump with silicon hose and anti-siphon valve.',
            icon: Icons.water_drop_rounded,
          ),
          _buildShopItem(
            name: 'Botanical Organic Plant Food (500ml)',
            price: '\$12.00',
            description: 'Liquid seaweed extract balanced for indoor tropicals and succulents.',
            icon: Icons.eco_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem({
    required String name,
    required String price,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: kAccentMint.withValues(alpha: 0.6),
            child: Icon(icon, color: kPrimaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2),
                const SizedBox(height: 4),
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: PROTOTYPE CONFIG & DIAGNOSTICS
  // ---------------------------------------------------------------------------
  Widget _buildProfileTab() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Prototype Diagnostics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: kSurfaceColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.perm_device_information_rounded, color: kPrimaryColor),
                    SizedBox(width: 8),
                    Text('Firmware & Hardware Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const Divider(height: 20),
                _buildInfoRow('Architecture', 'ESP32 Dual Core (Xtensa LX6)'),
                _buildInfoRow('GATT Service UUID', '0x0000FF01 (UrbanGreen SmartPlant)'),
                _buildInfoRow('Moisture Characteristic', '0x0000FF02 (Capacitance ADC)'),
                _buildInfoRow('Water Relay Characteristic', '0x0000FF03 (GPIO 23 Pulse)'),
                _buildInfoRow('Target Hardware IP', _service.targetDeviceIp),
                _buildInfoRow('Cloud Integration', 'Firebase Firestore Realtime Sync'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary)),
          ),
        ],
      ),
    );
  }
}
