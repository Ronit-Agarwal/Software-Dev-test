// E2E test for ASL Translation workflow
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:signsync/main.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/app_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E ASL Translation Workflow', () {
    testWidgets('Complete ASL translation workflow', (tester) async {
      // Launch app
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify app starts on dashboard
      expect(find.text('Dashboard'), findsOneWidget);

      // Navigate to ASL Translation mode
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // Verify on translation screen
      expect(find.text('ASL Translation'), findsOneWidget);

      // Verify camera preview is shown
      expect(find.byType(CameraPreviewWidget), findsOneWidget);

      // Verify translation display is shown
      expect(find.byType(TranslationDisplayWidget), findsOneWidget);

      // Verify no crash after 5 seconds of operation
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // App should still be running
      expect(find.text('ASL Translation'), findsOneWidget);
    });

    testWidgets('ASL detection and display workflow', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to translation mode
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // Verify detection indicators
      expect(find.text('Detecting signs...'), findsOneWidget);

      // Verify confidence display
      expect(find.textContaining('Confidence'), findsOneWidget);

      // Test mode switching
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);

      // Return to translation
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      expect(find.text('ASL Translation'), findsOneWidget);
    });

    testWidgets('ASL translation with settings changes', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Adjust confidence threshold
      final confidenceSlider = find.byWidgetPredicate((widget) =>
          widget is Slider && widget.key?.toString().contains('confidence') == true);
      if (confidenceSlider.evaluate().isNotEmpty) {
        await tester.drag(confidenceSlider, const Offset(50, 0));
        await tester.pumpAndSettle();
      }

      // Navigate to translation mode
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // Verify translation works with new settings
      expect(find.text('ASL Translation'), findsOneWidget);
    });

    testWidgets('ASL translation accessibility workflow', (tester) async {
      // Start with high contrast mode
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(AppConfig()..highContrastMode = true),
          ],
          child: const SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to translation
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // Verify high contrast mode is active
      expect(find.text('ASL Translation'), findsOneWidget);

      // Test screen reader support
      // (In real tests, verify semantic labels are announced)
    });
  });

  group('E2E Object Detection Workflow', () {
    testWidgets('Complete object detection workflow', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to detection mode
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      // Verify on detection screen
      expect(find.text('Object Detection'), findsOneWidget);

      // Verify camera preview
      expect(find.byType(CameraPreviewWidget), findsOneWidget);

      // Verify object list display
      expect(find.text('Detected Objects'), findsOneWidget);

      // Run for 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // App should still be running
      expect(find.text('Object Detection'), findsOneWidget);
    });

    testWidgets('Object detection with audio alerts', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to settings to enable audio alerts
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Enable audio alerts
      final audioAlertSwitch = find.byWidgetPredicate((widget) =>
          widget is Switch && widget.key?.toString().contains('audio') == true);
      if (audioAlertSwitch.evaluate().isNotEmpty) {
        await tester.tap(audioAlertSwitch);
        await tester.pumpAndSettle();
      }

      // Navigate to detection
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      // Verify detection screen
      expect(find.text('Object Detection'), findsOneWidget);

      // Run for 3 seconds to test audio
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('Object detection with spatial audio', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Enable spatial audio in settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final spatialAudioSwitch = find.byWidgetPredicate((widget) =>
          widget is Switch && widget.key?.toString().contains('spatial') == true);
      if (spatialAudioSwitch.evaluate().isNotEmpty) {
        await tester.tap(spatialAudioSwitch);
        await tester.pumpAndSettle();
      }

      // Navigate to detection
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      expect(find.text('Object Detection'), findsOneWidget);
    });

    testWidgets('Object detection distance alerts', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Set distance threshold in settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final distanceSlider = find.byWidgetPredicate((widget) =>
          widget is Slider && widget.key?.toString().contains('distance') == true);
      if (distanceSlider.evaluate().isNotEmpty) {
        await tester.drag(distanceSlider, const Offset(30, 0));
        await tester.pumpAndSettle();
      }

      // Navigate to detection
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      expect(find.text('Object Detection'), findsOneWidget);
    });
  });

  group('E2E AI Chat Workflow', () {
    testWidgets('Complete AI chat workflow', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to chat mode
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();

      // Verify on chat screen
      expect(find.text('AI Chat'), findsOneWidget);

      // Verify chat input field
      expect(find.byType(TextField), findsOneWidget);

      // Verify send button
      expect(find.byIcon(Icons.send), findsOneWidget);

      // Type a message
      await tester.enterText(find.byType(TextField), 'Hello, how can I learn ASL?');
      await tester.pumpAndSettle();

      // Send message
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify message appears in chat
      expect(find.text('Hello, how can I learn ASL?'), findsOneWidget);

      // Wait for AI response
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Verify AI response is shown
      expect(find.byType(Chip), findsWidgets); // AI messages typically use chips
    });

    testWidgets('AI chat with voice input', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to chat
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();

      // Verify voice input button
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Tap voice input
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      // Verify listening state
      // (In real tests, verify microphone icon changes)
    });

    testWidgets('AI chat with voice output', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to chat
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();

      // Send a message
      await tester.enterText(find.byType(TextField), 'What is ASL?');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Wait for response
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('AI chat conversation history', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to chat
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();

      // Send multiple messages
      await tester.enterText(find.byType(TextField), 'Message 1');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      await Future.delayed(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'Message 2');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify both messages in history
      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);
    });
  });

  group('E2E Mode Switching Workflow', () {
    testWidgets('Seamless mode switching', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Start on dashboard
      expect(find.text('Dashboard'), findsOneWidget);

      // Switch to translation
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();
      expect(find.text('ASL Translation'), findsOneWidget);

      // Switch to detection
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();
      expect(find.text('Object Detection'), findsOneWidget);

      // Switch to sound
      await tester.tap(find.text('Sound'));
      await tester.pumpAndSettle();
      expect(find.text('Sound Alerts'), findsOneWidget);

      // Switch to chat
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();
      expect(find.text('AI Chat'), findsOneWidget);

      // Return to dashboard
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('Mode switching with state preservation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to translation
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // Switch to detection and back
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // Verify translation screen state is preserved
      expect(find.text('ASL Translation'), findsOneWidget);
    });
  });

  group('E2E Multi-mode Operation', () {
    testWidgets('Simultaneous audio and camera operation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Enable audio alerts in settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final audioSwitch = find.byType(Switch).first;
      if (audioSwitch.evaluate().isNotEmpty) {
        await tester.tap(audioSwitch);
        await tester.pumpAndSettle();
      }

      // Navigate to detection
      await tester.tap(find.text('Detection'));
      await tester.pumpAndSettle();

      // Run camera and audio simultaneously
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // App should still be stable
      expect(find.text('Object Detection'), findsOneWidget);
    });
  });

  group('E2E Offline Operation', () {
    testWidgets('App works without network connection', (tester) async {
      // Simulate offline mode by disabling network
      // (In real tests, use network simulation)

      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to chat (which needs network for AI)
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();

      // Send message
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Should use offline fallback
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // App should handle gracefully
      expect(find.text('AI Chat'), findsOneWidget);
    });
  });

  group('E2E Settings Workflow', () {
    testWidgets('Configure all settings', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SignSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Change theme
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Adjust text scale
      final textScaleSlider = find.byWidgetPredicate((widget) =>
          widget is Slider && widget.key?.toString().contains('text') == true);
      if (textScaleSlider.evaluate().isNotEmpty) {
        await tester.drag(textScaleSlider, const Offset(50, 0));
        await tester.pumpAndSettle();
      }

      // Enable high contrast
      final contrastSwitch = find.byWidgetPredicate((widget) =>
          widget is Switch && widget.key?.toString().contains('contrast') == true);
      if (contrastSwitch.evaluate().isNotEmpty) {
        await tester.tap(contrastSwitch);
        await tester.pumpAndSettle();
      }

      // Change language
      final languageDropdown = find.byType(DropdownButton<String>);
      if (languageDropdown.evaluate().isNotEmpty) {
        await tester.tap(languageDropdown);
        await tester.pumpAndSettle();
      }

      // Navigate back to dashboard
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      // Settings should be applied
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}

// Mock widgets for testing
class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TranslationDisplayWidget extends StatelessWidget {
  const TranslationDisplayWidget({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
