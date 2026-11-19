import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
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

  final List<WateringLog> _wateringLogs = [];
  bool _isLoaded = false;
  String? _currentUserId;

  CareLogService._internal() {
    _initAuthListener();
  }

  void _initAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        clearOnLogout();
      } else if (user.uid != _currentUserId) {
        _currentUserId = user.uid;
        loadForUser(user.uid);
      }
    });
  }

  String _storageKeyFor(String? uid) {
    if (uid != null && uid.isNotEmpty) {
      return 'user_${uid}_garden_watering_logs_json';
    }
    return 'guest_garden_watering_logs_json';
  }

  List<WateringLog> get wateringLogs {
    if (!_isLoaded) _loadFromStorage();
    return List.unmodifiable(_wateringLogs);
  }

  void clearOnLogout() {
    _currentUserId = null;
    _wateringLogs.clear();
    _isLoaded = false;
    notifyListeners();
  }

  Future<void> loadForUser(String uid) async {
    _currentUserId = uid;
    _wateringLogs.clear();
    final key = _storageKeyFor(uid);
    final savedJson = await WebHardwareBridge.loadStorageAsync(key) ?? WebHardwareBridge.loadStorage(key);
    if (savedJson != null && savedJson.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _wateringLogs.add(WateringLog.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint('CareLogService loadForUser parse error: $e');
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await loadForUser(user.uid);
    } else {
      _loadFromStorage();
    }
  }

  void _loadFromStorage() {
    _isLoaded = true;
    final user = FirebaseAuth.instance.currentUser;
    final key = _storageKeyFor(user?.uid ?? _currentUserId);
    final savedJson = WebHardwareBridge.loadStorage(key);
    if (savedJson != null && savedJson.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        _wateringLogs.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _wateringLogs.add(WateringLog.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint('CareLogService load error: $e');
      }
    } else {
      _wateringLogs.clear();
    }
  }

  void _saveToStorage() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final key = _storageKeyFor(user?.uid ?? _currentUserId);
      final jsonStr = jsonEncode(_wateringLogs.map((l) => l.toJson()).toList());
      WebHardwareBridge.saveStorage(key, jsonStr);
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
