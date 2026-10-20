import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';

class WateringReportScreen extends StatelessWidget {
  const WateringReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watering Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Watering Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: kDefaultPadding),
            _buildMockChart(context),
            const SizedBox(height: kDefaultPadding * 2),
            Text(
              'Watering History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: kDefaultPadding),
            _buildWateringHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildMockChart(BuildContext context) {
    // Placeholder for a chart
    return Container(
      height: 200,
      padding: const EdgeInsets.all(kDefaultPadding),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      child: Center(
        child: Text(
          'Mock Chart Placeholder',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildWateringHistory() {
    final wateringEvents = [
      {'plant': 'Monstera', 'date': '2026-08-19', 'amount': '200ml'},
      {'plant': 'Fiddle Leaf Fig', 'date': '2026-08-18', 'amount': '300ml'},
      {'plant': 'Snake Plant', 'date': '2026-08-17', 'amount': '100ml'},
      {'plant': 'Monstera', 'date': '2026-08-12', 'amount': '200ml'},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: wateringEvents.length,
      itemBuilder: (context, index) {
        final event = wateringEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: const Icon(Icons.water_drop),
            title: Text('${event['plant']}'),
            subtitle: Text('Date: ${event['date']}'),
            trailing: Text('${event['amount']}'),
          ),
        );
      },
    );
  }
}
