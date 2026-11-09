import 'package:flutter/material.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/services/plant_service.dart';
import '../../constants.dart';
import '../camera/plant_diagnostic_screen.dart';

class IdentifiedPlantScreen extends StatelessWidget {
  final String? plantName;
  final String? plantDescription;
  final String? plantImage;

  const IdentifiedPlantScreen({
    super.key,
    this.plantName,
    this.plantDescription,
    this.plantImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = plantName ?? 'Monstera Deliciosa';
    final desc = plantDescription ??
        'Commonly known as the Swiss Cheese Plant, Monstera Deliciosa is a tropical evergreen vine celebrated for its dramatic perforated foliage. Native to the lush tropical rainforests of southern Mexico to Central America, it thrives in warm, humid indoor spaces with indirect bright daylight.';

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Parallax Hero App Bar
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: kPrimaryDark,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    plantImage ?? 'assets/images/image_1.png',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('IDENTIFIED • 98.4% MATCH', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Dossier
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health Overview Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCardColor : kSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? kDarkSurfaceColor : Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.favorite_rounded, color: Colors.green.shade700, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pathological Status', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              const Text('Vibrant & Vigorous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text('No signs of chlorosis, necrosis, or pest infestation.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlantDiagnosticScreen(),
                              ),
                            );
                          },
                          child: const Text('Full Audit'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botanical Requirements Strip
                  Text('Care Environment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildEnvCard(context, Icons.wb_sunny_rounded, 'Indirect Bright', 'Sunlight', Colors.amber),
                      const SizedBox(width: 10),
                      _buildEnvCard(context, Icons.water_drop_rounded, 'Weekly Top Soil', 'Moisture', Colors.blue),
                      const SizedBox(width: 10),
                      _buildEnvCard(context, Icons.thermostat_rounded, '18° - 27°C', 'Temperature', Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botanical Profile & Description
                  Text('Botanical Profile', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const Text('Diagnostics'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: const BorderSide(color: kPrimaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlantDiagnosticScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add to My Garden'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            final newPlant = Plant(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: name,
                              species: name,
                              imageUrl: plantImage ?? 'assets/images/image_1.png',
                              description: desc,
                            );
                            PlantService().addPlant(newPlant);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🌿 Added "$name" to your Garden!'),
                                backgroundColor: kPrimaryColor,
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'View Garden',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    Navigator.popUntil(context, (route) => route.isFirst);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvCard(BuildContext context, IconData icon, String title, String subtitle, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? kDarkCardColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? kDarkBorderSubtle : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color.shade600, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
