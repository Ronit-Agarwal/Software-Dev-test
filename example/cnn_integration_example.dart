import 'dart:io';
import 'package:signsync/services/cnn_inference_service.dart';

/// Example demonstrating ResNet-50 CNN integration for ASL sign recognition.
///
/// This example shows:
/// 1. Initializing the CNN service
/// 2. Processing camera frames
/// 3. Applying temporal smoothing
/// 4. Converting signs to phrases
/// 5. Monitoring performance metrics
void main() async {
  print('=== ResNet-50 CNN ASL Recognition Example ===\n');

  // Create CNN service instance
  final cnnService = CnnInferenceService();

  try {
    // Step 1: Initialize with lazy loading (recommended)
    print('1. Initializing CNN service with lazy loading...');
    await cnnService.initialize(
      modelPath: 'assets/models/asl_cnn.tflite',
      lazy: true, // Model loads on first inference
    );
    print('   ✓ Service initialized (model will load on first inference)\n');

    // Step 2: Check service state
    print('2. Checking service state...');
    print('   - Model loaded: ${cnnService.isModelLoaded}');
    print('   - Initializing: ${cnnService.isInitializing}');
    print('   - ASL dictionary size: ${cnnService.aslDictionary.length}');
    print('   - Confidence threshold: ${CnnInferenceService.confidenceThreshold}');
    print('   - Target FPS: ${CnnInferenceService.targetFpsMin}-${CnnInferenceService.targetFpsMax}');
    print('   - Max latency: ${CnnInferenceService.maxLatencyMs}ms\n');

    // Step 3: Process frames (in real app, use CameraImage)
    print('3. Simulating frame processing...');
    print('   Note: In real app, pass CameraImage from camera stream\n');

    // Simulated processing loop
    print('   Processing frames with:');
    print('   - YUV420→RGB conversion');
    print('   - 224x224 resize');
    print('   - ImageNet normalization');
    print('   - Temporal smoothing (3-5 frames)');
    print('   - Confidence filtering (≥0.85)\n');

    // Step 4: Performance monitoring
    print('4. Performance metrics during inference:');
    print('   - Average inference time: ${cnnService.averageInferenceTime.toStringAsFixed(2)}ms');
    print('   - Current FPS: ${cnnService.currentFps.toStringAsFixed(1)}');
    print('   - Frames processed: ${cnnService.framesProcessed}');
    print('   - Average confidence: ${(cnnService.averageConfidence * 100).toStringAsFixed(1)}%\n');

    // Step 5: Get recent signs for phrase building
    print('5. Recent signs detected (for phrase building):');
    final recentSigns = cnnService.getRecentSigns(5);
    print('   - Recent sign count: ${recentSigns.length}');

    if (recentSigns.isNotEmpty) {
      print('   - Letters: ${recentSigns.map((s) => s.letter).join(', ')}');

      // Convert to phrase
      final phrase = cnnService.convertToPhrase(recentSigns);
      if (phrase != null) {
        print('   - Phrase: "$phrase"');
      }
    } else {
      print('   - No signs detected yet (model needs to be loaded)');
    }
    print('');

    // Step 6: Performance stats
    print('6. Detailed performance statistics:');
    final stats = cnnService.performanceStats;
    stats.forEach((key, value) {
      print('   - $key: $value');
    });
    print('');

    // Step 7: Common phrase mappings
    print('7. Supported ASL phrase mappings:');
    print('   - HELLO → hello, hi, greeting');
    print('   - THANKYOU → thank you, thanks');
    print('   - ILOVEYOU → i love you');
    print('   - PLEASE → please');
    print('   - SORRY → sorry');
    print('   - MORNING → good morning, morning');
    print('   - NIGHT → good night, night');
    print('   - COMPUTER → computer, pc, laptop');
    print('   - PHONE → phone, call, telephone');
    print('   - HELP → help');
    print('');

    print('=== Integration Complete ===\n');

    // Usage tips
    print('📋 Usage Tips:');
    print('');
    print('1. Camera Integration:');
    print('   - Use CameraImage from camera package');
    print('   - Call cnnService.processFrame(image) for each frame');
    print('   - Returns null if confidence < 0.85');
    print('');
    print('2. Performance Optimization:');
    print('   - Lazy loading enabled by default');
    print('   - Preprocessing runs in isolate');
    print('   - Temporal smoothing reduces false positives');
    print('   - Auto-adapts to device performance');
    print('');
    print('3. Integration with LSTM:');
    print('   - Use recentSigns as input to LSTM');
    print('   - LSTM recognizes multi-sign sequences');
    print('   - See ml_orchestrator_service.dart for full pipeline');
    print('');
    print('4. Error Handling:');
    print('   - Check cnnService.error for issues');
    print('   - Graceful degradation on model load failure');
    print('   - Frame skipping when processing is busy');
    print('');
    print('5. Testing:');
    print('   - Run: flutter test test/cnn_inference_test.dart');
    print('   - Verify model loading and inference');
    print('   - Check performance metrics\n');

  } catch (e) {
    print('❌ Error: $e');
    print('\nMake sure to:');
    print('1. Place asl_cnn.tflite in assets/models/');
    print('2. Add assets/models/ to pubspec.yaml');
    print('3. Run flutter pub get');
  } finally {
    // Clean up
    cnnService.dispose();
    print('Service disposed.');
  }
}

/// Example of real-world integration with camera service.
///
/// This is pseudocode showing how to integrate CNN with the camera service:
///
/// ```dart
/// class TranslationScreen extends ConsumerStatefulWidget {
///   @override
///   ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
/// }
///
/// class _TranslationScreenState extends ConsumerState<TranslationScreen> {
///   late CnnInferenceService _cnnService;
///   AslSign? _currentSign;
///
///   @override
///   void initState() {
///     super.initState();
///     _cnnService = ref.read(cnnInferenceServiceProvider);
///     _initializeCNN();
///   }
///
///   Future<void> _initializeCNN() async {
///     try {
///       await _cnnService.initialize(lazy: true);
///     } catch (e) {
///       print('Failed to initialize CNN: $e');
///     }
///   }
///
///   void _onCameraFrame(CameraImage image) {
///     // Process frame with CNN
///     _cnnService.processFrame(image).then((sign) {
///       if (sign != null) {
///         setState(() {
///           _currentSign = sign;
///         });
///
///         // Update UI with recognized sign
///         print('Detected: ${sign.letter} (${(sign.confidence * 100).toStringAsFixed(1)}%)');
///       }
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: Column(
///         children: [
///           // Camera preview
///           CameraPreviewWidget(onFrame: _onCameraFrame),
///
///           // Display current sign
///           if (_currentSign != null)
///             Text(
///               'Detected: ${_currentSign!.letter}',
///               style: TextStyle(fontSize: 48),
///             ),
///
///           // Performance metrics
///           Text('FPS: ${_cnnService.currentFps.toStringAsFixed(1)}'),
///           Text('Latency: ${_cnnService.averageInferenceTime.toStringAsFixed(1)}ms'),
///         ],
///       ),
///     );
///   }
/// }
/// ```

/// Example of temporal smoothing behavior.
///
/// Temporal smoothing uses a 3-5 frame window to reduce jitter:
///
/// Frame 1: 'A' (0.92)
/// Frame 2: 'A' (0.95)
/// Frame 3: 'A' (0.91)
/// Frame 4: 'B' (0.88) ← Noise, smoothed out
/// Frame 5: 'A' (0.94)
///
/// Result: 'A' with averaged confidence 0.93
///
/// This prevents transient predictions from causing flickering output.
