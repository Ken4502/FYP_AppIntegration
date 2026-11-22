import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/services/iot_firestore_service.dart';
import 'platform/web_hardware_bridge.dart';

class PlantService extends ChangeNotifier {
  static final PlantService _instance = PlantService._internal();
  factory PlantService() => _instance;

  final List<Plant> _plants = [];
  bool _isLoaded = false;
  String? _currentUserId;

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  PlantService._internal() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          clearOnLogout();
        } else if (user.uid != _currentUserId) {
          _currentUserId = user.uid;
          loadForUser(user.uid);
        }
      });
    } catch (_) {}
  }

  String _storageKeyFor(String? uid) {
    if (uid != null && uid.isNotEmpty) {
      return 'user_${uid}_garden_plants_json';
    }
    return 'guest_garden_plants_json';
  }

  List<Plant> get myPlants {
    if (!_isLoaded) {
      _loadFromStorage();
    }
    return List.unmodifiable(_plants);
  }

  /// Wipes in-memory plants and state when user logs out
  void clearOnLogout() {
    _currentUserId = null;
    _plants.clear();
    _isLoaded = false;
    notifyListeners();
  }

  /// Load plants for a specific authenticated user from local storage and Firestore
  Future<void> loadForUser(String uid) async {
    _currentUserId = uid;
    _plants.clear();

    // 1. Try user-scoped local storage first for instant UI response
    final key = _storageKeyFor(uid);
    final savedJson = await WebHardwareBridge.loadStorageAsync(key) ?? WebHardwareBridge.loadStorage(key);
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
      } catch (e) {
        debugPrint('PlantService loadForUser storage parse error: $e');
      }
    }

    // 2. Fetch ground-truth plants from Firestore
    await _syncFromFirestoreIfAvailable();
    _isLoaded = true;
    notifyListeners();
  }

  /// Asynchronous initialization called before runApp() in main.dart
  Future<void> init() async {
    final user = _currentUser;
    if (user != null) {
      await loadForUser(user.uid);
    } else {
      _loadFromStorage();
    }
  }

  void _loadFromStorage() {
    final user = _currentUser;
    final key = _storageKeyFor(user?.uid);
    final savedJson = WebHardwareBridge.loadStorage(key);
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

    // Default starter plants in guest / unauthenticated mode or testing
    _plants.clear();
    if (user == null) {
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
    }
    _isLoaded = true;
  }

  void _syncToFirestore() async {
    try {
      final user = _currentUser;
      if (user != null) {
        // Sync garden summary to user profile
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'gardenPlantsCount': _plants.length,
          'gardenPlants': _plants.map((p) => p.toJson()).toList(),
          'gardenLastSaved': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> _savePlantDocToFirestore(Plant plant, String uid) async {
    try {
      final data = plant.toJson();
      data['userId'] = uid;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plant.id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving plant to firestore plants collection: $e');
    }
  }

  Future<void> _syncFromFirestoreIfAvailable() async {
    try {
      final user = _currentUser;
      if (user != null) {
        // 1. Fetch user-scoped plants from the root 'plants' collection
        final plantSnap = await FirebaseFirestore.instance
            .collection('plants')
            .where('userId', isEqualTo: user.uid)
            .get();

        if (plantSnap.docs.isNotEmpty) {
          final List<Plant> cloudPlants = [];
          for (final doc in plantSnap.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            cloudPlants.add(Plant.fromJson(data));
          }
          _plants.clear();
          _plants.addAll(cloudPlants);
          _isLoaded = true;
          _saveToStorageLocallyOnly();
          notifyListeners();
          return;
        }

        // 2. Fallback check for legacy user doc array
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['gardenPlants'] is List && (data['gardenPlants'] as List).isNotEmpty) {
            final List<dynamic> cloudList = data['gardenPlants'] as List<dynamic>;
            final List<Plant> cloudPlants = [];
            for (final item in cloudList) {
              if (item is Map<String, dynamic>) {
                final p = Plant.fromJson(item);
                cloudPlants.add(p);
                // Migrate to root plants collection
                _savePlantDocToFirestore(p, user.uid);
              }
            }
            _plants.clear();
            _plants.addAll(cloudPlants);
            _isLoaded = true;
            _saveToStorageLocallyOnly();
            notifyListeners();
            return;
          }
        }

        // If neither root collection nor legacy array has plants, cloud account is empty
        _plants.clear();
        _saveToStorageLocallyOnly();
        _isLoaded = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _saveToStorageLocallyOnly() {
    try {
      final user = _currentUser;
      final key = _storageKeyFor(user?.uid ?? _currentUserId);
      final jsonStr = jsonEncode(_plants.map((p) => p.toJson()).toList());
      WebHardwareBridge.saveStorage(key, jsonStr);
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
    _saveToStorageLocallyOnly();
    notifyListeners();

    final user = _currentUser;
    if (user != null) {
      _savePlantDocToFirestore(plantToSave, user.uid);
      _syncToFirestore();
    }
  }

  void updatePlant(Plant plant) {
    final index = _plants.indexWhere((p) => p.id == plant.id);
    if (index != -1) {
      _plants[index] = plant;
      _saveToStorageLocallyOnly();
      notifyListeners();

      final user = _currentUser;
      if (user != null) {
        _savePlantDocToFirestore(plant, user.uid);
        _syncToFirestore();

        // If this plant is linked to an IoT hardware device, synchronize name, image, and environment
        if (plant.iotDeviceId != null && plant.iotDeviceId!.isNotEmpty) {
          FirebaseFirestore.instance
              .collection('iot_devices')
              .doc(plant.iotDeviceId)
              .set({
            'linkedPlantName': plant.name,
            'linkedPlantImage': plant.imageUrl,
            'isIndoor': plant.isIndoor,
            'environment': plant.environment,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e) {
            debugPrint('Error syncing plant metadata to iot_devices: $e');
          });
        }
      }
    }
  }

  void deletePlant(String id) {
    final plantToDelete = getPlantById(id);
    _plants.removeWhere((p) => p.id == id);
    _saveToStorageLocallyOnly();
    notifyListeners();

    final user = _currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('plants').doc(id).delete().catchError((_) {});
      if (plantToDelete != null && plantToDelete.hasIot) {
        IotFirestoreService().unlinkPlant(plantToDelete.iotDeviceId!);
      }
      _syncToFirestore();
    }
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
  /// 3. Synchronizes to Cloud Firestore plants collection and iot_devices document.
  void assignDeviceToPlant({required String plantId, required String deviceId}) {
    if (!_isLoaded) _loadFromStorage();
    final user = _currentUser;

    // 1. Revoke deviceId from any other plant
    for (int i = 0; i < _plants.length; i++) {
      if (_plants[i].iotDeviceId == deviceId && _plants[i].id != plantId) {
        _plants[i].iotDeviceId = null;
        if (user != null) {
          _savePlantDocToFirestore(_plants[i], user.uid);
        }
      }
    }

    // 2. Assign deviceId to the selected plant
    final targetIndex = _plants.indexWhere((p) => p.id == plantId);
    if (targetIndex != -1) {
      _plants[targetIndex].iotDeviceId = deviceId;
      final targetPlant = _plants[targetIndex];
      if (user != null) {
        _savePlantDocToFirestore(targetPlant, user.uid);
        // Link probe in Cloud Firestore iot_devices
        IotFirestoreService().linkPlant(
          deviceId,
          plantId: targetPlant.id,
          plantName: targetPlant.name,
          plantImage: targetPlant.imageUrl,
          optimalMinMoisture: targetPlant.optimalMinMoisture,
        );
      }
    }

    _saveToStorageLocallyOnly();
    notifyListeners();
    _syncToFirestore();
  }

  /// Unlinks any IoT device from a specific plant.
  void unassignDeviceFromPlant(String plantId) {
    if (!_isLoaded) _loadFromStorage();
    final user = _currentUser;
    final index = _plants.indexWhere((p) => p.id == plantId);
    if (index != -1) {
      final oldDeviceId = _plants[index].iotDeviceId;
      _plants[index].iotDeviceId = null;
      if (user != null) {
        _savePlantDocToFirestore(_plants[index], user.uid);
        if (oldDeviceId != null && oldDeviceId.isNotEmpty) {
          IotFirestoreService().unlinkPlant(oldDeviceId);
        }
      }
      _saveToStorageLocallyOnly();
      notifyListeners();
      _syncToFirestore();
    }
  }

  /// Unlinks a specific device from whatever plant it was assigned to.
  void unassignDevice(String deviceId, {bool notifyDevice = true}) {
    if (!_isLoaded) _loadFromStorage();
    final user = _currentUser;
    bool changed = false;
    for (int i = 0; i < _plants.length; i++) {
      if (_plants[i].iotDeviceId == deviceId) {
        _plants[i].iotDeviceId = null;
        if (user != null) {
          _savePlantDocToFirestore(_plants[i], user.uid);
        }
        changed = true;
      }
    }
    if (user != null && notifyDevice) {
      IotFirestoreService().unlinkPlant(deviceId);
    }
    if (changed) {
      _saveToStorageLocallyOnly();
      notifyListeners();
      _syncToFirestore();
    }
  }
}
