import 'package:signsync/models/detected_object.dart';
import 'package:signsync/services/tts_service.dart';

/// Examples demonstrating TTS service integration.
///
/// This file provides practical examples of using the TTS service
/// for audio alerts with object detection.

// Example 1: Basic TTS initialization and speech
Future<void> basicTtsExample() async {
  final ttsService = TtsService();

  try {
    // Initialize TTS service
    await ttsService.initialize();
    print('TTS initialized: ${ttsService.isInitialized}');

    // Speak simple text
    await ttsService.speak('Hello, this is a test message');
    print('Speaking: Hello, this is a test message');

    // Wait for speech to complete
    await Future.delayed(const Duration(seconds: 2));

    // Change settings
    await ttsService.setVolume(0.5);
    await ttsService.setSpeechRate(0.8);
    await ttsService.setPitch(1.2);

    // Speak with new settings
    await ttsService.speak('This is slower and quieter');

    // Cleanup
    await ttsService.dispose();
  } catch (e) {
    print('TTS error: $e');
  }
}

// Example 2: Generating alerts for single objects
Future<void> singleObjectAlertExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Create a detected object
  final person = DetectedObject.basic(
    label: 'person',
    confidence: 0.92,
    boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
    distance: 1.5,
  );

  // Generate alert
  await ttsService.generateAlert(person);
  // Output: "Person, 5 feet ahead" or "Person to your left, 5 feet ahead"

  print('Generated alert for: ${person.label}');
  print('Total alerts played: ${ttsService.totalAlertsPlayed}');

  await Future.delayed(const Duration(seconds: 3));
  await ttsService.dispose();
}

// Example 3: Generating alerts for multiple objects
Future<void> multipleObjectAlertsExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Create multiple detected objects
  final objects = [
    DetectedObject.basic(
      label: 'person',
      confidence: 0.92,
      boundingBox: const Rect.fromLTWH(100, 100, 80, 160),
      distance: 2.0,
    ),
    DetectedObject.basic(
      label: 'chair',
      confidence: 0.85,
      boundingBox: const Rect.fromLTWH(300, 200, 50, 100),
      distance: 1.0,
    ),
    DetectedObject.basic(
      label: 'car',
      confidence: 0.88,
      boundingBox: const Rect.fromLTWH(500, 150, 120, 200),
      distance: 5.0,
    ),
  ];

  // Generate alerts for all objects
  await ttsService.generateAlerts(objects);

  print('Generated alerts for ${objects.length} objects');
  print('Total alerts played: ${ttsService.totalAlertsPlayed}');
  print('Duplicate alerts filtered: ${ttsService.duplicateAlertsFiltered}');

  await Future.delayed(const Duration(seconds: 10));
  await ttsService.dispose();
}

// Example 4: Spatial audio demonstration
Future<void> spatialAudioExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Enable spatial audio
  ttsService.setSpatialAudioEnabled(true);
  print('Spatial audio enabled: ${ttsService.spatialAudioEnabled}');

  // Create objects at different positions
  final leftObject = DetectedObject.basic(
    label: 'person',
    confidence: 0.90,
    boundingBox: const Rect.fromLTWH(50, 100, 80, 160), // Left side
    distance: 2.0,
  );

  final centerObject = DetectedObject.basic(
    label: 'chair',
    confidence: 0.85,
    boundingBox: const Rect.fromLTWH(280, 200, 80, 160), // Center
    distance: 1.0,
  );

  final rightObject = DetectedObject.basic(
    label: 'car',
    confidence: 0.88,
    boundingBox: const Rect.fromLTWH(510, 150, 80, 160), // Right side
    distance: 5.0,
  );

  // Generate alerts with spatial direction
  await ttsService.generateAlert(leftObject);   // "Person to your left..."
  await Future.delayed(const Duration(seconds: 2));

  await ttsService.generateAlert(centerObject); // "Chair, ..."
  await Future.delayed(const Duration(seconds: 2));

  await ttsService.generateAlert(rightObject);  // "Car to your right..."

  print('Spatial audio alerts generated');

  await Future.delayed(const Duration(seconds: 6));
  await ttsService.dispose();
}

