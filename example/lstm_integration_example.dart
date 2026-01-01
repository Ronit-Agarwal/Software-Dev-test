import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/app_mode.dart';

/// Example demonstrating LSTM integration for temporal ASL recognition.
///
/// This example shows:
/// 1. Combined CNN + LSTM pipeline
/// 2. Temporal sign sequence processing
/// 3. Real-time dynamic sign detection
/// 4. Integration with ML orchestrator
void main() {
  runApp(const LstmIntegrationExampleApp());
}

class LstmIntegrationExampleApp extends StatelessWidget {
  const LstmIntegrationExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LSTM ASL Recognition Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LstmExampleScreen(),
    );
  }
}

class LstmExampleScreen extends StatefulWidget {
  const LstmExampleScreen({super.key});

  @override
  State<LstmExampleScreen> createState() => _LstmExampleScreenState();
}

class _LstmExampleScreenState extends State<LstmExampleScreen> {
  late List<CameraDescription> _cameras;
  CameraController? _cameraController;
  final CnnInferenceService _cnnService = CnnInferenceService();
  final LstmInferenceService _lstmService = LstmInferenceService();
  final MlOrchestratorService _orchestrator = MlOrchestratorService();

  AslSign? _latestStaticSign;
  AslSign? _latestDynamicSign;
  String _status = 'Initializing...';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() => _status = 'Loading models...');

      // Initialize ML orchestrator with both CNN and LSTM
      await _orchestrator.initialize(
        initialMode: AppMode.translation,
        cnnModelPath: 'assets/models/asl_cnn.tflite',
        lstmModelPath: 'assets/models/asl_lstm.tflite',
      );

      setState(() => _status = 'Starting camera...');
      await _initializeCamera();

      setState(() {
        _status = 'Ready for ASL recognition';
        _isInitialized = true;
      });

      // Start processing frames
      _startFrameProcessing();
    } catch (e) {
      setState(() => _status = 'Initialization failed: $e');
    }
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(
      _cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
  }

  void _startFrameProcessing() {
    if (!_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((CameraImage image) {
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (!_isInitialized) return;

    try {
      // Method 1: Direct LSTM service usage
      final dynamicSign = await _lstmService.processFrame(image);
      if (dynamicSign != null) {
        setState(() => _latestDynamicSign = dynamicSign);
        _showSignDetection('Dynamic: ${dynamicSign.word}');
      }

      // Method 2: Through ML orchestrator (recommended)
      final mlResult = await _orchestrator.processFrame(image);
      if (mlResult.hasSign) {
        setState(() {
          _latestStaticSign = mlResult.staticSign;
          _latestDynamicSign = mlResult.dynamicSign;
        });
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
  }

  void _showSignDetection(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LSTM ASL Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeServices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            child: _cameraController?.value.isInitialized == true
                ? CameraPreview(_cameraController!)
                : const Center(child: CircularProgressIndicator()),
          ),

          // Status and results
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Static sign detection
                if (_latestStaticSign != null) ...[
                  _buildSignCard(
                    'Static Sign',
                    _latestStaticSign!.letter,
                    _latestStaticSign!.confidence,
                    Icons.touch_app,
                  ),
                  const SizedBox(height: 8),
                ],

                // Dynamic sign detection
                if (_latestDynamicSign != null) ...[
                  _buildSignCard(
                    'Dynamic Sign',
                    _latestDynamicSign!.word,
                    _latestDynamicSign!.confidence,
                    Icons.animation,
                  ),
                  const SizedBox(height: 8),
                ],

                // Performance metrics
                _buildPerformanceMetrics(),
                const SizedBox(height: 16),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _resetBuffers(),
                      child: const Text('Reset Buffers'),
                    ),
                    ElevatedButton(
                      onPressed: () => _showTemporalHistory(),
                      child: const Text('View History'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignCard(String title, String sign, double confidence, IconData icon) {
    final confidenceColor = confidence >= 0.8 ? Colors.green : 
                            confidence >= 0.6 ? Colors.orange : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    sign,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: confidenceColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: confidenceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Metrics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // LSTM metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('LSTM Buffer:'),
                Text('${_lstmService.currentBufferSize}/15'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('LSTM Inference Time:'),
                Text('${_lstmService.averageInferenceTime.toStringAsFixed(1)}ms'),
              ],
            ),

            // CNN metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CNN FPS:'),
                Text('${_orchestrator.performanceMetrics['cnnStats']?['currentFps']?.toStringAsFixed(1) ?? 'N/A'}'),
              ],
            ),

            // Orchestrator metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Frames:'),
                Text('${_orchestrator.totalFramesProcessed}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Processing Time:'),
                Text('${_orchestrator.averageProcessingTime.toStringAsFixed(1)}ms'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetBuffers() {
    _lstmService.resetBuffer();
    _orchestrator.resetModeState();
    
    setState(() {
      _latestStaticSign = null;
      _latestDynamicSign = null;
    });
    
    _showSignDetection('Buffers reset');
  }

  void _showTemporalHistory() {
    final dynamicSigns = _lstmService.getRecentDynamicSigns(10);
    final recentResults = _orchestrator.getRecentResults(5);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temporal History'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Recent Dynamic Signs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: dynamicSigns.isEmpty
                    ? const Text('No dynamic signs detected yet')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: dynamicSigns.length,
                        itemBuilder: (context, index) {
                          final sign = dynamicSigns[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.animation),
                            title: Text(sign.word),
                            trailing: Text(
                              '${(sign.confidence * 100).toStringAsFixed(1)}%',
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recent ML Results',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: recentResults.isEmpty
                    ? const Text('No results yet')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: recentResults.length,
                        itemBuilder: (context, index) {
                          final result = recentResults[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              result.isAsl ? Icons.touch_app :
                              result.isDetection ? Icons.visibility : 
                              result.isSkipped ? Icons.skip_next : Icons.error,
                            ),
                            title: Text(result.message ?? 'Unknown'),
                            subtitle: Text(result.type.toString()),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _cnnService.dispose();
    _lstmService.dispose();
    _orchestrator.dispose();
    super.dispose();
  }
}

/// Example: Standalone LSTM usage (without camera)
class StandaloneLstmExample {
  final LstmInferenceService _lstmService = LstmInferenceService();

  Future<void> demonstrateLstmUsage() async {
    try {
      // Initialize LSTM service
      await _lstmService.initialize(
        lstmModelPath: 'assets/models/asl_lstm.tflite',
        cnnModelPath: 'assets/models/asl_cnn.tflite',
      );

      // Simulate processing a sequence of frames
      await _simulateSignSequence('HELLO');
      await _simulateSignSequence('MORNING');
      await _simulateSignSequence('COMPUTER');

      // Get performance statistics
      final stats = _lstmService.temporalStats;
      print('LSTM Performance Stats: $stats');

      // Get recent dynamic signs
      final recentSigns = _lstmService.getRecentDynamicSigns(5);
      print('Recent Dynamic Signs: ${recentSigns.map((s) => s.word).toList()}');

    } catch (e) {
      print('LSTM example error: $e');
    }
  }

  Future<void> _simulateSignSequence(String signType) async {
    print('\\nSimulating $signType sign sequence...');

    // Simulate 15 frames of a dynamic sign
    for (int frame = 0; frame < 15; frame++) {
      // Simulate CNN detection with varying confidence
      final confidence = 0.7 + (frame < 5 ? frame * 0.05 : 0.25) - (frame > 10 ? (frame - 10) * 0.03 : 0);
      final letter = 'A'; // Static letter for demonstration
      
      // Create mock camera image (in real usage, this would be actual CameraImage)
      final mockImage = null;

      // Process frame through LSTM
      final detectedSign = await _lstmService.processFrame(mockImage);
      
      if (detectedSign != null) {
        print('Frame $frame: Detected dynamic sign: ${detectedSign.word} (${(detectedSign.confidence * 100).toStringAsFixed(1)}%)');
      } else {
        print('Frame $frame: No dynamic sign detected yet...');
      }

      // Simulate processing delay
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}

/// Example: Integration with existing camera service
class CameraLstmIntegrationExample {
  final CnnInferenceService _cnnService = CnnInferenceService();
  final LstmInferenceService _lstmService = LstmInferenceService();

  Future<void> processCameraStream(List<CameraImage> imageStream) async {
    // Initialize both services
    await _cnnService.initialize();
    await _lstmService.initialize();

    int frameCount = 0;
    
    for (final image in imageStream) {
      frameCount++;
      
      try {
        // Process through CNN first
        final cnnResult = await _cnnService.processFrame(image);
        
        if (cnnResult != null) {
          // Pass CNN result to LSTM for temporal analysis
          final lstmResult = await _lstmService.processFrame(image);
          
          if (lstmResult != null) {
            print('Frame $frameCount: Dynamic sign detected: ${lstmResult.word}');
          }
        }
      } catch (e) {
        print('Frame $frameCount processing error: $e');
      }
    }
    
    // Get final statistics
    print('\\nFinal LSTM Statistics:');
    print('Frames processed: ${_lstmService.temporalStats['totalFramesProcessed']}');
    print('Average inference time: ${_lstmService.averageInferenceTime.toStringAsFixed(2)}ms');
    print('Buffer utilization: ${_lstmService.currentBufferSize}/${LstmInferenceService.sequenceLength}');
  }
}