import 'package:flutter/material.dart';
import '../../models/iot_device_model.dart';

class IotScanningScreen extends StatefulWidget {
  const IotScanningScreen({super.key});

  @override
  State<IotScanningScreen> createState() => _IotScanningScreenState();
}

class _IotScanningScreenState extends State<IotScanningScreen> {
  final List<IotDevice> _discoveredDevices = [
    IotDevice(
        id: '1',
        name: 'Living Room Sensor',
        supportsMoistureSensor: true,
        supportsAutoWater: true),
    IotDevice(id: '2', name: 'Kitchen Sensor', supportsMoistureSensor: true),
    IotDevice(id: '3', name: 'Balcony Waterer', supportsAutoWater: true),
  ];
  bool _isScanning = false;

  void _scanForDevices() {
    setState(() {
      _isScanning = true;
    });
    // Simulate network scan
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isScanning = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _scanForDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan for IoT Devices"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanForDevices,
          ),
        ],
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Scanning for devices..."),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                return ListTile(
                  leading: const Icon(Icons.developer_board_outlined),
                  title: Text(device.name),
                  subtitle: Text(
                      "Supports: ${device.supportsMoistureSensor ? 'Moisture' : ''}${device.supportsAutoWater ? ', Auto-Water' : ''}"),
                  onTap: () {
                    Navigator.pop(context, device);
                  },
                );
              },
            ),
    );
  }
}
