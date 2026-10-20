import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_model.dart';

class EditPlantScreen extends StatefulWidget {
  final Plant plant;

  const EditPlantScreen({super.key, required this.plant});

  @override
  EditPlantScreenState createState() => EditPlantScreenState();
}

class EditPlantScreenState extends State<EditPlantScreen> {
  late TextEditingController _nameController;
  late TextEditingController _speciesController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _speciesController = TextEditingController(text: widget.plant.species);
    _descriptionController =
        TextEditingController(text: widget.plant.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final updatedPlant = widget.plant.copyWith(
      name: _nameController.text,
      species: _speciesController.text,
      description: _descriptionController.text,
    );
    Navigator.pop(context, updatedPlant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Plant"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Name",
              ),
            ),
            const SizedBox(height: kDefaultPadding),
            TextFormField(
              controller: _speciesController,
              decoration: const InputDecoration(
                labelText: "Species",
              ),
            ),
            const SizedBox(height: kDefaultPadding),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
