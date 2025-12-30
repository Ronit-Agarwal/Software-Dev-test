import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/main.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/utils/constants.dart';

void main() {
  group('App Initialization Tests', () {
    testWidgets('App builds without errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    test('AppConfig can be modified', () {
      final config = AppConfig();

      expect(config.themeMode, ThemeMode.system);
      config.themeMode = ThemeMode.dark;
      expect(config.themeMode, ThemeMode.dark);

      expect(config.textScaleFactor, 1.0);
      config.textScaleFactor = 1.5;
      expect(config.textScaleFactor, 1.5);

      expect(config.highContrastMode, false);
      config.highContrastMode = true;
      expect(config.highContrastMode, true);

      config.resetToDefaults();
      expect(config.themeMode, ThemeMode.system);
      expect(config.textScaleFactor, 1.0);
      expect(config.highContrastMode, false);
    });

    test('ThemeMode has correct display names', () {
      expect(ThemeMode.light.displayName, 'Light');
      expect(ThemeMode.dark.displayName, 'Dark');
      expect(ThemeMode.system.displayName, 'System');
    });
  });

  group('Accessibility Tests', () {
    test('Minimum touch target is met', () {
      expect(AppConstants.minTouchTarget, 44.0);
      expect(AppConstants.recommendedTouchTarget, 48.0);
    });

    test('Text scale range is valid', () {
      expect(AppConstants.textScaleMin, lessThanOrEqualTo(0.8));
      expect(AppConstants.textScaleMax, greaterThanOrEqualTo(2.0));
    });
  });

  group('Navigation Tests', () {
    test('AppModes have correct routes', () {
      expect(AppMode.translation.routePath, '/translation');
      expect(AppMode.detection.routePath, '/detection');
      expect(AppMode.sound.routePath, '/sound');
      expect(AppMode.chat.routePath, '/chat');
    });

    test('AppModes have correct display names', () {
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
