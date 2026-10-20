import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/camera/plant_diagnostic_screen.dart';
import 'package:urbangreen/screens/garden/add_plant_screen.dart';

class IdentifiedPlantScreen extends StatelessWidget {
  const IdentifiedPlantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/image_1.png', // Placeholder for identified plant
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(kDefaultPadding),
              child: Text(
                'Monstera Deliciosa',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: Text(
                'Commonly known as the Swiss cheese plant, is a species of flowering plant native to tropical forests of southern Mexico, south to Panama. It has been introduced to many tropical areas, and has become a mildly invasive species in Hawaii, Seychelles, Ascension Island and the Society Islands. ',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: kDefaultPadding),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plant Health',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: kDefaultPaddingSmall / 2),
                        Text(
                          'Your plant seems healthy.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PlantDiagnosticScreen(),
                        ),
                      );
                    },
                    child: const Text('See More'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kDefaultPadding),
            Padding(
              padding: const EdgeInsets.all(kDefaultPadding),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddPlantScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(double.infinity, kDefaultPadding * 2.5),
                ),
                child: Text(
                  'Add to My Garden',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
