import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'platform/web_hardware_bridge.dart';

class PlantService extends ChangeNotifier {
  static final PlantService _instance = PlantService._internal();
  factory PlantService() => _instance;

  final List<Plant> _plants = [];
  bool _isLoaded = false;

  PlantService._internal() {
    _loadFromStorage();
  }

  List<Plant> get myPlants {
    if (!_isLoaded) {
      _loadFromStorage();
    }
    return List.unmodifiable(_plants);
  }

  /// Asynchronous initialization called before runApp() in main.dart
  Future<void> init() async {
    final savedJson = await WebHardwareBridge.loadStorageAsync('user_garden_plants_json');
    if (savedJson != null && savedJson.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        final List<Plant> loaded = [];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(Plant.fromJson(item));
          }
        }
        _plants.clear();
        _plants.addAll(loaded);
        _isLoaded = true;
        notifyListeners();
        _syncFromFirestoreIfAvailable();
        return;
      } catch (e) {
        debugPrint('PlantService init JSON parse error: $e');
      }
    }

    if (!_isLoaded || _plants.isEmpty) {
      _loadFromStorage();
    }
    _syncFromFirestoreIfAvailable();
  }

  void _loadFromStorage() {
    final savedJson = WebHardwareBridge.loadStorage('user_garden_plants_json');
    if (savedJson != null && savedJson.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        final List<Plant> loaded = [];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(Plant.fromJson(item));
          }
        }
        _plants.clear();
        _plants.addAll(loaded);
        _isLoaded = true;
        return;
      } catch (_) {}
    }

    // Default starter plants ONLY if storage has never been initialized
    if (!_isLoaded && _plants.isEmpty) {
      _plants.clear();
      _plants.addAll([
        Plant(
          id: "1",
          name: "Samantha",
          species: "Monstera Deliciosa",
          imageUrl: "assets/images/image_1.png",
          description: "Thriving in the living room corner with bright indirect light. Watered every 7 days.",
          iotDeviceId: "SmartPlant-ESP32",
        ),
        Plant(
          id: "2",
          name: "Angelica",
          species: "Ficus Lyrata (Fiddle Leaf)",
          imageUrl: "assets/images/image_2.png",
          description: "Requires careful moisture balance. Sensitive to cold drafts and overwatering.",
        ),
        Plant(
          id: "3",
          name: "Bob",
          species: "Sansevieria Trifasciata",
          imageUrl: "assets/images/image_3.png",
          description: "Hardy air-purifier. Very tolerant of low lighting and infrequent watering.",
        ),
      ]);
      _isLoaded = true;
      _saveToStorage();
    }
  }

  void _saveToStorage() {
    try {
      final jsonStr = jsonEncode(_plants.map((p) => p.toJson()).toList());
      WebHardwareBridge.saveStorage('user_garden_plants_json', jsonStr);
      _syncToFirestore();
    } catch (_) {}
  }

  void _syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'gardenPlantsCount': _plants.length,
          'gardenPlants': _plants.map((p) => p.toJson()).toList(),
          'gardenLastSaved': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  void _syncFromFirestoreIfAvailable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['gardenPlants'] is List) {
            final List<dynamic> cloudList = data['gardenPlants'] as List<dynamic>;
            if (cloudList.isNotEmpty && _plants.length <= 3) {
              final List<Plant> cloudPlants = [];
              for (final item in cloudList) {
                if (item is Map<String, dynamic>) {
                  cloudPlants.add(Plant.fromJson(item));
                }
              }
              if (cloudPlants.isNotEmpty && cloudPlants.length >= _plants.length) {
                _plants.clear();
                _plants.addAll(cloudPlants);
                _isLoaded = true;
                _saveToStorage();
                notifyListeners();
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void addPlant(Plant plant) {
    Plant plantToSave = plant;

    // Permanently copy camera photo to app's private files directory so it never gets cleaned up by Android cache
    if (!plant.imageUrl.startsWith('http') && !plant.imageUrl.startsWith('assets/')) {
      try {
        final originalFile = File(plant.imageUrl);
        if (originalFile.existsSync()) {
          final filesDir = WebHardwareBridge.loadStorage('app_files_dir');
          if (filesDir != null && filesDir.isNotEmpty) {
            final plantDir = Directory('$filesDir/plants');
            if (!plantDir.existsSync()) {
              plantDir.createSync(recursive: true);
            }
            final ext = plant.imageUrl.contains('.') ? plant.imageUrl.split('.').last : 'jpg';
            final destPath = '${plantDir.path}/plant_${plant.id}.$ext';
            originalFile.copySync(destPath);
            plantToSave = plant.copyWith(imageUrl: destPath);
          }
        }
      } catch (e) {
        debugPrint('PlantService image copy warning: $e');
      }
    }

    _plants.insert(0, plantToSave);
    _saveToStorage();
    notifyListeners();
  }

  void updatePlant(Plant plant) {
    final index = _plants.indexWhere((p) => p.id == plant.id);
    if (index != -1) {
      _plants[index] = plant;
      _saveToStorage();
      notifyListeners();
    }
  }

  void deletePlant(String id) {
    _plants.removeWhere((p) => p.id == id);
    _saveToStorage();
    notifyListeners();
  }

  Plant? getPlantById(String id) {
    try {
      return _plants.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the plant currently assigned to [deviceId], or null if unassigned.
  Plant? getPlantForDevice(String deviceId) {
    if (!_isLoaded) _loadFromStorage();
    try {
      return _plants.firstWhere(
        (p) => p.iotDeviceId != null && p.iotDeviceId == deviceId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether a specific IoT device is assigned to any plant.
  bool isDeviceAssigned(String deviceId) {
    return getPlantForDevice(deviceId) != null;
  }

  /// Total count of plants monitored by an IoT hardware device.
  int get monitoredPlantsCount {
    if (!_isLoaded) _loadFromStorage();
    return _plants.where((p) => p.iotDeviceId != null && p.iotDeviceId!.isNotEmpty).length;
  }

  /// Assign an IoT device to a plant, strictly enforcing a 1-to-1 relationship:
  /// 1. Any other plant that previously had [deviceId] assigned has its probe unlinked.
  /// 2. [plantId] has its probe assigned to [deviceId].
  void assignDeviceToPlant({required String plantId, required String deviceId}) {
    if (!_isLoaded) _loadFromStorage();

    // 1. Revoke deviceId from any other plant
    for (int i = 0; i < _plants.length; i++) {
      if (_plants[i].iotDeviceId == deviceId && _plants[i].id != plantId) {
        _plants[i].iotDeviceId = null;
      }
    }

    // 2. Assign deviceId to the selected plant
    final targetIndex = _plants.indexWhere((p) => p.id == plantId);
    if (targetIndex != -1) {
      _plants[targetIndex].iotDeviceId = deviceId;
    }

    _saveToStorage();
    notifyListeners();
  }

  /// Unlinks any IoT device from a specific plant.
  void unassignDeviceFromPlant(String plantId) {
    if (!_isLoaded) _loadFromStorage();
    final index = _plants.indexWhere((p) => p.id == plantId);
    if (index != -1) {
      _plants[index].iotDeviceId = null;
      _saveToStorage();
      notifyListeners();
    }
  }

  /// Unlinks a specific device from whatever plant it was assigned to.
  void unassignDevice(String deviceId) {
    if (!_isLoaded) _loadFromStorage();
    bool changed = false;
    for (int i = 0; i < _plants.length; i++) {
      if (_plants[i].iotDeviceId == deviceId) {
        _plants[i].iotDeviceId = null;
        changed = true;
      }
    }
    if (changed) {
      _saveToStorage();
      notifyListeners();
    }
  }
}
