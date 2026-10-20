import 'package:flutter/material.dart';
import 'package:urbangreen/models/plant_model.dart';

class PlantLibraryScreen extends StatelessWidget {
  PlantLibraryScreen({super.key});

  // Mock data for plant library
  final List<Plant> _plantLibrary = [
    Plant(
        id: "4",
        name: "Lily",
        species: "Peace Lily",
        imageUrl: "assets/images/image_1.png",
        description: "It is a very popular indoor houseplant."),
    Plant(
        id: "5",
        name: "Rose",
        species: "Rosa",
        imageUrl: "assets/images/image_2.png",
        description: "A woody perennial flowering plant."),
    Plant(
        id: "6",
        name: "Orchid",
        species: "Orchidaceae",
        imageUrl: "assets/images/image_3.png",
        description: "A diverse and widespread family of flowering plants."),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plant Library"),
      ),
      body: ListView.builder(
        itemCount: _plantLibrary.length,
        itemBuilder: (context, index) {
          final plant = _plantLibrary[index];
          return Card(
            margin: const EdgeInsets.all(10.0),
            child: ListTile(
              leading: Image.asset(
                plant.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
              title: Text(plant.name),
              subtitle: Text(plant.species),
              onTap: () {
                // Return the selected plant to the previous screen
                Navigator.pop(context, plant);
              },
            ),
          );
        },
      ),
    );
  }
}
