import 'package:flutter/material.dart';
import '../../components/standard_app_bar.dart';
import '../../constants.dart';

class AutoWaterScheduleScreen extends StatefulWidget {
  final String? initialSchedule;

  const AutoWaterScheduleScreen({super.key, this.initialSchedule});

  @override
  State<AutoWaterScheduleScreen> createState() => _AutoWaterScheduleScreenState();
}

class _AutoWaterScheduleScreenState extends State<AutoWaterScheduleScreen> {
  String _selectedScheduleType = 'System Managed';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedFrequency = 'Daily';

  final List<String> _frequencies = [
    'Daily',
    'Every 2 days',
    'Every 3 days',
    'Weekly',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSchedule != null && widget.initialSchedule != 'System Managed') {
      _selectedScheduleType = 'Custom';
      for (final freq in _frequencies) {
        if (widget.initialSchedule!.contains(freq)) {
          _selectedFrequency = freq;
          break;
        }
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              onSurface: kTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveSchedule() {
    String schedule;
    if (_selectedScheduleType == 'System Managed') {
      schedule = 'System Managed (Smart Auto)';
    } else {
      schedule = 'Custom: $_selectedFrequency at ${_selectedTime.format(context)}';
    }
    Navigator.pop(context, schedule);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: const StandardAppBar(
        title: 'Hydration Schedule',
        subtitle: 'Automated valve & dispensing strategy',
        toolbarHeight: 68,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Watering Strategy',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how the smart valve determines when to dispense hydration.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Strategy Option 1: System Managed
          _buildOptionCard(
            type: 'System Managed',
            icon: Icons.auto_awesome_rounded,
            title: 'System Managed (Recommended)',
            subtitle: 'AI automatically monitors real-time soil moisture and weather conditions to water only when required.',
          ),
          const SizedBox(height: 12),

          // Strategy Option 2: Custom Schedule
          _buildOptionCard(
            type: 'Custom',
            icon: Icons.schedule_rounded,
            title: 'Custom Schedule',
            subtitle: 'Define explicit watering cadence and scheduled time-of-day execution.',
          ),

          if (_selectedScheduleType == 'Custom') ...[
            const SizedBox(height: 24),
            const Text(
              'Schedule Parameters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 14),

            // Time Picker Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.access_time_rounded, color: kPrimaryColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dispense Time', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 2),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () => _selectTime(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Change Time'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Frequency Chips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Interval Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _frequencies.map((freq) {
                      final isSelected = _selectedFrequency == freq;
                      return ChoiceChip(
                        label: Text(freq),
                        selected: isSelected,
                        selectedColor: kPrimaryColor,
                        backgroundColor: kBackgroundColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : kTextPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? kPrimaryColor : Colors.grey.shade300),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedFrequency = freq;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Save Button
          ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: const Text(
              'Save Watering Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedScheduleType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedScheduleType = type;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? kPrimaryColor : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kPrimaryColor : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kPrimaryColor,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
