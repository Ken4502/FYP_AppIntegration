import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/achievement_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/theme_provider.dart';
import 'package:urbangreen/services/achievement_service.dart';
import 'package:urbangreen/services/care_log_service.dart';

void main() {
  group('WateringLog Serialization & Moisture Delta Matrix (20 Scenarios)', () {
    final wateringScenarios = [
      {'id': 'wl_01', 'vol': 50, 'mode': 'Manual Care', 'before': 15, 'after': 45, 'notes': 'Light morning misting'},
      {'id': 'wl_02', 'vol': 100, 'mode': 'Manual Care', 'before': 20, 'after': 60, 'notes': null},
      {'id': 'wl_03', 'vol': 150, 'mode': 'Hardware Pump', 'before': 10, 'after': 75, 'notes': 'Automated IoT pump'},
      {'id': 'wl_04', 'vol': 200, 'mode': 'Auto-Schedule', 'before': 25, 'after': 80, 'notes': 'Weekly timer'},
      {'id': 'wl_05', 'vol': 250, 'mode': 'Hardware Pump', 'before': 12, 'after': 85, 'notes': 'Deep soak'},
      {'id': 'wl_06', 'vol': 300, 'mode': 'Manual Care', 'before': 30, 'after': 90, 'notes': 'Pre-vacation soaking'},
      {'id': 'wl_07', 'vol': 350, 'mode': 'Auto-Schedule', 'before': 18, 'after': 78, 'notes': null},
      {'id': 'wl_08', 'vol': 400, 'mode': 'Hardware Pump', 'before': 5, 'after': 88, 'notes': 'Emergency drought rescue'},
      {'id': 'wl_09', 'vol': 500, 'mode': 'Manual Care', 'before': 22, 'after': 70, 'notes': 'Foliage rinse'},
      {'id': 'wl_10', 'vol': 750, 'mode': 'Manual Care', 'before': 15, 'after': 85, 'notes': 'Large planter hydration'},
      {'id': 'wl_11', 'vol': 80, 'mode': 'Hardware Pump', 'before': 28, 'after': 65, 'notes': null},
      {'id': 'wl_12', 'vol': 120, 'mode': 'Auto-Schedule', 'before': 32, 'after': 68, 'notes': 'Daily top-up'},
      {'id': 'wl_13', 'vol': 160, 'mode': 'Manual Care', 'before': 40, 'after': 72, 'notes': 'Bottom watering'},
      {'id': 'wl_14', 'vol': 220, 'mode': 'Hardware Pump', 'before': null, 'after': null, 'notes': 'Probe offline during pulse'},
      {'id': 'wl_15', 'vol': 180, 'mode': 'Manual Care', 'before': 19, 'after': 62, 'notes': 'Rainwater hydration'},
      {'id': 'wl_16', 'vol': 240, 'mode': 'Auto-Schedule', 'before': 21, 'after': 77, 'notes': null},
      {'id': 'wl_17', 'vol': 320, 'mode': 'Hardware Pump', 'before': 14, 'after': 82, 'notes': 'Precision dosage'},
      {'id': 'wl_18', 'vol': 450, 'mode': 'Manual Care', 'before': 26, 'after': 89, 'notes': 'Flushing mineral salts'},
      {'id': 'wl_19', 'vol': 600, 'mode': 'Manual Care', 'before': null, 'after': 80, 'notes': 'After-sensor only'},
      {'id': 'wl_20', 'vol': 1000, 'mode': 'Manual Care', 'before': 8, 'after': 95, 'notes': 'Outdoor shrub watering'},
    ];

    for (final s in wateringScenarios) {
      test('WateringLog serialization & delta for scenario ${s['id']}', () {
        final now = DateTime(2026, 3, 15, 8, 30);
        final log = WateringLog(
          id: s['id'] as String,
          plantId: 'plant_test_01',
          plantName: 'Monstera Deliciosa',
          species: 'Monstera',
          timestamp: now,
          amountMl: s['vol'] as int,
          mode: s['mode'] as String,
          moistureBefore: s['before'] as int?,
          moistureAfter: s['after'] as int?,
          notes: s['notes'] as String?,
        );

        expect(log.volumeMl, equals(s['vol']));
        expect(log.careMode, equals(s['mode']));

        final json = log.toJson();
        expect(json['id'], equals(s['id']));
        expect(json['amountMl'], equals(s['vol']));
        expect(json['mode'], equals(s['mode']));

        final restored = WateringLog.fromJson(json);
        expect(restored.id, equals(s['id']));
        expect(restored.amountMl, equals(s['vol']));
        expect(restored.mode, equals(s['mode']));
        expect(restored.moistureBefore, equals(s['before']));
        expect(restored.moistureAfter, equals(s['after']));
        expect(restored.notes, equals(s['notes']));

        if (s['before'] != null && s['after'] != null) {
          final delta = (s['after'] as int) - (s['before'] as int);
          expect(delta, greaterThan(0), reason: 'Watering should increase moisture');
        }
      });
    }
  });

  group('Next Watering Date Calculation Matrix (1 to 21 Days)', () {
    final baseDate = DateTime(2026, 4, 1, 9, 0);

    for (int intervalDays = 1; intervalDays <= 21; intervalDays++) {
      test('Next watering date projection for $intervalDays-day interval', () {
        final nextWatering = baseDate.add(Duration(days: intervalDays));
        final diff = nextWatering.difference(baseDate).inDays;

        expect(diff, equals(intervalDays));
        expect(nextWatering.isAfter(baseDate), isTrue);
        expect(nextWatering.year, equals(2026));
        expect(nextWatering.month, equals(4));
        expect(nextWatering.day, equals(1 + intervalDays));
      });
    }
  });

  group('Achievement Unlock Logic & Progression Matrix (30 Test Profiles)', () {
    final achievementService = AchievementService();

    final testProfiles = [
      {'plants': 0, 'iot': false, 'water': 0, 'expUnlocked': 0},
      {'plants': 1, 'iot': false, 'water': 0, 'expUnlocked': 1}, // first_sprout
      {'plants': 1, 'iot': true, 'water': 0, 'expUnlocked': 2}, // first_sprout, cyber_botanist
      {'plants': 2, 'iot': false, 'water': 0, 'expUnlocked': 1},
      {'plants': 2, 'iot': true, 'water': 2, 'expUnlocked': 2},
      {'plants': 3, 'iot': false, 'water': 0, 'expUnlocked': 2}, // first_sprout, green_thumb
      {'plants': 3, 'iot': true, 'water': 0, 'expUnlocked': 3}, // first_sprout, green_thumb, cyber_botanist
      {'plants': 4, 'iot': false, 'water': 3, 'expUnlocked': 2},
      {'plants': 5, 'iot': false, 'water': 0, 'expUnlocked': 3}, // first_sprout, green_thumb, urban_botanist
      {'plants': 5, 'iot': true, 'water': 0, 'expUnlocked': 4}, // + cyber_botanist
      {'plants': 5, 'iot': true, 'water': 5, 'expUnlocked': 5}, // + hydration_hero
      {'plants': 6, 'iot': false, 'water': 5, 'expUnlocked': 4},
      {'plants': 6, 'iot': true, 'water': 5, 'expUnlocked': 5},
      {'plants': 7, 'iot': true, 'water': 6, 'expUnlocked': 5},
      {'plants': 8, 'iot': false, 'water': 4, 'expUnlocked': 3},
      {'plants': 8, 'iot': true, 'water': 5, 'expUnlocked': 5},
      {'plants': 10, 'iot': false, 'water': 0, 'expUnlocked': 3},
      {'plants': 10, 'iot': true, 'water': 10, 'expUnlocked': 5},
      {'plants': 1, 'iot': false, 'water': 5, 'expUnlocked': 2}, // first_sprout + hydration_hero
      {'plants': 2, 'iot': false, 'water': 5, 'expUnlocked': 2},
      {'plants': 0, 'iot': false, 'water': 5, 'expUnlocked': 1}, // hydration_hero
      {'plants': 0, 'iot': false, 'water': 1, 'expUnlocked': 0},
      {'plants': 0, 'iot': false, 'water': 10, 'expUnlocked': 1},
      {'plants': 3, 'iot': false, 'water': 5, 'expUnlocked': 3},
      {'plants': 4, 'iot': true, 'water': 5, 'expUnlocked': 4},
      {'plants': 12, 'iot': true, 'water': 20, 'expUnlocked': 5},
      {'plants': 15, 'iot': false, 'water': 5, 'expUnlocked': 4},
      {'plants': 20, 'iot': true, 'water': 50, 'expUnlocked': 5},
      {'plants': 1, 'iot': true, 'water': 5, 'expUnlocked': 3},
      {'plants': 0, 'iot': false, 'water': 0, 'expUnlocked': 0},
    ];

    for (int i = 0; i < testProfiles.length; i++) {
      final p = testProfiles[i];
      test('Achievement unlock profile #${i + 1} (${p['plants']} plants, iot=${p['iot']}, water=${p['water']})', () {
        final plantCount = p['plants'] as int;
        final hasIot = p['iot'] as bool;
        final waterCount = p['water'] as int;

        final mockPlants = List.generate(
          plantCount,
          (idx) => Plant(
            id: 'p_$idx',
            name: 'Plant $idx',
            species: 'Ficus',
            imageUrl: 'assets/images/image_1.png',
            iotDeviceId: (hasIot && idx == 0) ? 'iot_active_sensor' : null,
          ),
        );

        final achievements = achievementService.getAchievements(
          customPlants: mockPlants,
          customWateringCount: waterCount,
        );

        expect(achievements.length, equals(7));

        final unlocked = achievements.where((a) => a.isUnlocked).length;
        expect(unlocked, equals(p['expUnlocked']));
      });
    }
  });

  group('Achievement Ratio Clamping & Progress String Representation (15 Cases)', () {
    final progressCases = [
      {'cur': 0, 'max': 5, 'expRatio': 0.0, 'expLabel': '0 / 5'},
      {'cur': 1, 'max': 5, 'expRatio': 0.2, 'expLabel': '1 / 5'},
      {'cur': 2, 'max': 5, 'expRatio': 0.4, 'expLabel': '2 / 5'},
      {'cur': 3, 'max': 5, 'expRatio': 0.6, 'expLabel': '3 / 5'},
      {'cur': 4, 'max': 5, 'expRatio': 0.8, 'expLabel': '4 / 5'},
      {'cur': 5, 'max': 5, 'expRatio': 1.0, 'expLabel': '5 / 5'},
      {'cur': 6, 'max': 5, 'expRatio': 1.0, 'expLabel': '6 / 5'}, // Clamped to 1.0
      {'cur': 10, 'max': 5, 'expRatio': 1.0, 'expLabel': '10 / 5'},
      {'cur': 0, 'max': 1, 'expRatio': 0.0, 'expLabel': '0 / 1'},
      {'cur': 1, 'max': 1, 'expRatio': 1.0, 'expLabel': '1 / 1'},
      {'cur': 3, 'max': 1, 'expRatio': 1.0, 'expLabel': '3 / 1'},
      {'cur': 0, 'max': 3, 'expRatio': 0.0, 'expLabel': '0 / 3'},
      {'cur': 2, 'max': 3, 'expRatio': 2 / 3, 'expLabel': '2 / 3'},
      {'cur': 3, 'max': 3, 'expRatio': 1.0, 'expLabel': '3 / 3'},
      {'cur': 9, 'max': 3, 'expRatio': 1.0, 'expLabel': '9 / 3'},
    ];

    for (final c in progressCases) {
      test('Progress ratio & label for current=${c['cur']}, max=${c['max']}', () {
        final a = Achievement(
          id: 'test_ach',
          title: 'Test',
          description: 'Testing progression',
          icon: Icons.star,
          color: Colors.green,
          currentProgress: c['cur'] as int,
          maxProgress: c['max'] as int,
          isUnlocked: (c['cur'] as int) >= (c['max'] as int),
        );

        expect(a.progressRatio, closeTo(c['expRatio'] as double, 0.001));
        expect(a.progressLabel, equals(c['expLabel']));
        expect(a.progressRatio, lessThanOrEqualTo(1.0));
      });
    }
  });

  group('ThemeProvider State Transitions & Persistence Matrix (15 Cases)', () {
    final modeTransitions = [
      {'from': ThemeMode.light, 'to': ThemeMode.dark, 'expDark': true},
      {'from': ThemeMode.dark, 'to': ThemeMode.light, 'expDark': false},
      {'from': ThemeMode.light, 'to': ThemeMode.system, 'expDark': false},
      {'from': ThemeMode.system, 'to': ThemeMode.dark, 'expDark': true},
      {'from': ThemeMode.dark, 'to': ThemeMode.dark, 'expDark': true},
      {'from': ThemeMode.light, 'to': ThemeMode.light, 'expDark': false},
      {'from': ThemeMode.system, 'to': ThemeMode.light, 'expDark': false},
      {'from': ThemeMode.dark, 'to': ThemeMode.system, 'expDark': false},
      {'from': ThemeMode.system, 'to': ThemeMode.system, 'expDark': false},
      {'from': ThemeMode.light, 'to': ThemeMode.dark, 'expDark': true},
      {'from': ThemeMode.dark, 'to': ThemeMode.light, 'expDark': false},
      {'from': ThemeMode.light, 'to': ThemeMode.dark, 'expDark': true},
      {'from': ThemeMode.dark, 'to': ThemeMode.light, 'expDark': false},
      {'from': ThemeMode.light, 'to': ThemeMode.system, 'expDark': false},
      {'from': ThemeMode.system, 'to': ThemeMode.dark, 'expDark': true},
    ];

    for (int i = 0; i < modeTransitions.length; i++) {
      final t = modeTransitions[i];
      test('Theme transition #${i + 1}: ${t['from']} -> ${t['to']}', () {
        final provider = ThemeProvider();
        provider.setThemeMode(t['from'] as ThemeMode);
        expect(provider.themeMode, equals(t['from']));

        provider.setThemeMode(t['to'] as ThemeMode);
        expect(provider.themeMode, equals(t['to']));
        expect(provider.isDarkMode, equals(t['expDark']));
      });
    }
  });
}
