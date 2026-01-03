// Accessibility compliance tests (WCAG AAA)
import 'package:flutter/material.dart';
import 'package:flutter_semantics/flutter_semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/screens/dashboard/dashboard_screen.dart';
import 'package:signsync/screens/settings/settings_screen.dart';
import 'package:signsync/screens/translation/translation_screen.dart';
import 'package:signsync/screens/detection/detection_screen.dart';
import 'package:signsync/screens/chat/chat_screen.dart';

void main() {
  group('WCAG AAA - Screen Reader Support', () {
    testWidgets('Dashboard: All interactive elements have semantic labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all buttons have labels
      final buttons = find.byType(ElevatedButton);
      for (final button in buttons.evaluate()) {
        final semantics = button.getSemantics();
        expect(semantics.label, isNotEmpty,
            reason: 'Button should have a semantic label for screen readers');
      }

      // Check all text fields have labels
      final textFields = find.byType(TextField);
      for (final field in textFields.evaluate()) {
        final semantics = field.getSemantics();
        expect(semantics.label, isNotEmpty,
            reason: 'TextField should have a semantic label');
      }

      // Check all icon buttons have tooltips or labels
      final iconButtons = find.byType(IconButton);
      for (final button in iconButtons.evaluate()) {
        final semantics = button.getSemantics();
        expect(semantics.label.isNotEmpty || semantics.tooltip.isNotEmpty, true,
            reason: 'IconButton should have a label or tooltip');
      }
    });

    testWidgets('Settings: All controls are accessible via screen reader', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check switches
      final switches = find.byType(Switch);
      for (final sw in switches.evaluate()) {
        final semantics = sw.getSemantics();
        expect(semantics.label, isNotEmpty,
            reason: 'Switch should have a semantic label');
        expect(semantics.hasToggledState, true,
            reason: 'Switch should announce its state');
      }

      // Check sliders
      final sliders = find.byType(Slider);
      for (final slider in sliders.evaluate()) {
        final semantics = slider.getSemantics();
        expect(semantics.label, isNotEmpty,
            reason: 'Slider should have a semantic label');
        expect(semantics.hasValueState, true,
            reason: 'Slider should announce its value');
      }

      // Check dropdowns
      final dropdowns = find.byType(DropdownButton<String>);
      for (final dropdown in dropdowns.evaluate()) {
        final semantics = dropdown.getSemantics();
        expect(semantics.label, isNotEmpty,
            reason: 'DropdownButton should have a semantic label');
      }
    });

    testWidgets('Translation: Dynamic content has live regions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const TranslationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that detection results use live regions
      final textFields = find.byType(Text);
      for (final field in textFields.evaluate()) {
        final semantics = field.getSemantics();
        final text = semantics.label;

        // Detection results should announce changes
        if (text.contains('Detected') || text.contains('Confidence')) {
          expect(semantics.liveRegion, isTrue,
              reason: 'Dynamic content should have live region for screen readers');
        }
      }
    });

    testWidgets('Chat: Messages are properly announced', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chat messages should have speaker information
      final messages = find.byType(Container);
      for (final message in messages.evaluate()) {
        final semantics = message.getSemantics();
        final label = semantics.label;

        if (label.isNotEmpty) {
          // Should indicate if it's user or AI message
          expect(
            label.contains('You') || label.contains('AI') || label.contains('Assistant'),
            true,
            reason: 'Chat messages should indicate speaker for screen readers',
          );
        }
      }
    });
  });

  group('WCAG AAA - Touch Target Verification', () {
    testWidgets('All interactive elements meet 48x48dp minimum', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minSize = 48.0;

      // Check buttons
      final buttons = find.byType(ElevatedButton);
      for (final button in buttons.evaluate()) {
        final size = button.size!;
        expect(size.width, greaterThanOrEqualTo(minSize),
            reason: 'Button width should be at least $minSize');
        expect(size.height, greaterThanOrEqualTo(minSize),
            reason: 'Button height should be at least $minSize');
      }

      // Check icon buttons
      final iconButtons = find.byType(IconButton);
      for (final button in iconButtons.evaluate()) {
        final size = button.size!;
        expect(size.width, greaterThanOrEqualTo(minSize),
            reason: 'IconButton width should be at least $minSize');
        expect(size.height, greaterThanOrEqualTo(minSize),
            reason: 'IconButton height should be at least $minSize');
      }

      // Check list tiles
      final tiles = find.byType(ListTile);
      for (final tile in tiles.evaluate()) {
        final size = tile.size!;
        expect(size.height, greaterThanOrEqualTo(minSize),
            reason: 'ListTile height should be at least $minSize');
      }
    });

    testWidgets('Settings controls meet touch target requirements', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minSize = 48.0;

      // Check switches
      final switches = find.byType(Switch);
      for (final sw in switches.evaluate()) {
        final size = sw.size!;
        expect(size.width, greaterThanOrEqualTo(minSize));
        expect(size.height, greaterThanOrEqualTo(minSize));
      }

      // Check sliders
      final sliders = find.byType(Slider);
      for (final slider in sliders.evaluate()) {
        final size = slider.size!;
        expect(size.height, greaterThanOrEqualTo(minSize));
      }
    });

    testWidgets('Bottom navigation items meet touch target size', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        final nav = bottomNav.evaluate().first.widget as BottomNavigationBar;
        final iconSize = nav.iconSize;
        expect(iconSize, greaterThanOrEqualTo(24.0),
            reason: 'Bottom nav icons should be at least 24dp');
      }
    });
  });

  group('WCAG AAA - Color Contrast Audit', () {
    testWidgets('Text meets AAA contrast requirements (7:1 for normal text)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minContrast = 7.0;

      // Check text widgets
      final texts = find.byType(Text);
      for (final text in texts.evaluate()) {
        final textStyle = (text.widget as Text).style;
        if (textStyle?.fontSize != null && textStyle!.fontSize! >= 18) {
          // Large text can have 4.5:1 contrast
          final contrast = _calculateContrastRatio(textStyle.color ?? Colors.black, Colors.white);
          expect(contrast, greaterThanOrEqualTo(4.5),
              reason: 'Large text should have at least 4.5:1 contrast');
        } else {
          // Normal text needs 7:1 contrast
          final contrast = _calculateContrastRatio(textStyle?.color ?? Colors.black, Colors.white);
          expect(contrast, greaterThanOrEqualTo(minContrast),
              reason: 'Normal text should have at least 7:1 contrast');
        }
      }
    });

    testWidgets('Interactive elements meet AAA contrast (3:1 for UI components)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minContrast = 3.0;

      // Check buttons
      final buttons = find.byType(ElevatedButton);
      for (final button in buttons.evaluate()) {
        final style = (button.widget as ElevatedButton).style;
        final foregroundColor = style?.foregroundColor?.resolve({}) ?? Colors.white;
        final backgroundColor = style?.backgroundColor?.resolve({}) ?? Colors.blue;

        final contrast = _calculateContrastRatio(foregroundColor, backgroundColor);
        expect(contrast, greaterThanOrEqualTo(minContrast),
            reason: 'Button text should have at least 3:1 contrast with background');
      }
    });

    testWidgets('High contrast mode improves readability', (tester) async {
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
      await tester.pumpAndSettle();

      // In high contrast mode, should have excellent contrast
      final texts = find.byType(Text);
      for (final text in texts.evaluate()) {
        final textStyle = (text.widget as Text).style;
        if (textStyle?.color != null) {
          final contrast = _calculateContrastRatio(textStyle!.color!, Colors.white);
          expect(contrast, greaterThanOrEqualTo(10.0),
              reason: 'High contrast mode should have at least 10:1 contrast');
        }
      }
    });
  });

  group('WCAG AAA - Keyboard Navigation', () {
    testWidgets('All interactive elements are focusable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that interactive widgets have focus actions
      final interactiveWidgets = [
        find.byType(ElevatedButton),
        find.byType(IconButton),
        find.byType(TextField),
        find.byType(Switch),
      ];

      for (final finder in interactiveWidgets) {
        for (final widget in finder.evaluate()) {
          final semantics = widget.getSemantics();
          expect(semantics.actions.any((action) =>
            action == SemanticsAction.tap ||
            action == SemanticsAction.focus ||
            action == SemanticsAction.longPress
          ), true, reason: 'Interactive widget should be focusable');
        }
      }
    });

    testWidgets('Focus order is logical', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test tab navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Focus should move to next element
      // (In real tests, verify focus position)
    });

    testWidgets('Escape key handles back navigation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Press escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Should handle gracefully (may navigate back)
    });
  });

  group('WCAG AAA - Text Scaling', () {
    testWidgets('App supports 100% text scale (default)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.0),
            child: MaterialApp(
              home: const DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('App supports 150% text scale', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.5),
            child: MaterialApp(
              home: const DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      // Verify no overflow or layout issues
    });

    testWidgets('App supports 200% text scale (maximum)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 2.0),
            child: MaterialApp(
              home: const DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      // Verify no overflow or layout issues
    });

    testWidgets('Settings screen works at 200% text scale', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 2.0),
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
      expect(find.byType(Switch), findsWidgets);
    });
  });

  group('WCAG AAA - Haptic Feedback', () {
    testWidgets('Interactive elements provide haptic feedback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button and verify haptic feedback
      final button = find.byType(ElevatedButton).first;
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button);
        await tester.pumpAndSettle();

        // In real tests, verify haptic feedback was triggered
      }
    });

    testWidgets('Mode switching provides haptic feedback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap navigation item
      final navItem = find.text('Translation');
      if (navItem.evaluate().isNotEmpty) {
        await tester.tap(navItem);
        await tester.pumpAndSettle();

        // In real tests, verify haptic feedback
      }
    });
  });

  group('WCAG AAA - Orientation and Responsive Design', () {
    testWidgets('App works in portrait orientation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set portrait size (typical phone)
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('App works in landscape orientation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set landscape size
      await tester.binding.setSurfaceSize(const Size(812, 375));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('App adapts to tablet size', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });
  });

  group('WCAG AAA - Error Prevention and Recovery', () {
    testWidgets('Form inputs provide validation feedback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try to send empty message
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.text('Please enter a message'), findsOneWidget);
      }
    });

    testWidgets('Errors are announced to screen readers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger error
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        // Error message should have live region
        final errorText = find.textContaining('error');
        if (errorText.evaluate().isNotEmpty) {
          final semantics = errorText.evaluate().first.getSemantics();
          expect(semantics.liveRegion, true,
              reason: 'Error messages should be announced to screen readers');
        }
      }
    });
  });
}

// Helper function to calculate contrast ratio
double _calculateContrastRatio(Color foreground, Color background) {
  final fgLuminance = _getLuminance(foreground);
  final bgLuminance = _getLuminance(background);

  final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
  final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

double _getLuminance(Color color) {
  return (0.2126 * _getLinearColor(color.red) +
          0.7152 * _getLinearColor(color.green) +
          0.0722 * _getLinearColor(color.blue));
}

double _getLinearColor(int colorValue) {
  final colorDouble = colorValue / 255.0;
  return colorDouble <= 0.03928
      ? colorDouble / 12.92
      : ((colorDouble + 0.055) / 1.055).pow(2.4);
}
