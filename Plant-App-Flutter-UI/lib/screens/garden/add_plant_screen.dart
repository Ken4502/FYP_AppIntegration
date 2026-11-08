import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/camera/camera_screen.dart';
import 'package:urbangreen/screens/garden/plant_library_screen.dart';

class AddPlantScreen extends StatelessWidget {
  const AddPlantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: const StandardAppBar(
        title: 'Add New Specimen',
        subtitle: 'Identify, pick from library, or create manual entry',
        toolbarHeight: 68,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to Your Garden',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you would like to catalog your new botanical companion.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 28),

              // Option 1: AI Camera
              _buildChoiceCard(
                context,
                icon: Icons.camera_alt_outlined,
                iconColor: kPrimaryColor,
                title: 'Snap Leaf with AI Scanner',
                subtitle: 'Automatically identifies the exact plant species and evaluates foliar health',
                badgeText: 'RECOMMENDED',
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 92,
                  );
                  if (image != null && context.mounted) {
                    final newPlant = await Navigator.push<Plant>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraScreen(image: image),
                      ),
                    );
                    if (newPlant != null && context.mounted) {
                      Navigator.pop(context, newPlant);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              // Option 2: Botanical Library
              _buildChoiceCard(
                context,
                icon: Icons.local_florist_outlined,
                iconColor: Colors.teal.shade700,
                title: 'Browse Botanical Library',
                subtitle: 'Search popular houseplants with pre-configured watering and sunlight care profiles',
                onTap: () async {
                  final newPlant = await Navigator.push<Plant>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlantLibraryScreen(),
                    ),
                  );
                  if (newPlant != null && context.mounted) {
                    Navigator.pop(context, newPlant);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Option 3: Photo Gallery
              _buildChoiceCard(
                context,
                icon: Icons.photo_library_outlined,
                iconColor: Colors.indigo.shade700,
                title: 'Upload from Photo Album',
                subtitle: 'Select an existing foliage photo from your device gallery for AI analysis',
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 92,
                  );
                  if (image != null && context.mounted) {
                    final newPlant = await Navigator.push<Plant>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraScreen(image: image),
                      ),
                    );
                    if (newPlant != null && context.mounted) {
                      Navigator.pop(context, newPlant);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badgeText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccentMint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
