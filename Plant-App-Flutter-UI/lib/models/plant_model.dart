import 'package:flutter/material.dart';
import 'package:urbangreen/models/plant_species_profile_model.dart';

class Plant {
  final String id;
  final String name;
  final String species;
  final String imageUrl;
  final String description;
  String? iotDeviceId; // Make iotDeviceId optional and mutable

  // Botanical & Care Reminder Attributes (Shared by both IoT & non-IoT plants)
  final int wateringIntervalDays;
  final DateTime? lastWatered;
  final String reminderTime;
  final bool reminderEnabled;
  final String sunlight;
  final String wateringRecommendation;
  final String idealTemperature;
  final String petToxicity;
  final String soilType;
  final String? careNotes;

  Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.imageUrl,
    this.description = "",
    this.iotDeviceId,
    int? wateringIntervalDays,
    this.lastWatered,
    this.reminderTime = "09:00 AM",
    this.reminderEnabled = false, // DO NOT automatically set a reminder
    String? sunlight,
    String? wateringRecommendation,
    String? idealTemperature,
    String? petToxicity,
    String? soilType,
    this.careNotes,
  })  : wateringIntervalDays = wateringIntervalDays ?? _defaultIntervalForSpecies(species),
        sunlight = sunlight ?? _defaultSunlightForSpecies(species),
        wateringRecommendation = wateringRecommendation ?? _defaultWateringRecommendationForSpecies(species),
        idealTemperature = idealTemperature ?? _defaultTemperatureForSpecies(species),
        petToxicity = petToxicity ?? _defaultToxicityForSpecies(species),
        soilType = soilType ?? _defaultSoilForSpecies(species);

  /// Whether this plant is actively connected to an IoT telemetry probe
  bool get hasIot => iotDeviceId != null && iotDeviceId!.trim().isNotEmpty;

  /// Next planned watering timestamp based on lastWatered and interval.
  /// Strictly null if the user has not configured / enabled a watering reminder.
  DateTime? get nextWateringDate {
    if (!reminderEnabled) return null;
    final base = lastWatered ?? DateTime.now();
    return base.add(Duration(days: wateringIntervalDays));
  }

  /// Number of days until next watering (null if no reminder setup)
  int? get daysUntilNextWatering {
    final next = nextWateringDate;
    if (next == null) return null;
    final now = DateTime.now();
    return next.difference(now).inDays;
  }

  /// Whether the plant is due for hydration.
  /// Always false if reminders are not setup.
  bool get isWateringDue {
    if (!reminderEnabled) return false;
    final next = nextWateringDate;
    if (next == null) return false;
    final now = DateTime.now();
    return now.isAfter(next) || (daysUntilNextWatering != null && daysUntilNextWatering! <= 0);
  }

  /// Human-readable schedule summary (e.g. "Due today", "Due in 3 days", "No reminder set")
  String get wateringScheduleSummary {
    if (!reminderEnabled) {
      return 'No reminder set';
    }
    final next = nextWateringDate;
    if (next == null) {
      return 'Reminder active';
    }
    if (isWateringDue) {
      final daysOverdue = DateTime.now().difference(next).inDays;
      if (daysOverdue > 0) {
        return 'Overdue by $daysOverdue d';
      }
      return 'Watering due today';
    } else {
      final days = daysUntilNextWatering ?? wateringIntervalDays;
      if (days <= 1) return 'Due tomorrow';
      return 'Due in $days days';
    }
  }

  /// Human-readable reminder notification status
  String get reminderStatusText {
    if (reminderEnabled) {
      return 'Daily at $reminderTime';
    }
    return 'No notification setup';
  }

  /// Status badge color based on watering compliance
  Color get wateringStatusColor {
    if (!reminderEnabled) {
      return Colors.blueGrey;
    }
    if (isWateringDue) {
      final next = nextWateringDate;
      if (next != null) {
        final daysOverdue = DateTime.now().difference(next).inDays;
        if (daysOverdue > 1) return Colors.red.shade700;
      }
      return Colors.orange.shade800;
    }
    return const Color(0xFF2E7D32);
  }

  Plant copyWith({
    String? id,
    String? name,
    String? species,
    String? imageUrl,
    String? description,
    String? iotDeviceId,
    bool clearIotDevice = false,
    int? wateringIntervalDays,
    DateTime? lastWatered,
    String? reminderTime,
    bool? reminderEnabled,
    String? sunlight,
    String? wateringRecommendation,
    String? idealTemperature,
    String? petToxicity,
    String? soilType,
    String? careNotes,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      iotDeviceId: clearIotDevice ? null : (iotDeviceId ?? this.iotDeviceId),
      wateringIntervalDays: wateringIntervalDays ?? this.wateringIntervalDays,
      lastWatered: lastWatered ?? this.lastWatered,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      sunlight: sunlight ?? this.sunlight,
      wateringRecommendation: wateringRecommendation ?? this.wateringRecommendation,
      idealTemperature: idealTemperature ?? this.idealTemperature,
      petToxicity: petToxicity ?? this.petToxicity,
      soilType: soilType ?? this.soilType,
      careNotes: careNotes ?? this.careNotes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    'imageUrl': imageUrl,
    'description': description,
    'iotDeviceId': iotDeviceId,
    'wateringIntervalDays': wateringIntervalDays,
    'lastWatered': lastWatered?.toIso8601String(),
    'reminderTime': reminderTime,
    'reminderEnabled': reminderEnabled,
    'sunlight': sunlight,
    'wateringRecommendation': wateringRecommendation,
    'idealTemperature': idealTemperature,
    'petToxicity': petToxicity,
    'soilType': soilType,
    'careNotes': careNotes,
  };

  factory Plant.fromJson(Map<String, dynamic> json) {
    final species = json['species']?.toString() ?? '';
    return Plant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      species: species,
      imageUrl: json['imageUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iotDeviceId: json['iotDeviceId']?.toString(),
      wateringIntervalDays: json['wateringIntervalDays'] is int
          ? json['wateringIntervalDays'] as int
          : (int.tryParse(json['wateringIntervalDays']?.toString() ?? '') ?? _defaultIntervalForSpecies(species)),
      lastWatered: json['lastWatered'] != null
          ? DateTime.tryParse(json['lastWatered'].toString())
          : null,
      reminderTime: json['reminderTime']?.toString() ?? '09:00 AM',
      reminderEnabled: json['reminderEnabled'] is bool
          ? json['reminderEnabled'] as bool
          : (json['reminderEnabled']?.toString().toLowerCase() == 'true'),
      sunlight: json['sunlight']?.toString(),
      wateringRecommendation: json['wateringRecommendation']?.toString(),
      idealTemperature: json['idealTemperature']?.toString(),
      petToxicity: json['petToxicity']?.toString(),
      soilType: json['soilType']?.toString(),
      careNotes: json['careNotes']?.toString(),
    );
  }

  // --- Species defaults helpers ---
  static int _defaultIntervalForSpecies(String species) {
    final s = species.toLowerCase();
    if (s.contains('cactus') || s.contains('succulent') || s.contains('sansevieria') || s.contains('snake')) {
      return 14;
    }
    if (s.contains('fern') || s.contains('peace lily') || s.contains('spathiphyllum') || s.contains('calathea')) {
      return 4;
    }
    if (s.contains('basil') || s.contains('herb') || s.contains('mint') || s.contains('tomato')) {
      return 3;
    }
    if (s.contains('monstera') || s.contains('ficus') || s.contains('pothos')) {
      return 7;
    }
    return 5;
  }

  static String _defaultSunlightForSpecies(String species) {
    final profile = PlantSpeciesProfile.resolveForSpecies(species);
    return profile.sunlight;
  }

  static String _defaultWateringRecommendationForSpecies(String species) {
    final profile = PlantSpeciesProfile.resolveForSpecies(species);
    return profile.recommendedCycle;
  }

  static String _defaultTemperatureForSpecies(String species) {
    final s = species.toLowerCase();
    if (s.contains('cactus') || s.contains('succulent')) {
      return '18°C - 32°C (Warm & Dry)';
    }
    if (s.contains('fern') || s.contains('tropical') || s.contains('monstera')) {
      return '20°C - 28°C (Humid Warmth)';
    }
    return '18°C - 26°C (Room Ambient)';
  }

  static String _defaultToxicityForSpecies(String species) {
    final s = species.toLowerCase();
    if (s.contains('fern') || s.contains('spider') || s.contains('basil') || s.contains('calathea')) {
      return 'Non-toxic & Pet Safe 🐾';
    }
    if (s.contains('monstera') || s.contains('ficus') || s.contains('sansevieria') || s.contains('snake') || s.contains('pothos') || s.contains('peace lily')) {
      return 'Toxic to cats & dogs ⚠️';
    }
    return 'Keep away from pets';
  }

  static String _defaultSoilForSpecies(String species) {
    final s = species.toLowerCase();
    if (s.contains('cactus') || s.contains('succulent')) {
      return 'Porous, gritty cactus & succulent substrate';
    }
    if (s.contains('fern') || s.contains('lily')) {
      return 'Moisture-retentive rich peat loam';
    }
    return 'Aerated, well-draining indoor potting mix';
  }
}
