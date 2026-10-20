import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';

class PlantHealthReportScreen extends StatelessWidget {
  const PlantHealthReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Health Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Garden Health',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: kDefaultPadding),
            _buildPlantHealthCard(
              context,
              plantName: 'Monstera',
              healthStatus: 'Good',
              healthColor: Colors.green,
              details: {
                'Sunlight': '80%',
                'Soil Moisture': '60%',
                'Temperature': '24°C',
              },
            ),
            _buildPlantHealthCard(
              context,
              plantName: 'Fiddle Leaf Fig',
              healthStatus: 'Needs Attention',
              healthColor: Colors.orange,
              details: {
                'Sunlight': '50%',
                'Soil Moisture': '30%',
                'Temperature': '22°C',
              },
            ),
            _buildPlantHealthCard(
              context,
              plantName: 'Snake Plant',
              healthStatus: 'Excellent',
              healthColor: Colors.blue,
              details: {
                'Sunlight': '70%',
                'Soil Moisture': '50%',
                'Temperature': '25°C',
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantHealthCard(
    BuildContext context, {
    required String plantName,
    required String healthStatus,
    required Color healthColor,
    required Map<String, String> details,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plantName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: healthColor,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    healthStatus,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kDefaultPadding),
            ...details.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(entry.value),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
