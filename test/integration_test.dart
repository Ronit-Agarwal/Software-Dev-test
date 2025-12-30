// Integration test for the SignSync app
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/main.dart';
import 'package:signsync/config/app_config.dart';

void main() {
  group('App Initialization Tests', () {
    testWidgets('App creates without errors', (tester) async {
      // Build the app
      await tester.pumpWidget(
        ProviderScope(
          child: const SignSyncApp(),
        ),
      );

      // Verify app title is set
      expect(find.text('SignSync'), findsOneWidget);
    });

    testWidgets('AppConfig can be modified', (tester) async {
      final config = AppConfig();

      // Test theme mode changes
      expect(config.themeMode, ThemeMode.system);
      config.themeMode = ThemeMode.dark;
      expect(config.themeMode, ThemeMode.dark);

      // Test text scale changes
      expect(config.textScaleFactor, 1.0);
      config.textScaleFactor = 1.5;
      expect(config.textScaleFactor, 1.5);

      // Test high contrast mode
      expect(config.highContrastMode, false);
      config.highContrastMode = true;
      expect(config.highContrastMode, true);

      // Test reset
      config.resetToDefaults();
      expect(config.themeMode, ThemeMode.system);
      expect(config.textScaleFactor, 1.0);
      expect(config.highContrastMode, false);
    });

    testWidgets('ThemeMode has correct display names', (tester) {
      expect(ThemeMode.light.displayName, 'Light');
      expect(ThemeMode.dark.displayName, 'Dark');
      expect(ThemeMode.system.displayName, 'System');
    });
  });

  group('Accessibility Tests', () {
    testWidgets('Minimum touch target is met', (tester) async {
      // Verify the constant exists
      expect(AppConstants.minTouchTarget, 44.0);
      expect(AppConstants.recommendedTouchTarget, 48.0);
    });

    testWidgets('Text scale range is valid', (tester) async {
      expect(AppConstants.textScaleMin, lessThanOrEqualTo(0.8));
      expect(AppConstants.textScaleMax, greaterThanOrEqualTo(2.0));
    });
  });

  group('Navigation Tests', () {
    testWidgets('AppModes have correct routes', (tester) async {
      expect(AppMode.translation.routePath, '/translation');
      expect(AppMode.detection.routePath, '/detection');
      expect(AppMode.sound.routePath, '/sound');
      expect(AppMode.chat.routePath, '/chat');
    });

    testWidgets('AppModes have correct display names', (tester) async {
      expect(AppMode.translation.displayName, 'ASL Translation');
      expect(AppMode.detection.displayName, 'Object Detection');
      expect(AppMode.sound.displayName, 'Sound Alerts');
      expect(AppMode.chat.displayName, 'AI Chat');
    });
  });

  group('Supported Locales Tests', () {
    test('AppLocales has correct supported locales', () {
      expect(AppLocales.supported.length, greaterThan(0));
      expect(AppLocales.supported.map((l) => l.languageCode), contains('en'));
    });

    test('AppLocales.getDisplayName works correctly', () {
      expect(AppLocales.getDisplayName('en'), 'English');
      expect(AppLocales.getDisplayName('es'), 'Español');
      expect(AppLocales.getDisplayName('fr'), 'Français');
    });
  });
}

import 'package:flutter/material.dart';
