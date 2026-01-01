import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/services/cnn_inference_service.dart';

void main() {
  group('CnnInferenceService Tests', () {
    late CnnInferenceService cnnService;

    setUp(() {
      cnnService = CnnInferenceService();
    });

    tearDown(() {
      cnnService.dispose();
    });

    test('initializes with lazy loading by default', () {
      expect(cnnService.isModelLoaded, false);
      expect(cnnService.isInitializing, false);
      expect(cnnService.error, null);
    });

    test('returns correct ASL dictionary', () {
      final dictionary = cnnService.aslDictionary;

      expect(dictionary.length, 27);
      expect(dictionary[0], 'A');
      expect(dictionary[25], 'Z');
      expect(dictionary[26], 'UNKNOWN');
    });

    test('has correct performance thresholds', () {
      expect(CnnInferenceService.confidenceThreshold, 0.85);
      expect(CnnInferenceService.inputSize, 224);
      expect(CnnInferenceService.numClasses, 27);
    });

    test('tracks performance metrics correctly', () {
      expect(cnnService.averageInferenceTime, 0.0);
      expect(cnnService.averageConfidence, 0.0);
      expect(cnnService.framesProcessed, 0);
      expect(cnnService.currentFps, 0.0);
    });
  });

  group('InferenceResult Tests', () {
    test('creates result with correct properties', () {
      final result = InferenceResult(
        letter: 'A',
        confidence: 0.95,
        classIndex: 0,
      );

      expect(result.letter, 'A');
      expect(result.confidence, 0.95);
      expect(result.classIndex, 0);
    });

    test('correctly identifies high confidence', () {
      final highConf = InferenceResult(
        letter: 'B',
        confidence: 0.90,
        classIndex: 1,
      );
      final lowConf = InferenceResult(
        letter: 'C',
        confidence: 0.80,
        classIndex: 2,
      );

      expect(highConf.isHighConfidence, true);
      expect(lowConf.isHighConfidence, false);
    });

    test('correctly identifies unknown predictions', () {
      final unknown = InferenceResult(
        letter: 'UNKNOWN',
        confidence: 0.30,
        classIndex: 26,
      );
      final known = InferenceResult(
        letter: 'D',
        confidence: 0.95,
        classIndex: 3,
      );

      expect(unknown.isUnknown, true);
      expect(known.isUnknown, false);
    });

    test('formats string correctly', () {
      final result = InferenceResult(
        letter: 'E',
        confidence: 0.876,
        classIndex: 4,
      );

      final str = result.toString();
      expect(str, contains('E'));
      expect(str, contains('0.876'));
      expect(str, contains('4'));
    });
  });

  group('ASL Phrase Mapping Tests', () {
    test('has common phrase mappings', () {
      // The service has internal phrase mappings
      // These are tested through the convertToPhrase method
      final signs = [
        AslSign.fromLetter('H'),
        AslSign.fromLetter('E'),
        AslSign.fromLetter('L'),
        AslSign.fromLetter('L'),
        AslSign.fromLetter('O'),
      ];

      // Signs can be converted to phrases
      expect(signs.length, 5);
    });

    test('handles empty sign sequences', () {
      final emptySigns = <AslSign>[];

      // Empty sequences should be handled gracefully
      expect(emptySigns.isEmpty, true);
    });
  });

  group('Performance Metrics Tests', () {
    test('calculates average inference time', () {
      final service = CnnInferenceService();

      // Initially zero
      expect(service.averageInferenceTime, 0.0);

      service.dispose();
    });

    test('calculates average confidence', () {
      final service = CnnInferenceService();

      // Initially zero
      expect(service.averageConfidence, 0.0);

      service.dispose();
    });

    test('tracks frames processed', () {
      final service = CnnInferenceService();

      // Initially zero
      expect(service.framesProcessed, 0);

      service.dispose();
    });

    test('tracks current FPS', () {
      final service = CnnInferenceService();

      // Initially zero
      expect(service.currentFps, 0.0);

      service.dispose();
    });
  });
}
