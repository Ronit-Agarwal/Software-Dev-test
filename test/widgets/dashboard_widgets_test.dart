// Widget tests for dashboard widgets
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/screens/dashboard/dashboard_screen.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/app_mode.dart';

void main() {
  group('DashboardScreen Widget Tests', () {
    testWidgets('should render dashboard screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('should display mode toggle widget', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Mode toggle widget should be present
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('should display performance stats', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Performance stats should be shown
      expect(find.byKey(const Key('performance-stats')), findsOneWidget);
    });

    testWidgets('should display health indicators', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Health indicators should be shown
      expect(find.text('Health'), findsOneWidget);
    });

    testWidgets('should display quick actions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      expect(find.text('Quick Actions'), findsOneWidget);
    });

    testWidgets('should display current mode info', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appModeProvider.overrideWithValue(AppMode.translation),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Should show info for current mode
      expect(find.text('ASL Translation'), findsOneWidget);
    });

    testWidgets('should have bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Bottom nav bar should be present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('should switch mode when tapping navigation item', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Tap on second nav item (Detection)
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      // Should navigate to detection screen
      // (This would require checking the router state)
    });
  });

  group('DashboardScreen Accessibility Tests', () {
    testWidgets('should have semantic labels for all interactive elements', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Check that buttons have semantic labels
      final buttons = find.byType(ElevatedButton);
      for (final button in buttons.evaluate()) {
        final semantics = button.getSemantics();
        expect(semantics.label, isNotEmpty);
      }
    });

    testWidgets('should meet minimum touch target size', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Check all touch targets
      final inkWells = find.byType(InkWell);
      for (final well in inkWells.evaluate()) {
        final size = well.size!;
        expect(size.width, greaterThanOrEqualTo(44.0));
        expect(size.height, greaterThanOrEqualTo(44.0));
      }
    });

    testWidgets('should support text scaling', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.5),
            child: const MaterialApp(
              home: DashboardScreen(),
            ),
          ),
        ),
      );

      // Should render without errors at 1.5x scale
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('should support 2x text scaling', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 2.0),
            child: const MaterialApp(
              home: DashboardScreen(),
            ),
          ),
        ),
      );

      // Should render without errors at 2.0x scale
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('should support high contrast mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.highContrastLight(),
            ),
            home: const DashboardScreen(),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('should announce changes via semantics', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Check that dynamic content has live regions
      final textFields = find.byType(Text);
      for (final field in textFields.evaluate()) {
        final semantics = field.getSemantics();
        if (semantics.label.contains('FPS') ||
            semantics.label.contains('Battery')) {
          expect(semantics.liveRegion, isTrue);
        }
      }
    });
  });

  group('DashboardScreen Performance Tests', () {
    testWidgets('should build in reasonable time', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    testWidgets('should not rebuild unnecessarily', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Pump again without changes
      final before = tester.binding.microtaskCount;
      await tester.pump();
      final after = tester.binding.microtaskCount;

      // Should not trigger rebuilds
      expect(after - before, lessThan(10));
    });
  });
}
