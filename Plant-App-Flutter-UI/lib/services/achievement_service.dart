import 'package:flutter/material.dart';
import 'package:urbangreen/models/achievement_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/plant_service.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static const String _diagKey = 'urbangreen_diag_scans_count';
  static const String _storeKey = 'urbangreen_store_actions_count';

  /// Records a successful AI plant diagnostic scan
  void recordDiagnosticScan() {
    try {
      final current = getDiagnosticScanCount();
      WebHardwareBridge.saveStorage(_diagKey, (current + 1).toString());
    } catch (_) {}
  }

  int getDiagnosticScanCount() {
    try {
      final val = WebHardwareBridge.loadStorage(_diagKey);
      if (val != null) return int.tryParse(val) ?? 0;
    } catch (_) {}
    return 0;
  }

  /// Records an e-commerce cart or order activity
  void recordStoreAction() {
    try {
      final current = getStoreActionCount();
      WebHardwareBridge.saveStorage(_storeKey, (current + 1).toString());
    } catch (_) {}
  }

  int getStoreActionCount() {
    try {
      final val = WebHardwareBridge.loadStorage(_storeKey);
      if (val != null) return int.tryParse(val) ?? 0;
    } catch (_) {}
    return 0;
  }

  /// Evaluates and returns all botanical achievement badges
  List<Achievement> getAchievements({
    List<Plant>? customPlants,
    int? customWateringCount,
  }) {
    final plants = customPlants ?? PlantService().myPlants;
    final plantCount = plants.length;
    final hasIot = plants.any((p) => p.hasIot);

    final waterCount = customWateringCount ??
        CareLogService().wateringLogs.length;

    final scanCount = getDiagnosticScanCount();
    final storeCount = getStoreActionCount();

    return [
      // 1. First Sprout
      Achievement(
        id: 'first_sprout',
        title: 'First Sprout',
        description: 'Add your first plant specimen to the garden sanctuary',
        icon: Icons.eco_outlined,
        color: const Color(0xFF2E7D32),
        currentProgress: plantCount.clamp(0, 1),
        maxProgress: 1,
        isUnlocked: plantCount >= 1,
        category: 'Gardening',
      ),

      // 2. Green Thumb
      Achievement(
        id: 'green_thumb',
        title: 'Green Thumb',
        description: 'Cultivate 3 or more healthy plants in your sanctuary',
        icon: Icons.yard_outlined,
        color: const Color(0xFF1B5E20),
        currentProgress: plantCount.clamp(0, 3),
        maxProgress: 3,
        isUnlocked: plantCount >= 3,
        category: 'Gardening',
      ),

      // 3. Urban Botanist
      Achievement(
        id: 'urban_botanist',
        title: 'Urban Botanist',
        description: 'Cultivate 5 or more botanical specimens across your home',
        icon: Icons.park_outlined,
        color: const Color(0xFF004D40),
        currentProgress: plantCount.clamp(0, 5),
        maxProgress: 5,
        isUnlocked: plantCount >= 5,
        category: 'Mastery',
      ),

      // 4. Hydration Hero
      Achievement(
        id: 'hydration_hero',
        title: 'Hydration Hero',
        description: 'Log 5 hydration and watering events for your specimens',
        icon: Icons.water_drop_outlined,
        color: const Color(0xFF0288D1),
        currentProgress: waterCount.clamp(0, 5),
        maxProgress: 5,
        isUnlocked: waterCount >= 5,
        category: 'Care',
      ),

      // 5. Cyber-Botanist
      Achievement(
        id: 'cyber_botanist',
        title: 'Cyber-Botanist',
        description: 'Connect an automated IoT telemetry probe or sensor',
        icon: Icons.sensors,
        color: const Color(0xFF5E35B1),
        currentProgress: hasIot ? 1 : 0,
        maxProgress: 1,
        isUnlocked: hasIot,
        category: 'IoT Tech',
      ),

      // 6. Foliage Diagnostician
      Achievement(
        id: 'foliage_diagnostician',
        title: 'Foliage Scout',
        description: 'Perform an AI computer vision plant health diagnosis',
        icon: Icons.document_scanner_outlined,
        color: const Color(0xFFE65100),
        currentProgress: scanCount.clamp(0, 1),
        maxProgress: 1,
        isUnlocked: scanCount >= 1,
        category: 'AI Vision',
      ),

      // 7. Botanical Marketplace Supporter
      Achievement(
        id: 'marketplace_patron',
        title: 'Market Supporter',
        description: 'Explore and interact with UrbanGreen botanical supplies',
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFFC2185B),
        currentProgress: storeCount.clamp(0, 1),
        maxProgress: 1,
        isUnlocked: storeCount >= 1,
        category: 'Community',
      ),
    ];
  }

  int get unlockedCount =>
      getAchievements().where((a) => a.isUnlocked).length;

  int get totalCount => getAchievements().length;

  double get overallProgress {
    final list = getAchievements();
    if (list.isEmpty) return 0.0;
    return list.where((a) => a.isUnlocked).length / list.length;
  }
}
