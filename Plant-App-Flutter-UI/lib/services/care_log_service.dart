import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'platform/web_hardware_bridge.dart';

class WateringLog {
  final String id;
  final String plantId;
  final String plantName;
  final String species;
  final String? imageUrl;
  final DateTime timestamp;
  final int amountMl;
  final String mode; // 'Manual Care', 'Hardware Pump', 'Auto-Schedule'
  final int? moistureBefore;
  final int? moistureAfter;
  final String? notes;

  WateringLog({
    required this.id,
    required this.plantId,
    required this.plantName,
    required this.species,
    this.imageUrl,
    required this.timestamp,
    required this.amountMl,
    required this.mode,
    this.moistureBefore,
    this.moistureAfter,
    this.notes,
  });

  int get volumeMl => amountMl;
  String get careMode => mode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'plantId': plantId,
    'plantName': plantName,
    'species': species,
    'imageUrl': imageUrl,
    'timestamp': timestamp.toIso8601String(),
    'amountMl': amountMl,
    'mode': mode,
    'moistureBefore': moistureBefore,
    'moistureAfter': moistureAfter,
    'notes': notes,
  };

  factory WateringLog.fromJson(Map<String, dynamic> json) => WateringLog(
    id: json['id']?.toString() ?? '',
    plantId: json['plantId']?.toString() ?? '',
    plantName: json['plantName']?.toString() ?? '',
    species: json['species']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString(),
    timestamp: json['timestamp'] != null
        ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
        : DateTime.now(),
    amountMl: int.tryParse(json['amountMl']?.toString() ?? '150') ?? 150,
    mode: json['mode']?.toString() ?? 'Manual Care',
    moistureBefore: json['moistureBefore'] != null ? int.tryParse(json['moistureBefore'].toString()) : null,
    moistureAfter: json['moistureAfter'] != null ? int.tryParse(json['moistureAfter'].toString()) : null,
    notes: json['notes']?.toString(),
  );
}

class CareLogService extends ChangeNotifier {
  static final CareLogService _instance = CareLogService._internal();
  factory CareLogService() => _instance;

  static const String _storageKey = 'garden_watering_logs_json';
  final List<WateringLog> _wateringLogs = [];
  bool _isLoaded = false;

  CareLogService._internal() {
    _loadFromStorage();
  }

  Future<void> init() async {
    _loadFromStorage();
  }

  List<WateringLog> get wateringLogs {
    if (!_isLoaded) _loadFromStorage();
    return List.unmodifiable(_wateringLogs);
  }

  void _loadFromStorage() {
    _isLoaded = true;
    final savedJson = WebHardwareBridge.loadStorage(_storageKey);
    if (savedJson != null && savedJson.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        _wateringLogs.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _wateringLogs.add(WateringLog.fromJson(item));
          }
        }
        if (_wateringLogs.isNotEmpty) return;
      } catch (e) {
        debugPrint('CareLogService load error: $e');
      }
    }

    // Seed realistic starter logs matching existing starter plants
    _seedInitialLogs();
  }

  void _seedInitialLogs() {
    final now = DateTime.now();
    _wateringLogs.clear();
    _wateringLogs.addAll([
      WateringLog(
        id: 'seed_01',
        plantId: '1',
        plantName: 'Samantha',
        species: 'Monstera Deliciosa',
        imageUrl: 'assets/images/image_1.png',
        timestamp: now.subtract(const Duration(hours: 3)),
        amountMl: 250,
        mode: 'Hardware Pump Pulse',
        moistureBefore: 30,
        moistureAfter: 65,
        notes: 'IoT automatic hydration routine',
      ),
      WateringLog(
        id: 'seed_02',
        plantId: '2',
        plantName: 'Angelica',
        species: 'Ficus Lyrata (Fiddle Leaf)',
        imageUrl: 'assets/images/image_2.png',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        amountMl: 350,
        mode: 'Manual Hydration',
        moistureBefore: 22,
        moistureAfter: 55,
        notes: 'Deep pot soaking',
      ),
      WateringLog(
        id: 'seed_03',
        plantId: '3',
        plantName: 'Bob',
        species: 'Sansevieria Trifasciata',
        imageUrl: 'assets/images/image_3.png',
        timestamp: now.subtract(const Duration(days: 3, hours: 5)),
        amountMl: 150,
        mode: 'Manual Hydration',
        moistureBefore: 18,
        moistureAfter: 48,
        notes: 'Light soil spritz',
      ),
      WateringLog(
        id: 'seed_04',
        plantId: '1',
        plantName: 'Samantha',
        species: 'Monstera Deliciosa',
        imageUrl: 'assets/images/image_1.png',
        timestamp: now.subtract(const Duration(days: 5, hours: 4)),
        amountMl: 250,
        mode: 'Hardware Pump Pulse',
        moistureBefore: 28,
        moistureAfter: 62,
        notes: 'Hardware pulse actuated',
      ),
    ]);
    _saveToStorage();
  }

  void _saveToStorage() {
    try {
      final jsonStr = jsonEncode(_wateringLogs.map((l) => l.toJson()).toList());
      WebHardwareBridge.saveStorage(_storageKey, jsonStr);
    } catch (_) {}
  }

  Future<void> logWatering({
    required String plantId,
    required String plantName,
    required String species,
    String? imageUrl,
    int? amountMl,
    int? volumeMl,
    String? mode,
    String? careMode,
    int? moistureBefore,
    int? moistureBeforePct,
    int? moistureAfter,
    int? moistureAfterPct,
    String? notes,
    DateTime? timestamp,
  }) async {
    if (!_isLoaded) _loadFromStorage();

    final actualAmount = volumeMl ?? amountMl ?? 150;
    final actualMode = careMode ?? mode ?? 'Manual Hydration';
    final actualBefore = moistureBeforePct ?? moistureBefore;
    final actualAfter = moistureAfterPct ?? moistureAfter;

    final log = WateringLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      plantId: plantId,
      plantName: plantName,
      species: species,
      imageUrl: imageUrl,
      timestamp: timestamp ?? DateTime.now(),
      amountMl: actualAmount,
      mode: actualMode,
      moistureBefore: actualBefore,
      moistureAfter: actualAfter,
      notes: notes,
    );

    _wateringLogs.insert(0, log);
    if (_wateringLogs.length > 100) {
      _wateringLogs.removeLast();
    }
    _saveToStorage();
    notifyListeners();
  }

  /// Calculates real hydration volume breakdown by day of week for the past 7 days
  Map<String, int> getWeeklyHydrationByDay() {
    if (!_isLoaded) _loadFromStorage();

    final Map<String, int> result = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    for (final log in _wateringLogs) {
      if (log.timestamp.isAfter(sevenDaysAgo)) {
        final dayName = _dayOfWeekName(log.timestamp.weekday);
        result[dayName] = (result[dayName] ?? 0) + log.amountMl;
      }
    }

    return result;
  }

  List<Map<String, dynamic>> getWeeklyHydrationList() {
    final map = getWeeklyHydrationByDay();
    return map.entries.map((e) => {'day': e.key, 'ml': e.value}).toList();
  }

  static String _dayOfWeekName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }

  int get totalWeeklyVolumeMl {
    final daily = getWeeklyHydrationByDay();
    return daily.values.fold(0, (acc, val) => acc + val);
  }

  WateringLog? get lastWateringEvent {
    if (!_isLoaded) _loadFromStorage();
    return _wateringLogs.isNotEmpty ? _wateringLogs.first : null;
  }

  void clearLogs() {
    _wateringLogs.clear();
    _saveToStorage();
    notifyListeners();
  }
}
