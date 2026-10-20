import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import 'iot_details_screen.dart';
import 'iot_scanning_screen.dart';

class IotManagementScreen extends StatefulWidget {
  final String? plantId; // Optional plantId

  const IotManagementScreen({super.key, this.plantId});

  @override
  State<IotManagementScreen> createState() => _IotManagementScreenState();
}

class _IotManagementScreenState extends State<IotManagementScreen> {
  final List<IotDevice> _iotDevices = [
    IotDevice(
      id: 'd1',
      name: 'Living Room Sensor',
      supportsMoistureSensor: true,
      moistureLevel: 0.75,
    ),
    IotDevice(
      id: 'd2',
      name: 'Kitchen Waterer',
      supportsAutoWater: true,
      autoWaterEnabled: true,
      autoWaterSchedule: 'Every 2 days',
    ),
    IotDevice(
      id: 'd3',
      name: 'Balcony Combo',
      supportsMoistureSensor: true,
      supportsAutoWater: true,
      moistureLevel: 0.5,
      autoWaterEnabled: false,
    ),
  ];

  void _navigateAndAddDevice() async {
    final newDevice = await Navigator.push<IotDevice>(
      context,
      MaterialPageRoute(builder: (context) => const IotScanningScreen()),
    );

    if (newDevice != null) {
      setState(() {
        _iotDevices.add(newDevice);
      });
    }
  }

  void _deleteDevice(int index) {
    setState(() {
      _iotDevices.removeAt(index);
    });
  }

  void _attachDevice(IotDevice device) {
    // This is a placeholder for actual IoT attachment logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attached ${device.name} to Plant ${widget.plantId}!'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context); // Go back to PlantDetailScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: ListView.builder(
        itemCount: _iotDevices.length,
        itemBuilder: (context, index) {
          final device = _iotDevices[index];
          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: kDefaultPadding,
              vertical: kDefaultPadding / 2,
            ),
            child: ListTile(
              leading: Icon(Icons.developer_board,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(device.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.plantId !=
                      null) // Show attach button if plantId is provided
                    IconButton(
                      icon: const Icon(Icons.link),
                      onPressed: () => _attachDevice(device),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              IotDetailsScreen(device: device),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDevice(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "iot_management_fab",
        onPressed: _navigateAndAddDevice,
        child: const Icon(Icons.add),
      ),
    );
  }
}
