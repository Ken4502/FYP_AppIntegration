class IotDevice {
  final String id;
  String name;
  final bool supportsMoistureSensor;
  final bool supportsAutoWater;
  double? moistureLevel;
  bool autoWaterEnabled;
  String? autoWaterSchedule;

  IotDevice({
    required this.id,
    required this.name,
    this.supportsMoistureSensor = false,
    this.supportsAutoWater = false,
    this.moistureLevel,
    this.autoWaterEnabled = false,
    this.autoWaterSchedule,
  });
}
