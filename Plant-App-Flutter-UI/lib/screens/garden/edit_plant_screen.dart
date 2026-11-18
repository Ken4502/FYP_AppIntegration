import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/plant_species_profile_model.dart';

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
  late String _environment;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _speciesController = TextEditingController(text: widget.plant.species);
    _descriptionController = TextEditingController(text: widget.plant.description);
    _intervalController = TextEditingController(text: widget.plant.wateringIntervalDays.toString());
    _reminderTime = widget.plant.reminderTime;
    _reminderEnabled = widget.plant.reminderEnabled;
    _environment = widget.plant.environment;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  PlantSpeciesProfile get _currentProfile =>
      PlantSpeciesProfile.resolveForSpecies(_speciesController.text.trim());

  void _saveChanges() {
    final parsedInterval = int.tryParse(_intervalController.text.trim()) ?? widget.plant.wateringIntervalDays;
    final bool hasIot = widget.plant.hasIot;
    final updatedPlant = widget.plant.copyWith(
      name: _nameController.text.trim(),
      species: _speciesController.text.trim(),
      description: _descriptionController.text.trim(),
      environment: _environment,
      wateringIntervalDays: parsedInterval > 0 ? parsedInterval : widget.plant.wateringIntervalDays,
      reminderTime: _reminderTime,
      reminderEnabled: hasIot ? false : _reminderEnabled,
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

            // Environment & Rain Exposure Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _environment == 'outdoor' ? Icons.wb_sunny_rounded : Icons.home_rounded,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Environment & Microclimate',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Determines whether local precipitation & RainGuard affect watering recommendations.',
                      style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _environment = 'indoor'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _environment == 'indoor'
                                    ? kPrimaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
                                    : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _environment == 'indoor'
                                      ? kPrimaryColor
                                      : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                                  width: _environment == 'indoor' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.home_rounded,
                                    size: 26,
                                    color: _environment == 'indoor' ? kPrimaryColor : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Indoor',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _environment == 'indoor'
                                          ? kPrimaryColor
                                          : (isDark ? kDarkTextPrimary : kTextPrimary),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sheltered from rain',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _environment = 'outdoor'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _environment == 'outdoor'
                                    ? Colors.teal.withValues(alpha: isDark ? 0.25 : 0.12)
                                    : (isDark ? kDarkSurfaceColor : kBackgroundColor),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _environment == 'outdoor'
                                      ? Colors.teal
                                      : (isDark ? kDarkBorderSubtle : kBorderSubtle),
                                  width: _environment == 'outdoor' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.park_rounded,
                                    size: 26,
                                    color: _environment == 'outdoor' ? Colors.teal : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Outdoor',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _environment == 'outdoor'
                                          ? Colors.teal
                                          : (isDark ? kDarkTextPrimary : kTextPrimary),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Exposed to weather',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _environment == 'indoor' ? Icons.shield_outlined : Icons.cloud_sync_outlined,
                            size: 16,
                            color: _environment == 'indoor' ? kPrimaryColor : Colors.teal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _environment == 'indoor'
                                  ? '🏠 RainGuard is bypassed. Hydration decisions rely strictly on soil moisture, ignoring external rain forecasts.'
                                  : '🌧️ RainGuard active. If rain is forecast today, watering is postponed unless soil is critically parched.',
                              style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Calibrated Soil Moisture Spectrum Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Moisture Spectrum',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _currentProfile.category.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Species-calibrated 4-tier moisture spectrum and saturation limits.',
                      style: TextStyle(fontSize: 12, color: isDark ? kDarkTextSecondary : kTextSecondary),
                    ),
                    const SizedBox(height: 14),

                    // 4-Tier Range Visualizer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildSpectrumSegment(
                                label: 'Wilting',
                                range: '<${_currentProfile.criticalMinMoisture}%',
                                color: const Color(0xFFDC2626),
                                flex: 1,
                              ),
                              const SizedBox(width: 4),
                              _buildSpectrumSegment(
                                label: 'Thirsty',
                                range: '${_currentProfile.criticalMinMoisture}-${_currentProfile.optimalMinMoisture}%',
                                color: const Color(0xFFD97706),
                                flex: 2,
                              ),
                              const SizedBox(width: 4),
                              _buildSpectrumSegment(
                                label: 'Optimal',
                                range: '${_currentProfile.optimalMinMoisture}-${_currentProfile.optimalMaxMoisture}%',
                                color: const Color(0xFF16A34A),
                                flex: 3,
                              ),
                              const SizedBox(width: 4),
                              _buildSpectrumSegment(
                                label: 'Overwater',
                                range: '>${_currentProfile.overwaterMaxMoisture}%',
                                color: const Color(0xFFDC2626),
                                flex: 1,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Healthy: ${_currentProfile.optimalMinMoisture}% - ${_currentProfile.optimalMaxMoisture}%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                              ),
                              Text(
                                'Max Safe: ${_currentProfile.overwaterMaxMoisture}%',
                                style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '💡 ${_currentProfile.careSummary}',
                      style: TextStyle(fontSize: 11, color: isDark ? kDarkTextSecondary : kTextSecondary, fontStyle: FontStyle.italic),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.plant.hasIot ? Icons.sensors_rounded : Icons.alarm_rounded,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.plant.hasIot ? 'Hydration & Offline Watchdog' : 'Watering Reminder & Interval',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                            ),
                          ],
                        ),
                        if (widget.plant.hasIot)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'IOT MONITORED',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (widget.plant.hasIot) ...[
                      // IoT Telemetry Explanation Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Probe: ${widget.plant.iotDeviceId}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Soil moisture is measured continuously in real time. Dynamic hydration alerts fire automatically when moisture drops below ${_currentProfile.optimalMinMoisture}% (accounting for rain forecasts). Fixed daily calendar alarms are suppressed to avoid duplicate or conflicting alerts.',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Baseline Cadence / Offline Watchdog (Days)",
                          hintText: "e.g. 3, 5, 7",
                          helperText: "Safety fallback: Used if IoT probe loses battery or goes offline.",
                          helperMaxLines: 2,
                          prefixIcon: Icon(Icons.shield_outlined, size: 20),
                          suffixText: "days",
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Alerts Auto-Managed by IoT Telemetry',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF16A34A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
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

  Widget _buildSpectrumSegment({
    required String label,
    required String range,
    required Color color,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
