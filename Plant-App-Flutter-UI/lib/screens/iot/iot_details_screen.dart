import 'package:flutter/material.dart';
import '../../models/iot_device_model.dart';
import 'auto_water_schedule_screen.dart';

class IotDetailsScreen extends StatefulWidget {
  final IotDevice device;

  const IotDetailsScreen({super.key, required this.device});

  @override
  State<IotDetailsScreen> createState() => _IotDetailsScreenState();
}

class _IotDetailsScreenState extends State<IotDetailsScreen> {
  late bool _autoWaterEnabled;

  @override
  void initState() {
    super.initState();
    _autoWaterEnabled = widget.device.autoWaterEnabled;
    // Simulate initial moisture level
    if (widget.device.supportsMoistureSensor) {
      widget.device.moistureLevel = 0.65; // 65%
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.device.supportsMoistureSensor &&
                widget.device.moistureLevel != null)
              _buildMoistureInfo(),
            const SizedBox(height: 24),
            if (widget.device.supportsAutoWater) _buildAutoWaterControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoistureInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Soil Moisture",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: widget.device.moistureLevel!,
          minHeight: 10,
        ),
        const SizedBox(height: 8),
        Text(
          "${(widget.device.moistureLevel! * 100).toStringAsFixed(0)}%",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAutoWaterControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Auto Watering",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text("Enable Automatic Watering"),
          value: _autoWaterEnabled,
          onChanged: (bool value) {
            setState(() {
              _autoWaterEnabled = value;
              widget.device.autoWaterEnabled = value;
            });
          },
        ),
        const SizedBox(height: 8),
        if (_autoWaterEnabled)
          ListTile(
            title: const Text("Watering Schedule"),
            subtitle: Text(widget.device.autoWaterSchedule ?? "Not set"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final newSchedule = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => AutoWaterScheduleScreen(
                    initialSchedule: widget.device.autoWaterSchedule,
                  ),
                ),
              );
              if (newSchedule != null) {
                setState(() {
                  widget.device.autoWaterSchedule = newSchedule;
                });
              }
            },
          ),
      ],
    );
  }
}