// Example 5: Priority system demonstration
Future<void> prioritySystemExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Create objects with different priorities
  final objects = [
    // Low priority
    DetectedObject.basic(
      label: 'bottle',
      confidence: 0.95,
      boundingBox: const Rect.fromLTWH(100, 100, 40, 80),
      distance: 1.0,
    ),
    // Critical priority
    DetectedObject.basic(
      label: 'person',
      confidence: 0.85,
      boundingBox: const Rect.fromLTWH(200, 100, 80, 160),
      distance: 2.0,
    ),
    // Medium priority
    DetectedObject.basic(
      label: 'chair',
      confidence: 0.90,
      boundingBox: const Rect.fromLTWH(300, 200, 80, 160),
      distance: 1.5,
    ),
    // High priority
    DetectedObject.basic(
      label: 'car',
      confidence: 0.80,
      boundingBox: const Rect.fromLTWH(400, 150, 100, 200),
      distance: 5.0,
    ),
  ];

  // Generate alerts - should be prioritized by priority level
  // 1. person (critical)
  // 2. car (high)
  // 3. chair (medium)
  // bottle (low) may be skipped if only 3 alerts per frame
  await ttsService.generateAlerts(objects);

  print('Priority-based alerts generated');
  print('Queue size: ${ttsService.queuedAlerts}');

  await Future.delayed(const Duration(seconds: 8));
  await ttsService.dispose();
}

// Example 6: Duplicate filtering demonstration
Future<void> duplicateFilteringExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Create the same object
  final person = DetectedObject.basic(
    label: 'person',
    confidence: 0.92,
    boundingBox: const Rect.fromLTWH(200, 100, 80, 160),
    distance: 2.0,
  );

  // Try to generate alert multiple times quickly
  print('First alert...');
  await ttsService.generateAlert(person);
  print('Total alerts: ${ttsService.totalAlertsPlayed}');

  await Future.delayed(const Duration(seconds: 1));

  print('Second alert (should be filtered)...');
  await ttsService.generateAlert(person);
  print('Total alerts: ${ttsService.totalAlertsPlayed}');
  print('Duplicates filtered: ${ttsService.duplicateAlertsFiltered}');

  await Future.delayed(const Duration(seconds: 1));

  print('Third alert (should be filtered)...');
  await ttsService.generateAlert(person);
  print('Total alerts: ${ttsService.totalAlertsPlayed}');
  print('Duplicates filtered: ${ttsService.duplicateFiltered}');

  // Wait for cooldown to expire
  await Future.delayed(const Duration(seconds: 6));

  print('Fourth alert (cooldown expired)...');
  await ttsService.generateAlert(person);
  print('Total alerts: ${ttsService.totalAlertsPlayed}');
  print('Duplicates filtered: ${ttsService.duplicateAlertsFiltered}');

  await Future.delayed(const Duration(seconds: 3));
  await ttsService.dispose();
}

// Example 7: Volume and speech rate control
Future<void> audioControlExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Test different volumes
  print('Volume: 1.0 (100%)');
  await ttsService.setVolume(1.0);
  await ttsService.speak('This is full volume');
  await Future.delayed(const Duration(seconds: 2));

  print('Volume: 0.5 (50%)');
  await ttsService.setVolume(0.5);
  await ttsService.speak('This is half volume');
  await Future.delayed(const Duration(seconds: 2));

  print('Volume: 0.2 (20%)');
  await ttsService.setVolume(0.2);
  await ttsService.speak('This is low volume');
  await Future.delayed(const Duration(seconds: 2));

  // Test different speech rates
  await ttsService.setVolume(0.8);

  print('Speech rate: 0.5 (slow)');
  await ttsService.setSpeechRate(0.5);
  await ttsService.speak('This is spoken slowly');
  await Future.delayed(const Duration(seconds: 2));

  print('Speech rate: 1.0 (normal)');
  await ttsService.setSpeechRate(1.0);
  await ttsService.speak('This is spoken at normal speed');
  await Future.delayed(const Duration(seconds: 2));

  print('Speech rate: 0.2 (fast)');
  await ttsService.setSpeechRate(0.2);
  await ttsService.speak('This is spoken quickly');
  await Future.delayed(const Duration(seconds: 2));

  // Test different pitches
  await ttsService.setSpeechRate(0.9);

  print('Pitch: 0.8 (low)');
  await ttsService.setPitch(0.8);
  await ttsService.speak('This is low pitch');
  await Future.delayed(const Duration(seconds: 2));

  print('Pitch: 1.0 (normal)');
  await ttsService.setPitch(1.0);
  await ttsService.speak('This is normal pitch');
  await Future.delayed(const Duration(seconds: 2));

  print('Pitch: 1.5 (high)');
  await ttsService.setPitch(1.5);
  await ttsService.speak('This is high pitch');
  await Future.delayed(const Duration(seconds: 2));

  await ttsService.dispose();
}

