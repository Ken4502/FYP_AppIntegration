import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/reports/plant_health_report_screen.dart';
import 'package:urbangreen/screens/reports/watering_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          children: [
            _buildReportOption(
              context,
              icon: Icons.water_drop_outlined,
              text: "Watering Report",
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WateringReportScreen()));
              },
            ),
            _buildReportOption(
              context,
              icon: Icons.health_and_safety_outlined,
              text: "Plant Health Report",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PlantHealthReportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(BuildContext context,
      {required IconData icon, required String text, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
