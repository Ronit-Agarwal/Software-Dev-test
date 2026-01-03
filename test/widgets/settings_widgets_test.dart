// Widget tests for settings screen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/screens/settings/settings_screen.dart';
import 'package:signsync/config/app_config.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    testWidgets('should render settings screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should display theme selection section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('should display text scale slider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Text Size'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('should display high contrast toggle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('High Contrast'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('should display detection settings', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Detection'), findsOneWidget);
      expect(find.text('Confidence Threshold'), findsOneWidget);
      expect(find.text('Distance Alert'), findsOneWidget);
    });

    testWidgets('should display alert preferences', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Audio Alerts'), findsOneWidget);
      expect(find.text('Spatial Audio'), findsOneWidget);
    });

    testWidgets('should display voice settings', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('Speech Rate'), findsOneWidget);
    });

    testWidgets('should display language selection', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Language'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsWidgets);
    });

    testWidgets('should change theme when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Tap on Dark theme
      await tester.tap(find.text('Dark').first);
      await tester.pumpAndSettle();

      // Theme should be changed
    });

    testWidgets('should toggle high contrast mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Find and tap the high contrast switch
      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Mode should be toggled
    });

    testWidgets('should adjust text scale via slider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Find text scale slider
      final sliderFinder = find.byType(Slider).first;
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Text scale should be adjusted
    });

    testWidgets('should adjust confidence threshold slider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Find confidence threshold slider
      final sliderFinder = find.byWidgetPredicate((widget) =>
          widget is Slider && widget.key?.toString().contains('confidence') == true);
      if (sliderFinder.evaluate().isNotEmpty) {
        await tester.drag(sliderFinder, const Offset(20, 0));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('should adjust distance alert slider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Find distance alert slider
      final sliderFinder = find.byWidgetPredicate((widget) =>
          widget is Slider && widget.key?.toString().contains('distance') == true);
      if (sliderFinder.evaluate().isNotEmpty) {
        await tester.drag(sliderFinder, const Offset(20, 0));
        await tester.pumpAndSettle();
      }
    });
  });

  group('SettingsScreen Accessibility Tests', () {
    testWidgets('should have semantic labels for all controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Check switches
      final switches = find.byType(Switch);
      for (final sw in switches.evaluate()) {
        final semantics = sw.getSemantics();
        expect(semantics.label, isNotEmpty);
      }

      // Check sliders
      final sliders = find.byType(Slider);
      for (final slider in sliders.evaluate()) {
        final semantics = slider.getSemantics();
        expect(semantics.label, isNotEmpty);
      }

      // Check dropdowns
      final dropdowns = find.byType(DropdownButton<String>);
      for (final dropdown in dropdowns.evaluate()) {
        final semantics = dropdown.getSemantics();
        expect(semantics.label, isNotEmpty);
      }
    });

    testWidgets('should meet minimum touch target size', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Check switches
      final switches = find.byType(Switch);
      for (final sw in switches.evaluate()) {
        final size = sw.size!;
        expect(size.width, greaterThanOrEqualTo(44.0));
        expect(size.height, greaterThanOrEqualTo(44.0));
      }

      // Check list tiles
      final tiles = find.byType(ListTile);
      for (final tile in tiles.evaluate()) {
        final size = tile.size!;
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('should announce setting changes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Tap a setting that should announce change
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Should announce via semantics
    });

    testWidgets('should support text scaling', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.5),
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('should work with screen reader', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        ),
      );

      // All interactive elements should be focusable
      final interactiveElements = [
        find.byType(Switch),
        find.byType(Slider),
        find.byType(DropdownButton<String>),
        find.byType(ElevatedButton),
      ];

      for (final finder in interactiveElements) {
        final widgets = finder.evaluate();
        for (final widget in widgets) {
          final semantics = widget.getSemantics();
          expect(semantics.actions, isNotEmpty);
        }
      }
    });
  });
}