// Example 8: Error handling and fallbacks
Future<void> errorHandlingExample() async {
  final ttsService = TtsService();

  try {
    // Try to speak before initialization
    print('Attempting to speak before initialization...');
    await ttsService.speak('Hello');
  } catch (e) {
    print('Caught error: $e');
  }

  // Initialize
  await ttsService.initialize();

  try {
    // Speak empty text
    print('Attempting to speak empty text...');
    await ttsService.speak('');
  } catch (e) {
    print('Caught error: $e');
  }

  try {
    // Set invalid volume
    print('Attempting to set invalid volume...');
    await ttsService.setVolume(1.5);
  } catch (e) {
    print('Caught error: $e');
  }

  try {
    // Set invalid speech rate
    print('Attempting to set invalid speech rate...');
    await ttsService.setSpeechRate(-0.5);
  } catch (e) {
    print('Caught error: $e');
  }

  // Normal operation
  await ttsService.speak('Error handling test complete');

  await Future.delayed(const Duration(seconds: 2));
  await ttsService.dispose();
}

// Example 9: Statistics and monitoring
Future<void> statisticsExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Generate multiple alerts
  final objects = [
    DetectedObject.basic(
      label: 'person',
      confidence: 0.92,
      boundingBox: const Rect.fromLTWH(200, 100, 80, 160),
      distance: 2.0,
    ),
    DetectedObject.basic(
      label: 'chair',
      confidence: 0.85,
      boundingBox: const Rect.fromLTWH(300, 200, 80, 160),
      distance: 1.0,
    ),
  ];

  await ttsService.generateAlerts(objects);
  await Future.delayed(const Duration(seconds: 5));

  // Get and display statistics
  final stats = ttsService.statistics;
  print('\n=== TTS Statistics ===');
  print('Total alerts: ${stats['totalAlerts']}');
  print('Duplicates filtered: ${stats['duplicatesFiltered']}');
  print('Average speech duration: ${stats['averageSpeechDuration']}ms');
  print('Queue size: ${stats['queuedAlerts']}');
  print('Is speaking: ${stats['isSpeaking']}');
  print('Volume: ${stats['volume']}');
  print('Speech rate: ${stats['speechRate']}');
  print('Spatial audio enabled: ${stats['spatialAudioEnabled']}');
  print('Language: ${stats['language']}');
  print('======================\n');

  await ttsService.dispose();
}

// Example 10: Integration with ML Orchestrator
Future<void> orchestratorIntegrationExample() async {
  final ttsService = TtsService();
  await ttsService.initialize();

  // Simulate object detection results
  final detectedObjects = [
    DetectedObject.basic(
      label: 'person',
      confidence: 0.95,
      boundingBox: const Rect.fromLTWH(150, 100, 100, 200),
      distance: 1.8,
    ),
  ];

  // Generate alerts automatically
  await ttsService.generateAlerts(detectedObjects);

  print('Alerts generated for ${detectedObjects.length} objects');

  // Monitor statistics
  print('Total alerts played: ${ttsService.totalAlertsPlayed}');
  print('Average speech duration: ${ttsService.averageSpeechDuration.toStringAsFixed(2)}ms');

  await Future.delayed(const Duration(seconds: 5));
  await ttsService.dispose();
}

/// Main entry point for running examples
Future<void> main() async {
  print('=== TTS Integration Examples ===\n');

  print('Example 1: Basic TTS');
  await basicTtsExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 2: Single object alert');
  await singleObjectAlertExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 3: Multiple object alerts');
  await multipleObjectAlertsExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 4: Spatial audio');
  await spatialAudioExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 5: Priority system');
  await prioritySystemExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 6: Duplicate filtering');
  await duplicateFilteringExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 7: Audio control');
  await audioControlExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 8: Error handling');
  await errorHandlingExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 9: Statistics');
  await statisticsExample();
  await Future.delayed(const Duration(seconds: 2));

  print('\nExample 10: Orchestrator integration');
  await orchestratorIntegrationExample();

  print('\n=== All examples completed ===');
}
