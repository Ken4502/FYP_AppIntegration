import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/components/achievements_sheet.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/theme_provider.dart';
import 'package:urbangreen/screens/account/account_screen.dart';
import 'package:urbangreen/services/achievement_service.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider & Botanical Dark Mode Tests', () {
    setUp(() {
      WebHardwareBridge.removeStorage('urbangreen_theme_mode');
    });

    test('ThemeProvider initializes with light mode and toggles to dark mode', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, equals(ThemeMode.light));
      expect(provider.isDarkMode, isFalse);

      provider.toggleTheme();
      expect(provider.themeMode, equals(ThemeMode.dark));
      expect(provider.isDarkMode, isTrue);

      provider.toggleTheme();
      expect(provider.themeMode, equals(ThemeMode.light));
      expect(provider.isDarkMode, isFalse);
    });

    test('ThemeProvider persists dark mode selection in local storage', () {
      final provider = ThemeProvider();
      provider.setThemeMode(ThemeMode.dark);

      final saved = WebHardwareBridge.loadStorage('urbangreen_theme_mode');
      expect(saved, equals('dark'));

      final restoredProvider = ThemeProvider();
      expect(restoredProvider.themeMode, equals(ThemeMode.dark));
      expect(restoredProvider.isDarkMode, isTrue);
    });

    test('Botanical dark mode palette constants are correctly defined', () {
      expect(kDarkBackgroundColor, const Color(0xFF0F1712));
      expect(kDarkSurfaceColor, const Color(0xFF16231C));
      expect(kDarkCardColor, const Color(0xFF1B2C23));
      expect(kDarkTextPrimary, const Color(0xFFF0FDF4));
      expect(kDarkTextSecondary, const Color(0xFF9AB2A3));
      expect(kDarkBorderSubtle, const Color(0xFF24382D));
    });
  });

  group('AchievementService Botanical Milestones Tests', () {
    setUp(() {
      WebHardwareBridge.removeStorage('urbangreen_diag_scans_count');
      WebHardwareBridge.removeStorage('urbangreen_store_actions_count');
    });

    test('Empty garden yields 0 unlocked gardening achievements', () {
      final service = AchievementService();
      final achievements = service.getAchievements(customPlants: [], customWateringCount: 0);

      expect(achievements.length, equals(7));

      final firstSprout = achievements.firstWhere((a) => a.id == 'first_sprout');
      expect(firstSprout.isUnlocked, isFalse);
      expect(firstSprout.currentProgress, equals(0));

      final cyberBotanist = achievements.firstWhere((a) => a.id == 'cyber_botanist');
      expect(cyberBotanist.isUnlocked, isFalse);
    });

    test('Adding 1 specimen unlocks First Sprout and marks progress on Green Thumb', () {
      final service = AchievementService();
      final plants = [
        Plant(
          id: 'p1',
          name: 'Snake Plant',
          species: 'Sansevieria trifasciata',
          imageUrl: 'assets/images/image_2.png',
        ),
      ];

      final achievements = service.getAchievements(customPlants: plants);
      final firstSprout = achievements.firstWhere((a) => a.id == 'first_sprout');
      expect(firstSprout.isUnlocked, isTrue);
      expect(firstSprout.currentProgress, equals(1));

      final greenThumb = achievements.firstWhere((a) => a.id == 'green_thumb');
      expect(greenThumb.isUnlocked, isFalse);
      expect(greenThumb.currentProgress, equals(1));
      expect(greenThumb.progressRatio, closeTo(1 / 3, 0.01));
    });

    test('Pairing IoT device unlocks Cyber-Botanist milestone', () {
      final service = AchievementService();
      final plants = [
        Plant(
          id: 'p1',
          name: 'Snake Plant',
          species: 'Sansevieria trifasciata',
          imageUrl: 'assets/images/image_2.png',
          iotDeviceId: 'probe_mesh_01',
        ),
      ];

      final achievements = service.getAchievements(customPlants: plants);
      final cyberBotanist = achievements.firstWhere((a) => a.id == 'cyber_botanist');
      expect(cyberBotanist.isUnlocked, isTrue);
      expect(cyberBotanist.currentProgress, equals(1));
    });

    test('Logging 5 waterings unlocks Hydration Hero', () {
      final service = AchievementService();
      final achievements = service.getAchievements(
        customPlants: [],
        customWateringCount: 5,
      );

      final hydrationHero = achievements.firstWhere((a) => a.id == 'hydration_hero');
      expect(hydrationHero.isUnlocked, isTrue);
      expect(hydrationHero.currentProgress, equals(5));
      expect(hydrationHero.progressRatio, equals(1.0));
    });

    test('Recording AI diagnosis and store actions updates milestones', () {
      final service = AchievementService();

      expect(service.getDiagnosticScanCount(), equals(0));
      service.recordDiagnosticScan();
      expect(service.getDiagnosticScanCount(), equals(1));

      expect(service.getStoreActionCount(), equals(0));
      service.recordStoreAction();
      expect(service.getStoreActionCount(), equals(1));

      final achievements = service.getAchievements(customPlants: []);
      final scout = achievements.firstWhere((a) => a.id == 'foliage_diagnostician');
      expect(scout.isUnlocked, isTrue);

      final patron = achievements.firstWhere((a) => a.id == 'marketplace_patron');
      expect(patron.isUnlocked, isTrue);
    });
  });

  group('Dark Mode & Achievements Widget Tests', () {
    testWidgets('AccountScreen displays Gardener Milestones card and Dark Mode toggle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartModel>(create: (_) => CartModel()),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, tp, child) {
              return MaterialApp(
                themeMode: tp.themeMode,
                home: const AccountScreen(),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Milestones card is displayed
      expect(find.text('Gardener Milestones'), findsOneWidget);
      expect(find.textContaining('Unlocked'), findsOneWidget);

      // Verify Dark Mode switch is present
      expect(find.text('Botanical Dark Mode'), findsOneWidget);
      expect(find.textContaining('Daylight porcelain'), findsOneWidget);

      // Ensure visible and tap dark mode toggle switch
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify theme toggled to dark mode
      expect(themeProvider.isDarkMode, isTrue);
      expect(find.textContaining('Night obsidian'), findsOneWidget);

      // Tap Milestones card to open AchievementsSheet modal
      await tester.ensureVisible(find.text('Gardener Milestones'));
      await tester.tap(find.text('Gardener Milestones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify AchievementsSheet opened
      expect(find.byType(AchievementsSheet), findsOneWidget);
      expect(find.text('First Sprout'), findsAtLeastNWidgets(1));
      expect(find.text('Cyber-Botanist'), findsAtLeastNWidgets(1));
    });
  });
}
