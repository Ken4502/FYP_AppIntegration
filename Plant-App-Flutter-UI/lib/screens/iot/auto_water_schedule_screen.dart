import 'package:flutter/material.dart';

class AutoWaterScheduleScreen extends StatefulWidget {
  final String? initialSchedule;

  const AutoWaterScheduleScreen({super.key, this.initialSchedule});

  @override
  State<AutoWaterScheduleScreen> createState() =>
      _AutoWaterScheduleScreenState();
}

class _AutoWaterScheduleScreenState extends State<AutoWaterScheduleScreen> {
  String _selectedScheduleType = 'System Managed';
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedFrequency = 'Daily';

  @override
  void initState() {
    super.initState();
    if (widget.initialSchedule != null &&
        widget.initialSchedule != 'System Managed') {
      _selectedScheduleType = 'Custom';
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Watering Schedule"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              String schedule;
              if (_selectedScheduleType == 'System Managed') {
                schedule = 'System Managed';
              } else {
                schedule =
                    'Custom: $_selectedFrequency at ${_selectedTime.format(context)}';
              }
              Navigator.pop(context, schedule);
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _ScheduleTypeRadioGroup(
            initialValue: _selectedScheduleType,
            onChanged: (value) {
              setState(() {
                _selectedScheduleType = value;
              });
            },
          ),
          if (_selectedScheduleType == 'Custom') ...[
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectTime(context),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text('Frequency'),
              trailing: DropdownButton<String>(
                value: _selectedFrequency,
                items: <String>['Daily', 'Every 2 days', 'Weekly']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFrequency = newValue!;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTypeRadioGroup extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _ScheduleTypeRadioGroup({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_ScheduleTypeRadioGroup> createState() =>
      _ScheduleTypeRadioGroupState();
}

class _ScheduleTypeRadioGroupState extends State<_ScheduleTypeRadioGroup> {
  late String _currentSelectedValue;

  @override
  void initState() {
    super.initState();
    _currentSelectedValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _ScheduleTypeRadioGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _currentSelectedValue = widget.initialValue;
    }
  }

  void _handleChanged(String? value) {
    if (value != null) {
      setState(() {
        _currentSelectedValue = value;
      });
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('System Managed'),
          subtitle: const Text(
              'Automatically waters based on weather and soil moisture.'),
          value: 'System Managed',
          // ignore: deprecated_member_use
          groupValue: _currentSelectedValue,
          // ignore: deprecated_member_use
          onChanged: _handleChanged,
        ),
        RadioListTile<String>(
          title: const Text('Custom Schedule'),
          subtitle: const Text('Set your own time and frequency.'),
          value: 'Custom',
          // ignore: deprecated_member_use
          groupValue: _currentSelectedValue,
          // ignore: deprecated_member_use
          onChanged: _handleChanged,
        ),
      ],
    );
  }
}
