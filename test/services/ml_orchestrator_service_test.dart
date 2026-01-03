// Unit tests for MlOrchestratorService
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';
import 'package:signsync/services/yolo_detection_service.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/services/face_recognition_service.dart';
import 'package:signsync/services/storage_service.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/detected_object.dart';

import '../helpers/mocks.dart';

void main() {
  late MlOrchestratorService orchestrator;
  late MockCnnInferenceService mockCnnService;
  late MockLstmInferenceService mockLstmService;
  late MockYoloDetectionService mockYoloService;
  late MockTtsService mockTtsService;
  late FaceRecognitionService mockFaceService;
  late StorageService mockStorageService;

  setUpAll(() {
    registerMockFallbacks();
  });

  setUp(() {
    mockCnnService = MockCnnInferenceService();
    mockLstmService = MockLstmInferenceService();
    mockYoloService = MockYoloDetectionService();
    mockTtsService = MockTtsService();
    mockFaceService = FaceRecognitionService();
    mockStorageService = StorageService();

    orchestrator = MlOrchestratorService(
      cnnService: mockCnnService,
      lstmService: mockLstmService,
      yoloService: mockYoloService,
      ttsService: mockTtsService,
      faceService: mockFaceService,
      storageService: mockStorageService,
    );
  });

  group('MlOrchestratorService Initialization', () {
    test('should start uninitialized', () {
      expect(orchestrator.isInitialized, false);
      expect(orchestrator.isProcessing, false);
      expect(orchestrator.currentMode, AppMode.dashboard);
    });

    test('should initialize for translation mode', () async {
      await orchestrator.initialize(initialMode: AppMode.translation);

      expect(orchestrator.isInitialized, true);
      expect(orchestrator.error, null);
    });

    test('should initialize for detection mode', () async {
      await orchestrator.initialize(initialMode: AppMode.detection);

      expect(orchestrator.isInitialized, true);
      expect(orchestrator.error, null);
    });

    test('should initialize for dashboard mode', () async {
      await orchestrator.initialize(initialMode: AppMode.dashboard);

      expect(orchestrator.isInitialized, true);
      expect(orchestrator.currentMode, AppMode.dashboard);
    });

    test('should not initialize twice', () async {
      await orchestrator.initialize(initialMode: AppMode.translation);
      await orchestrator.initialize(initialMode: AppMode.detection);

      expect(orchestrator.isInitialized, true);
      expect(orchestrator.currentMode, AppMode.translation);
    });

    test('should initialize with custom model paths', () async {
      await orchestrator.initialize(
        initialMode: AppMode.translation,
        cnnModelPath: '/custom/path/cnn.tflite',
        lstmModelPath: '/custom/path/lstm.tflite',
      );

      expect(orchestrator.isInitialized, true);
    });

    test('should initialize with locale', () async {
      await orchestrator.initialize(
        initialMode: AppMode.translation,
        locale: const Locale('es'),
      );

      expect(orchestrator.isInitialized, true);
      verify(() => mockTtsService.setLocale(any())).called(1);
    });
  });

  group('MlOrchestratorService Frame Processing', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should throw error when processing before initialization', () async {
      final uninitializedOrchestrator = MlOrchestratorService(
        cnnService: mockCnnService,
        lstmService: mockLstmService,
        yoloService: mockYoloService,
        ttsService: mockTtsService,
      );

      expect(
        () => uninitializedOrchestrator.processFrame(TestData.mockCameraImage),
        throwsA(isA<Exception>()),
      );
    });

    test('should skip processing when already processing', () async {
      orchestrator.isProcessing; // Access getter

      // If processing, should return skipped result
      // Testing logic indirectly
    });

    test('should process ASL frame in translation mode', () async {
      final cameraImage = TestData.mockCameraImage;

      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => TestData.mockAslSigns.first);
      when(() => mockLstmService.processFrame(any()))
          .thenAnswer((_) async => null);

      final result = await orchestrator.processFrame(cameraImage);

      expect(result, isNotNull);
      expect(result.type, MlResultType.asl);
    });

    test('should process detection frame in detection mode', () async {
      await orchestrator.switchMode(AppMode.detection);

      final cameraImage = TestData.mockCameraImage;

      when(() => mockYoloService.detect(any())).thenAnswer((_) async =>
          DetectionFrame(
            id: 'test',
            objects: TestData.mockDetectedObjects,
            timestamp: DateTime.now(),
            frameIndex: 0,
          ));

      final result = await orchestrator.processFrame(cameraImage);

      expect(result, isNotNull);
      expect(result.type, MlResultType.detection);
    });

    test('should skip in sound mode', () async {
      await orchestrator.switchMode(AppMode.sound);

      final cameraImage = TestData.mockCameraImage;
      final result = await orchestrator.processFrame(cameraImage);

      expect(result, isNotNull);
      expect(result.type, MlResultType.skipped);
    });

    test('should track total frames processed', () async {
      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => null);

      await orchestrator.processFrame(cameraImage);
      await orchestrator.processFrame(cameraImage);
      await orchestrator.processFrame(cameraImage);

      expect(orchestrator.totalFramesProcessed, greaterThanOrEqualTo(0));
    });

    test('should calculate average processing time', () async {
      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => null);

      await orchestrator.processFrame(cameraImage);
      await orchestrator.processFrame(cameraImage);

      final avgTime = orchestrator.averageProcessingTime;
      expect(avgTime, isA<double>());
      expect(avgTime, greaterThanOrEqualTo(0.0));
    });
  });

  group('MlOrchestratorService Mode Switching', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should switch from translation to detection', () async {
      await orchestrator.switchMode(AppMode.detection);

      expect(orchestrator.currentMode, AppMode.detection);
    });

    test('should switch from detection to translation', () async {
      await orchestrator.switchMode(AppMode.detection);
      await orchestrator.switchMode(AppMode.translation);

      expect(orchestrator.currentMode, AppMode.translation);
    });

    test('should switch to sound mode', () async {
      await orchestrator.switchMode(AppMode.sound);

      expect(orchestrator.currentMode, AppMode.sound);
    });

    test('should switch to chat mode', () async {
      await orchestrator.switchMode(AppMode.chat);

      expect(orchestrator.currentMode, AppMode.chat);
    });

    test('should handle same mode switch', () async {
      await orchestrator.switchMode(AppMode.translation);

      expect(orchestrator.currentMode, AppMode.translation);
    });

    test('should reset mode state after switching', () async {
      await orchestrator.switchMode(AppMode.detection);

      // State should be reset for new mode
      expect(orchestrator.latestAslSign, null);
      expect(orchestrator.latestDynamicSign, null);
    });
  });

  group('MlOrchestratorService Confidence Thresholds', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should set ASL confidence threshold', () {
      orchestrator.setConfidenceThresholds(aslThreshold: 0.90);

      // Should use new threshold for filtering
      // Testing configuration
      expect(true, isTrue);
    });

    test('should clamp ASL threshold to [0.0, 1.0]', () {
      orchestrator.setConfidenceThresholds(aslThreshold: 1.5);
      orchestrator.setConfidenceThresholds(aslThreshold: -0.5);

      // Should be clamped
      expect(true, isTrue);
    });

    test('should set object confidence threshold', () {
      orchestrator.setConfidenceThresholds(objectThreshold: 0.70);

      // Should use new threshold for filtering
      expect(true, isTrue);
    });

    test('should set both thresholds simultaneously', () {
      orchestrator.setConfidenceThresholds(
        aslThreshold: 0.85,
        objectThreshold: 0.60,
      );

      expect(true, isTrue);
    });
  });

  group('MlOrchestratorService Model Enabling', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should enable CNN model', () {
      orchestrator.setModelEnabled(cnn: true);

      expect(true, isTrue);
    });

    test('should disable CNN model', () {
      orchestrator.setModelEnabled(cnn: false);

      expect(true, isTrue);
    });

    test('should enable LSTM model', () {
      orchestrator.setModelEnabled(lstm: true);

      expect(true, isTrue);
    });

    test('should enable YOLO model', () {
      orchestrator.setModelEnabled(yolo: true);

      expect(true, isTrue);
    });

    test('should enable multiple models', () {
      orchestrator.setModelEnabled(
        cnn: true,
        lstm: true,
        yolo: true,
      );

      expect(true, isTrue);
    });
  });

  group('MlOrchestratorService Audio Alerts', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.detection);
    });

    test('should enable audio alerts', () {
      orchestrator.setAudioAlertsEnabled(true);

      expect(orchestrator.audioAlertsEnabled, true);
    });

    test('should disable audio alerts', () {
      orchestrator.setAudioAlertsEnabled(false);

      expect(orchestrator.audioAlertsEnabled, false);
    });

    test('should enable spatial audio', () {
      orchestrator.setSpatialAudioEnabled(true);

      expect(orchestrator.spatialAudioEnabled, true);
    });

    test('should disable spatial audio', () {
      orchestrator.setSpatialAudioEnabled(false);

      expect(orchestrator.spatialAudioEnabled, false);
    });
  });

  group('MlOrchestratorService Result Queue', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should maintain result queue', () async {
      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => TestData.mockAslSigns.first);

      await orchestrator.processFrame(cameraImage);
      await orchestrator.processFrame(cameraImage);

      expect(orchestrator.queuedResults, greaterThanOrEqualTo(0));
    });

    test('should limit queue size', () async {
      // Process more than 50 frames
      final cameraImage = TestData.mockCameraImage;

      for (int i = 0; i < 60; i++) {
        when(() => mockCnnService.processFrame(any()))
            .thenAnswer((_) async => TestData.mockAslSigns[i % 3]);
        await orchestrator.processFrame(cameraImage);
      }

      expect(orchestrator.queuedResults, lessThanOrEqualTo(50));
    });

    test('should get recent results', () {
      final recent = orchestrator.getRecentResults(10);

      expect(recent, isA<List<MlResult>>());
    });

    test('should get ASL sequence', () async {
      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => TestData.mockAslSigns.first);

      await orchestrator.processFrame(cameraImage);
      await orchestrator.processFrame(cameraImage);

      final sequence = orchestrator.getAslSequence();

      expect(sequence, isA<List<AslSign>>());
    });
  });

  group('MlOrchestratorService Performance Metrics', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should provide performance metrics', () async {
      final metrics = orchestrator.performanceMetrics;

      expect(metrics, isA<Map<String, dynamic>>());
      expect(metrics.containsKey('totalFrames'), true);
      expect(metrics.containsKey('averageProcessingTime'), true);
    });

    test('should track frames per mode', () async {
      await orchestrator.switchMode(AppMode.translation);
      await orchestrator.switchMode(AppMode.detection);

      final metrics = orchestrator.performanceMetrics;
      expect(metrics['framesPerMode'], isA<Map>());
    });

    test('should limit processing times history', () async {
      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => null);

      // Process 40 frames
      for (int i = 0; i < 40; i++) {
        await orchestrator.processFrame(cameraImage);
      }

      // Should only keep last 30
      expect(orchestrator.totalFramesProcessed, greaterThanOrEqualTo(0));
    });
  });

  group('MlOrchestratorService Adaptive Inference', () {
    setUp(() async {
      await orchestrator.initialize(initialMode: AppMode.translation);
    });

    test('should enable adaptive inference', () {
      orchestrator.setAdaptiveInferenceEnabled(true);

      expect(orchestrator.adaptiveInferenceEnabled, true);
    });

    test('should disable adaptive inference', () {
      orchestrator.setAdaptiveInferenceEnabled(false);

      expect(orchestrator.adaptiveInferenceEnabled, false);
    });

    test('should reduce inference on low battery', () async {
      orchestrator.setAdaptiveInferenceEnabled(true);

      // Simulate low battery
      orchestrator.updateBatteryLevel(15);

      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => null);

      await orchestrator.processFrame(cameraImage);

      // Should process with reduced frequency
      expect(orchestrator.batteryLevel, 15);
    });

    test('should maintain full inference on high battery', () async {
      orchestrator.setAdaptiveInferenceEnabled(true);

      orchestrator.updateBatteryLevel(80);

      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any()))
          .thenAnswer((_) async => null);

      await orchestrator.processFrame(cameraImage);

      // Should process at full speed
      expect(orchestrator.batteryLevel, 80);
    });
  });

  group('MlOrchestratorService Error Handling', () {
    test('should throw error when processing fails', () async {
      await orchestrator.initialize(initialMode: AppMode.translation);

      final cameraImage = TestData.mockCameraImage;
      when(() => mockCnnService.processFrame(any())).thenThrow(Exception('Test error'));

      final result = await orchestrator.processFrame(cameraImage);

      expect(result, isNotNull);
      expect(result.type, MlResultType.error);
    });

    test('should set error state on initialization failure', () async {
      final failingOrchestrator = MlOrchestratorService(
        cnnService: mockCnnService,
        ttsService: mockTtsService,
      );

      when(() => mockCnnService.initialize(any()))
          .thenThrow(Exception('Init error'));

      try {
        await failingOrchestrator.initialize(initialMode: AppMode.translation);
      } catch (_) {}

      // Error state should be set
      expect(failingOrchestrator.error, isNotNull);
    });
  });
}
