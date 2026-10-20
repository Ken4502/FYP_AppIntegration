import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/camera/camera_screen.dart';
import 'package:urbangreen/screens/garden/plant_library_screen.dart';

class AddPlantScreen extends StatelessWidget {
  const AddPlantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add a New Plant"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text("Choose from Library"),
              onPressed: () async {
                final newPlant = await Navigator.push<Plant>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlantLibraryScreen(),
                  ),
                );
                if (newPlant != null && context.mounted) {
                  Navigator.pop(context, newPlant);
                }
              },
            ),
            const SizedBox(height: kDefaultPadding),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Identify with Camera"),
              onPressed: () async {
                final image =
                    await ImagePicker().pickImage(source: ImageSource.camera);
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
    );
  }
}
