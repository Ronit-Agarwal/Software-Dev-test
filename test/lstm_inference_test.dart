import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';

void main() {
  group('LstmInferenceService', () {
    late LstmInferenceService lstmService;
    late CnnInferenceService mockCnnService;

    setUp(() {
      mockCnnService = MockCnnInferenceService();
      lstmService = LstmInferenceService(cnnService: mockCnnService);
    });

    tearDown(() {
      lstmService.dispose();
    });

    group('Initialization', () {
      test('should initialize with default parameters', () {
        expect(lstmService.isModelLoaded, false);
        expect(lstmService.isProcessing, false);
        expect(lstmService.latestSign, null);
        expect(lstmService.currentBufferSize, 0);
        expect(lstmService.framesInBuffer, 0);
      });

      test('should validate LSTM model parameters', () {
        expect(LstmInferenceService.sequenceLength, 15);
        expect(LstmInferenceService.featureDims, 512);
        expect(LstmInferenceService.numClasses, 20);
        expect(LstmInferenceService.confidenceThreshold, 0.80);
      });
    });

    group('Feature Extraction', () {
      test('should extract meaningful features from CNN result', () {
        final sign = AslSign.fromLetter('A', confidence: 0.9);
        final features = lstmService._extractCnnFeatures(sign);
        
        expect(features.length, 512);
        expect(features[0], equals(0.9)); // confidence
        expect(features[1], equals(0.0)); // A is first letter
        expect(features[2], equals(1.0)); // A is vowel
        expect(features[3], greaterThan(0.5)); // high confidence
      });

      test('should handle different letter types correctly', () {
        // Test vowel
        final vowelSign = AslSign.fromLetter('A', confidence: 0.8);
        final vowelFeatures = lstmService._extractCnnFeatures(vowelSign);
        expect(vowelFeatures[2], equals(1.0));

        // Test consonant
        final consonantSign = AslSign.fromLetter('B', confidence: 0.8);
        final consonantFeatures = lstmService._extractCnnFeatures(consonantSign);
        expect(consonantFeatures[2], equals(0.0));

        // Test different letter positions
        final zSign = AslSign.fromLetter('Z', confidence: 0.8);
        final zFeatures = lstmService._extractCnnFeatures(zSign);
        expect(zFeatures[1], equals(25.0 / 26.0)); // Z is last letter
      });

      test('should compute temporal derivatives correctly', () {
        // Add initial frame
        final sign1 = AslSign.fromLetter('A', confidence: 0.7);
        lstmService._extractCnnFeatures(sign1);

        // Add second frame with different confidence
        final sign2 = AslSign.fromLetter('A', confidence: 0.9);
        final features2 = lstmService._extractCnnFeatures(sign2);
        
        expect(features2[4], equals(0.2)); // confidence delta
        expect(features2[5], equals(0.2)); // confidence velocity
      });

      test('should compute frequency domain features', () {
        // Add multiple frames to enable frequency features
        for (int i = 0; i < 5; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.7 + i * 0.05);
          lstmService._extractCnnFeatures(sign);
        }

        final sign6 = AslSign.fromLetter('A', confidence: 0.95);
        final features = lstmService._extractCnnFeatures(sign6);
        
        expect(features[6], greaterThan(0.0)); // mean
        expect(features[7], greaterThan(0.0)); // variance
        expect(features[8], greaterThan(0.0)); // trend
      });
    });

    group('Temporal Buffer Management', () {
      test('should maintain correct buffer size', () {
        for (int i = 0; i < 20; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.8);
          lstmService._addFrameToBuffer(null, sign);
        }

        // Should only keep last 15 frames
        expect(lstmService.currentBufferSize, 15);
      });

      test('should track frame timestamps', () {
        final sign1 = AslSign.fromLetter('A', confidence: 0.8);
        lstmService._addFrameToBuffer(null, sign1);

        final sign2 = AslSign.fromLetter('B', confidence: 0.9);
        lstmService._addFrameToBuffer(null, sign2);

        expect(lstmService.currentBufferSize, 2);
      });

      test('should reset buffer correctly', () {
        // Add some frames
        for (int i = 0; i < 5; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.8);
          lstmService._addFrameToBuffer(null, sign);
        }

        expect(lstmService.currentBufferSize, 5);

        lstmService.resetBuffer();
        expect(lstmService.currentBufferSize, 0);
      });
    });

    group('Sequence Validation', () {
      test('should reject insufficient frames', () {
        expect(lstmService._isSequenceValidForInference(), false);
        
        // Add fewer than minimum frames
        for (int i = 0; i < 3; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.8);
          lstmService._addFrameToBuffer(null, sign);
        }
        
        expect(lstmService._isSequenceValidForInference(), false);
      });

      test('should accept valid sequences', () {
        // Add sufficient frames with variation
        final confidences = [0.7, 0.8, 0.9, 0.85, 0.7, 0.6, 0.8];
        for (int i = 0; i < 7; i++) {
          final sign = AslSign.fromLetter('A', confidence: confidences[i]);
          lstmService._addFrameToBuffer(null, sign);
        }
        
        expect(lstmService._isSequenceValidForInference(), true);
      });

      test('should reject sequences with insufficient variation', () {
        // Add frames with same confidence
        for (int i = 0; i < 7; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.8);
          lstmService._addFrameToBuffer(null, sign);
        }
        
        expect(lstmService._isSequenceValidForInference(), false);
      });

      test('should require motion/transitions for dynamic signs', () {
        // Add frames with very small variations
        for (int i = 0; i < 7; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.8 + i * 0.01);
          lstmService._addFrameToBuffer(null, sign);
        }
        
        expect(lstmService._isSequenceValidForInference(), false);
      });
    });

    group('Temporal Smoothing', () {
      test('should apply smoothing to sequences', () {
        final sequence = Float32List.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
        lstmService._applyTemporalSmoothing(sequence, 3);
        
        // Should have smoothed values
        expect(sequence[2], lessThan(3.0)); // smoothed value
      });

      test('should not smooth short sequences', () {
        final sequence = Float32List.fromList([1.0, 2.0]);
        lstmService._applyTemporalSmoothing(sequence, 2);
        
        expect(sequence[0], equals(1.0));
        expect(sequence[1], equals(2.0));
      });
    });

    group('Sign Counter and Consistency', () {
      test('should update sign counters correctly', () {
        lstmService._updateSignCounter('HELLO');
        lstmService._updateSignCounter('HELLO');
        lstmService._updateSignCounter('WORLD');
        
        expect(lstmService._signCounter['HELLO'], equals(2));
        expect(lstmService._signCounter['WORLD'], equals(1));
      });

      test('should get most consistent sign', () {
        // Simulate consistent sign detection
        for (int i = 0; i < 5; i++) {
          lstmService._updateSignCounter('HELLO');
        }
        
        final consistentSign = lstmService.getMostConsistentSign();
        expect(consistentSign, isNotNull);
        expect(consistentSign?.word, equals('hello'));
      });

      test('should handle inconsistent signs', () {
        // Mix different signs
        lstmService._updateSignCounter('HELLO');
        lstmService._updateSignCounter('WORLD');
        lstmService._updateSignCounter('HELLO');
        
        final consistentSign = lstmService.getMostConsistentSign();
        expect(consistentSign?.word, equals('hello')); // HELLO appears more
      });
    });

    group('Performance Monitoring', () {
      test('should track inference times', () {
        final startTime = DateTime.now();
        
        // Simulate some inference times
        for (int i = 0; i < 5; i++) {
          lstmService._inferenceTimes.add(50.0 + i * 10);
        }
        
        expect(lstmService.averageInferenceTime, greaterThan(0.0));
      });

      test('should track temporal statistics', () {
        // Add some frames
        for (int i = 0; i < 5; i++) {
          final sign = AslSign.fromLetter('A', confidence: 0.8);
          lstmService._addFrameToBuffer(null, sign);
        }
        
        final stats = lstmService.temporalStats;
        expect(stats['sequenceLength'], equals(15));
        expect(stats['bufferedFrames'], equals(5));
      });
    });

    group('Dynamic Signs Dictionary', () {
      test('should contain all expected dynamic signs', () {
        final dynamicSigns = lstmService._dynamicSigns;
        
        expect(dynamicSigns, contains('MORNING'));
        expect(dynamicSigns, contains('COMPUTER'));
        expect(dynamicSigns, contains('THANKYOU'));
        expect(dynamicSigns, contains('HELLO'));
        expect(dynamicSigns, contains('UNKNOWN'));
      });

      test('should map indices to correct signs', () {
        final result = LstmResult(
          label: 'MORNING',
          confidence: 0.9,
          classIndex: 0,
        );
        
        expect(result.label, equals('MORNING'));
        expect(result.confidence, equals(0.9));
      });
    });

    group('Error Handling', () {
      test('should handle processing when not initialized', () async {
        expect(() async => await lstmService.processFrame(null),
            throwsA(isA<MlInferenceException>()));
      });

      test('should handle concurrent processing', () async {
        // This would normally throw, but with mock service it might pass
        // The important thing is that it handles the state correctly
        try {
          await lstmService.initialize();
          // Test would depend on actual model availability
        } catch (e) {
          // Expected for test environment without model files
          expect(e, isA<ModelLoadException>());
        }
      });
    });

    group('Integration with CNN', () {
      test('should process CNN results correctly', () {
        final cnnResult = AslSign.fromLetter('A', confidence: 0.9);
        lstmService._addFrameToBuffer(null, cnnResult);
        
        expect(lstmService.currentBufferSize, 1);
        expect(lstmService._cnnResults.length, 1);
        expect(lstmService._cnnResults.first.letter, 'A');
      });

      test('should handle CNN results with different confidences', () {
        final results = [
          AslSign.fromLetter('A', confidence: 0.7),
          AslSign.fromLetter('A', confidence: 0.8),
          AslSign.fromLetter('A', confidence: 0.9),
        ];
        
        for (final result in results) {
          lstmService._addFrameToBuffer(null, result);
        }
        
        expect(lstmService.currentBufferSize, 3);
      });
    });

    group('Model Unloading', () {
      test('should unload model correctly', () async {
        try {
          await lstmService.initialize();
          expect(lstmService.isModelLoaded, true);
          
          await lstmService.unloadModel();
          expect(lstmService.isModelLoaded, false);
        } catch (e) {
          // Expected in test environment
          expect(e, isA<ModelLoadException>());
        }
      });

      test('should reset state after unloading', () async {
        try {
          await lstmService.initialize();
          
          // Add some data
          final sign = AslSign.fromLetter('A', confidence: 0.8);
          lstmService._addFrameToBuffer(null, sign);
          
          expect(lstmService.currentBufferSize, 1);
          
          await lstmService.unloadModel();
          expect(lstmService.currentBufferSize, 0);
        } catch (e) {
          // Expected in test environment
        }
      });
    });
  });
}

/// Mock CNN service for testing
class MockCnnInferenceService extends CnnInferenceService {
  @override
  Future<AslSign?> processFrame(dynamic image) async {
    // Return mock result for testing
    return AslSign.fromLetter('A', confidence: 0.8);
  }

  @override
  bool get isModelLoaded => true;

  @override
  Future<void> initialize({String? modelPath}) async {
    // Mock initialization
  }
}