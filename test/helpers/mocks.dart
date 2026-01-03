// Mock classes and test helpers for testing
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/services/gemini_ai_service.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';
import 'package:signsync/services/yolo_detection_service.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/detected_object.dart';
import 'dart:ui';

// Mock CameraController
class MockCameraController extends Mock implements CameraController {}

// Mock CameraDescription
class MockCameraDescription extends Mock implements CameraDescription {
  MockCameraDescription({String? name, CameraLensDirection direction = CameraLensDirection.back}) {
    when(() => this.name).thenReturn(name ?? 'MockCamera');
    when(() => this.lensDirection).thenReturn(direction);
    when(() => this.sensorOrientation).thenReturn(0);
  }
}

// Mock CameraImage
class MockCameraImage extends Mock implements CameraImage {
  MockCameraImage({
    int width = 640,
    int height = 480,
  }) {
    when(() => this.width).thenReturn(width);
    when(() => this.height).thenReturn(height);
    when(() => this.formatGroup).thenReturn(ImageFormatGroup.yuv420);
  }
}

// Mock TtsService
class MockTtsService extends Mock implements TtsService {
  MockTtsService() {
    when(() => isInitialized).thenReturn(false);
    when(() => isSpeaking).thenReturn(false);
  }
}

// Mock CnnInferenceService
class MockCnnInferenceService extends Mock implements CnnInferenceService {
  MockCnnInferenceService() {
    when(() => isModelLoaded).thenReturn(true);
  }
}

// Mock LstmInferenceService
class MockLstmInferenceService extends Mock implements LstmInferenceService {
  MockLstmInferenceService() {
    when(() => isModelLoaded).thenReturn(true);
  }
}

// Mock YoloDetectionService
class MockYoloDetectionService extends Mock implements YoloDetectionService {
  MockYoloDetectionService() {
    when(() => isModelLoaded).thenReturn(true);
  }
}

// Mock GeminiAiService
class MockGeminiAiService extends Mock implements GeminiAiService {
  MockGeminiAiService() {
    when(() => isInitialized).thenReturn(false);
    when(() => isLoading).thenReturn(false);
  }
}

// Test data generators
class TestData {
  static List<CameraDescription> get mockCameras => [
        MockCameraDescription(name: 'Back Camera', direction: CameraLensDirection.back),
        MockCameraDescription(name: 'Front Camera', direction: CameraLensDirection.front),
      ];

  static CameraImage get mockCameraImage => MockCameraImage();

  static List<AslSign> get mockAslSigns => [
        AslSign.fromLetter('A', confidence: 0.95),
        AslSign.fromLetter('B', confidence: 0.92),
        AslSign.fromWord('hello', confidence: 0.88),
      ];

  static List<DetectedObject> get mockDetectedObjects => [
        DetectedObject.basic(
          label: 'person',
          confidence: 0.92,
          boundingBox: const Rect.fromLTWH(10, 10, 100, 200),
        ),
        DetectedObject.basic(
          label: 'cup',
          confidence: 0.85,
          boundingBox: const Rect.fromLTWH(150, 50, 50, 80),
        ),
      ];

  static List<String> get mockChatMessages => [
        'Hello, how can I help you?',
        'What is the sign for "thank you"?',
        'How does the object detection feature work?',
      ];
}

// Test configuration
class TestConfig {
  static const String testApiKey = 'test-api-key-12345';
  static const Duration testTimeout = Duration(seconds: 5);
  static const int maxRetries = 3;
  static const double defaultConfidence = 0.85;
}

// Helper functions
Future<void> pumpAndSettle(WidgetTester tester, {Duration? timeout}) async {
  await tester.pump();
  await tester.pumpAndSettle(timeout: timeout ?? TestConfig.testTimeout);
}

/// Registers all mock fallback values
void registerMockFallbacks() {
  registerFallbackValue(const CameraDescription(
    name: 'fallback',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 0,
  ));
  registerFallbackValue(MockCameraImage());
  registerFallbackValue(AslSign.fromLetter('A'));
  registerFallbackValue(DetectedObject.basic(
    label: 'test',
    confidence: 0.5,
    boundingBox: Rect.zero,
  ));
}
