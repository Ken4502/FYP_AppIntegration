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
  late TextEditingController _intervalController;
  late String _reminderTime;
  late bool _reminderEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _speciesController = TextEditingController(text: widget.plant.species);
    _descriptionController = TextEditingController(text: widget.plant.description);
    _intervalController = TextEditingController(text: widget.plant.wateringIntervalDays.toString());
    _reminderTime = widget.plant.reminderTime;
    _reminderEnabled = widget.plant.reminderEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final parsedInterval = int.tryParse(_intervalController.text.trim()) ?? widget.plant.wateringIntervalDays;
    final updatedPlant = widget.plant.copyWith(
      name: _nameController.text.trim(),
      species: _speciesController.text.trim(),
      description: _descriptionController.text.trim(),
      wateringIntervalDays: parsedInterval > 0 ? parsedInterval : widget.plant.wateringIntervalDays,
      reminderTime: _reminderTime,
      reminderEnabled: _reminderEnabled,
    );
    Navigator.pop(context, updatedPlant);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: AppBar(
        title: const Text("Edit Plant Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plant Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Plant Nickname",
                        prefixIcon: Icon(Icons.drive_file_rename_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _speciesController,
                      decoration: const InputDecoration(
                        labelText: "Botanical Species",
                        prefixIcon: Icon(Icons.local_florist_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Care Notes & Placement",
                        prefixIcon: Icon(Icons.notes, size: 20),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Watering Schedule & Reminder Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.alarm_rounded, color: kPrimaryColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Watering Reminder & Interval',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Watering Frequency (in days)",
                        hintText: "e.g. 3, 5, 7, 14",
                        prefixIcon: Icon(Icons.water_drop_outlined, size: 20),
                        suffixText: "days",
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) {
                          final hr = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
                          final min = time.minute.toString().padLeft(2, '0');
                          final period = time.period == DayPeriod.am ? 'AM' : 'PM';
                          setState(() {
                            _reminderTime = '${hr.toString().padLeft(2, '0')}:$min $period';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 20, color: kPrimaryColor),
                                  const SizedBox(width: 10),
                                  Text(
                                    _reminderTime,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? kDarkTextPrimary : kTextPrimary),
                                  ),
                                ],
                              ),
                            ),
                            const Text('Change Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Daily Reminder Alert', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextPrimary)),
                      subtitle: const Text('Notify when plant is due for hydration', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                      value: _reminderEnabled,
                      activeTrackColor: kPrimaryColor,
                      onChanged: (val) => setState(() => _reminderEnabled = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Botanical Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
