import 'package:flutter/material.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/garden/edit_plant_screen.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;
  final Function(Plant) onDelete;
  final Function(Plant) onUpdate;

  const PlantDetailScreen(
      {super.key,
      required this.plant,
      required this.onDelete,
      required this.onUpdate});

  @override
  PlantDetailScreenState createState() => PlantDetailScreenState();
}

class PlantDetailScreenState extends State<PlantDetailScreen> {
  late Plant _plant;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _descriptionController = TextEditingController(text: _plant.description);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _navigateAndEditPlant(BuildContext context) async {
    final updatedPlant = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlantScreen(plant: _plant),
      ),
    );

    if (updatedPlant != null) {
      setState(() {
        _plant = updatedPlant;
        _descriptionController.text = _plant.description;
      });
      widget.onUpdate(updatedPlant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_plant.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateAndEditPlant(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              widget.onDelete(_plant);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Image.asset(
                      _plant.imageUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _plant.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  _plant.species,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Notes",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  readOnly: true,
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  "IoT Data",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 15),
                const Row(
                  children: [
                    Icon(Icons.water_drop, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Moisture Level: 65%",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.wb_sunny, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Light Intensity: 80%",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.thermostat, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Temperature: 25°C",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text("Attach IoT"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IotManagementScreen(
                            plantId: _plant.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
