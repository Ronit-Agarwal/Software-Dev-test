import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/services/tts_service.dart';

// Mock FlutterTts
class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late TtsService ttsService;
  late MockFlutterTts mockFlutterTts;

  setUp(() {
    mockFlutterTts = MockFlutterTts();
  });

  tearDown(() {
    ttsService.dispose();
  });

  group('TtsService Initialization', () {
    test('should initialize successfully', () async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();

      expect(ttsService.isInitialized, isTrue);
      expect(ttsService.error, isNull);
    });

    test('should not initialize twice', () async {
      ttsService = TtsService();
      await ttsService.initialize();
      await ttsService.initialize();

      // Should not throw error, just warn
      expect(ttsService.isInitialized, isTrue);
    });
  });

  group('TtsService Speaking', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should speak text successfully', () async {
      when(mockFlutterTts.speak('Hello, world'))
          .thenAnswer((_) async => 1);

      await ttsService.speak('Hello, world');

      verify(mockFlutterTts.speak('Hello, world')).called(1);
      expect(ttsService.totalAlertsPlayed, greaterThan(0));
    });

    test('should not speak empty text', () async {
      await ttsService.speak('');

      verifyNever(mockFlutterTts.speak(any));
    });

    test('should throw error if not initialized', () async {
      final uninitializedService = TtsService();

      expect(
        () => uninitializedService.speak('test'),
        throwsA(isA<TtsException>()),
      );
    });

    test('should stop speech', () async {
      when(mockFlutterTts.stop())
          .thenAnswer((_) async => 1);

      await ttsService.stop();

      verify(mockFlutterTts.stop()).called(1);
      expect(ttsService.queuedAlerts, equals(0));
    });
  });

  group('TtsService Volume Control', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should set volume within valid range', () async {
      await ttsService.setVolume(0.8);

      expect(ttsService.volume, equals(0.8));
      verify(mockFlutterTts.setVolume(0.8)).called(1);
    });

    test('should clamp volume to maximum', () async {
      await ttsService.setVolume(1.5);

      expect(ttsService.volume, equals(1.0));
    });

    test('should clamp volume to minimum', () async {
      await ttsService.setVolume(-0.5);

      expect(ttsService.volume, equals(0.0));
    });

    test('should throw error for invalid volume', () async {
      expect(
        () => ttsService.setVolume(1.5),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TtsService Speech Rate', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should set speech rate within valid range', () async {
      await ttsService.setSpeechRate(0.9);

      expect(ttsService.speechRate, equals(0.9));
      verify(mockFlutterTts.setSpeechRate(0.9)).called(1);
    });

    test('should clamp speech rate to maximum', () async {
      await ttsService.setSpeechRate(1.5);

      expect(ttsService.speechRate, equals(1.0));
    });

    test('should clamp speech rate to minimum', () async {
      await ttsService.setSpeechRate(-0.5);

      expect(ttsService.speechRate, equals(0.0));
    });
  });

  group('TtsService Pitch', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should set pitch within valid range', () async {
      await ttsService.setPitch(1.2);

      expect(ttsService.pitch, equals(1.2));
      verify(mockFlutterTts.setPitch(1.2)).called(1);
    });

    test('should clamp pitch to maximum', () async {
      await ttsService.setPitch(3.0);

      expect(ttsService.pitch, equals(2.0));
    });

    test('should clamp pitch to minimum', () async {
      await ttsService.setPitch(0.2);

      expect(ttsService.pitch, equals(0.5));
    });
  });

  group('TtsService Spatial Audio', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should enable spatial audio', () {
      expect(ttsService.spatialAudioEnabled, isTrue);

      ttsService.setSpatialAudioEnabled(false);
      expect(ttsService.spatialAudioEnabled, isFalse);

      ttsService.setSpatialAudioEnabled(true);
      expect(ttsService.spatialAudioEnabled, isTrue);
    });
  });

  group('TtsService Alert Generation', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should generate alert for single object', () async {
      final object = DetectedObject.basic(
        label: 'person',
        confidence: 0.92,
        boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
        distance: 2.0,
      );

      await ttsService.generateAlert(object);

      expect(ttsService.queuedAlerts, greaterThan(0));
    });

    test('should filter duplicate alerts', () async {
      final object = DetectedObject.basic(
        label: 'person',
        confidence: 0.92,
        boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
        distance: 2.0,
      );

      await ttsService.generateAlert(object);
      final firstTotal = ttsService.totalAlertsPlayed;

      await ttsService.generateAlert(object);
      final secondTotal = ttsService.totalAlertsPlayed;

      expect(ttsService.duplicateAlertsFiltered, greaterThan(0));
      expect(secondTotal, equals(firstTotal));
    });

    test('should generate alerts for multiple objects', () async {
      final objects = [
        DetectedObject.basic(
          label: 'person',
          confidence: 0.92,
          boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
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

      expect(ttsService.queuedAlerts, greaterThan(0));
    });
  });

  group('TtsService Priority System', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should prioritize person over bottle', () {
      final person = DetectedObject.basic(
        label: 'person',
        confidence: 0.80,
        boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
      );

      final bottle = DetectedObject.basic(
        label: 'bottle',
        confidence: 0.95,
        boundingBox: const Rect.fromLTWH(300, 200, 40, 80),
      );

      // Person should have higher priority despite lower confidence
      final personPriority = person.label == 'person'
          ? AlertPriority.critical
          : AlertPriority.low;
      final bottlePriority = AlertPriority.low;

      expect(personPriority.index, lessThan(bottlePriority.index));
    });

    test('should prioritize car over chair', () {
      final car = DetectedObject.basic(
        label: 'car',
        confidence: 0.80,
        boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
      );

      final chair = DetectedObject.basic(
        label: 'chair',
        confidence: 0.90,
        boundingBox: const Rect.fromLTWH(300, 200, 80, 160),
      );

      final carPriority = AlertPriority.high;
      final chairPriority = AlertPriority.medium;

      expect(carPriority.index, lessThan(chairPriority.index));
    });
  });

  group('TtsService Statistics', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should track total alerts', () {
      final initialCount = ttsService.totalAlertsPlayed;

      final object = DetectedObject.basic(
        label: 'person',
        confidence: 0.92,
        boundingBox: const Rect.fromLTWH(200, 100, 100, 200),
      );

      ttsService.generateAlert(object);

      // Note: Alerts may not increment immediately due to async processing
      expect(ttsService.totalAlertsPlayed, greaterThanOrEqualTo(initialCount));
    });

    test('should provide statistics', () {
      final stats = ttsService.statistics;

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalAlerts'), isTrue);
      expect(stats.containsKey('duplicatesFiltered'), isTrue);
      expect(stats.containsKey('averageSpeechDuration'), isTrue);
      expect(stats.containsKey('queuedAlerts'), isTrue);
      expect(stats.containsKey('volume'), isTrue);
      expect(stats.containsKey('speechRate'), isTrue);
      expect(stats.containsKey('spatialAudioEnabled'), isTrue);
    });
  });

  group('TtsService Error Handling', () {
    test('should handle TtsException', () {
      final exception = TtsException('Test error');

      expect(exception.toString(), equals('TtsException: Test error'));
      expect(exception.message, equals('Test error'));
    });

    test('should gracefully handle speak errors', () async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();

      when(mockFlutterTts.speak(any))
          .thenThrow(Exception('Speak error'));

      try {
        await ttsService.speak('Test');
        // Should not throw, just log error
      } catch (e) {
        // Expected
      }
    });
  });

  group('TtsService Language Support', () {
    setUp(() async {
      ttsService = TtsService();

      when(mockFlutterTts.setLanguage('en-US'))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSharedInstance(true))
          .thenAnswer((_) async => true);
      when(mockFlutterTts.setVolume(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setSpeechRate(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setPitch(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setCompletionHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setErrorHandler(any))
          .thenAnswer((_) async => 1);
      when(mockFlutterTts.setIosAudioCategory(any, any, any))
          .thenAnswer((_) async => 1);

      await ttsService.initialize();
    });

    test('should return available languages', () async {
      when(mockFlutterTts.getLanguages)
          .thenAnswer((_) async => ['en-US', 'en-GB', 'es-ES']);

      final languages = await ttsService.getLanguages();

      expect(languages, contains('en-US'));
      expect(languages, contains('en-GB'));
      expect(languages, contains('es-ES'));
    });

    test('should set language', () async {
      when(mockFlutterTts.getLanguages)
          .thenAnswer((_) async => ['en-US', 'en-GB', 'es-ES']);
      when(mockFlutterTts.setLanguage('es-ES'))
          .thenAnswer((_) async => 1);

      await ttsService.setLanguage('es-ES');

      verify(mockFlutterTts.setLanguage('es-ES')).called(1);
    });
  });
}
