import 'package:flutter/material.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/garden/add_plant_screen.dart';
import 'package:urbangreen/screens/garden/plant_detail_screen.dart';

class PlantListScreen extends StatefulWidget {
  const PlantListScreen({super.key});

  @override
  State<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  // Mock data for plants
  final List<Plant> _myPlants = [
    Plant(
        id: "1",
        name: "Samantha",
        species: "Monstera",
        imageUrl: "assets/images/image_1.png",
        description: "Loves indirect sunlight."),
    Plant(
        id: "2",
        name: "Angelica",
        species: "Fiddle Leaf",
        imageUrl: "assets/images/image_2.png",
        description: "Water only when soil is dry."),
    Plant(
        id: "3",
        name: "Bob",
        species: "Snake Plant",
        imageUrl: "assets/images/image_3.png",
        description: "Very resilient."),
  ];

  void _addPlant(Plant plant) {
    setState(() {
      _myPlants.add(plant);
    });
  }

  void _updatePlant(Plant plant) {
    setState(() {
      final index = _myPlants.indexWhere((p) => p.id == plant.id);
      if (index != -1) {
        _myPlants[index] = plant;
      }
    });
  }

  void _deletePlant(Plant plant) {
    setState(() {
      _myPlants.remove(plant);
    });
  }

  void _navigateAndAddPlant(BuildContext context) async {
    final newPlant = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPlantScreen(),
      ),
    );

    if (newPlant != null) {
      _addPlant(newPlant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _myPlants.length,
        itemBuilder: (context, index) {
          final plant = _myPlants[index];
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
              onTap: () async {
                final updatedPlant = await Navigator.push<Plant>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlantDetailScreen(
                      plant: plant,
                      onDelete: _deletePlant,
                      onUpdate: _updatePlant,
                    ),
                  ),
                );
                if (updatedPlant != null) {
                  _updatePlant(updatedPlant);
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "plant_list_fab",
        onPressed: () => _navigateAndAddPlant(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
