import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/camera_state.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/services/ml_inference_service.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/common/camera_preview.dart';

/// Detection screen for object detection.
///
/// This screen handles camera input and ML inference for detecting
/// objects in the camera feed.
class DetectionScreen extends ConsumerStatefulWidget {
  const DetectionScreen({super.key});

  @override
  ConsumerState<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends ConsumerState<DetectionScreen> {
  bool _isProcessing = false;
  DetectionFrame? _currentFrame;
  List<DetectedObject> _recentObjects = [];

  @override
  void initState() {
    super.initState();
    LoggerService.info('Detection screen initialized');
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggleDetection() async {
    setState(() => _isProcessing = !_isProcessing);

    if (_isProcessing) {
      await _startDetection();
    } else {
      _stopDetection();
    }
  }

  Future<void> _startDetection() async {
    LoggerService.info('Starting object detection');
    AnalyticsEvent.logObjectDetectionStarted();

    try {
      final cameraService = ref.read(cameraServiceProvider);

      // Initialize camera service if not already done
      if (!cameraService.isInitialized) {
        await cameraService.initialize();
      }

      // Start camera if not already running
      if (cameraService.state != CameraState.ready &&
          cameraService.state != CameraState.streaming) {
        await cameraService.startCamera();
      }

      final mlService = ref.read(mlInferenceServiceProvider);
      await mlService.switchMode(AppMode.detection);

      // Start streaming for ML inference
      if (cameraService.state != CameraState.streaming) {
        await cameraService.startStreaming(onFrame: _processFrame);
      }

      LoggerService.info('Object detection started');
    } catch (e, stack) {
      LoggerService.error('Failed to start detection', error: e, stack: stack);
      setState(() => _isProcessing = false);
      _showError('Failed to start detection: $e');
    }
  }

  void _stopDetection() {
    LoggerService.info('Stopping object detection');

    final cameraService = ref.read(cameraServiceProvider);
    cameraService.stopStreaming();

    setState(() => _isProcessing = false);
  }

  void _processFrame(CameraImage image) async {
    if (!_isProcessing) return;

    try {
      final mlService = ref.read(mlInferenceServiceProvider);
      final result = await mlService.processImage(image);

      if (result is InferenceResult && result.data is DetectionFrame) {
        final frame = result.data as DetectionFrame;
        setState(() {
          _currentFrame = frame;
          _recentObjects = frame.objects;
        });

        if (_recentObjects.isNotEmpty) {
          AnalyticsEvent.logObjectDetectionStopped(
            objectCount: _recentObjects.length,
          );

          unawaited(
            ref.read(audioAlertServiceProvider).handleDetectionFrame(
                  frame,
                  frameSize: Size(
                    image.width.toDouble(),
                    image.height.toDouble(),
                  ),
                ),
          );
        }
      }
    } catch (e) {
      LoggerService.debug('Frame processing error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraInitialized = ref.watch(cameraInitializedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () => ref.read(cameraServiceProvider).switchCamera(),
            tooltip: 'Switch Camera',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuSelection(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'confidence',
                child: Text('Confidence Threshold'),
              ),
              const PopupMenuItem(
                value: 'labels',
                child: Text('Show Labels'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview Area
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Camera Preview
                if (cameraInitialized)
                  const CameraPreviewWidget()
                else
                  _buildCameraPlaceholder(),

                // Detection Overlay
                if (_isProcessing && _recentObjects.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ObjectDetectionPainter(objects: _recentObjects),
                    ),
                  ),
              ],
            ),
          ),

          // Detection Info Panel
          Expanded(
            flex: 2,
            child: _buildDetectionInfoPanel(),
          ),

          // Control Buttons
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: AppColors.surfaceVariantLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility,
              size: AppConstants.iconSizeXl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Camera not initialized',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            ElevatedButton.icon(
              onPressed: _startDetection,
              icon: const Icon(Icons.camera),
              label: const Text('Enable Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionInfoPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detected Objects',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_currentFrame != null)
                Text(
                  '${_currentFrame!.objects.length} objects',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Expanded(
            child: _recentObjects.isEmpty
                ? Center(
                    child: Text(
                      _isProcessing
                          ? 'Looking for objects...'
                          : 'Press Start to begin detection',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentObjects.length,
                    itemBuilder: (context, index) {
                      final object = _recentObjects[index];
                      return _buildObjectTile(object);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectTile(DetectedObject object) {
    final confidencePercent = (object.confidence * 100).toStringAsFixed(1);
    final distanceMeters = object.distance?.toStringAsFixed(1) ?? '?.?';
    final distanceFeet = object.distance != null 
        ? (object.distance! * 3.28084).toStringAsFixed(1) 
        : '?.?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingXs),
            decoration: BoxDecoration(
              color: object.isHighConfidence
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              object.isHighConfidence ? Icons.check_circle : Icons.warning,
              color: object.isHighConfidence ? AppColors.success : AppColors.warning,
              size: AppConstants.iconSizeMd,
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${object.displayName} - $distanceMeters m ($distanceFeet ft)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$confidencePercent confidence',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: object.confidence,
              minHeight: 4,
              backgroundColor: AppColors.surfaceVariantLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                object.isHighConfidence ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FilledButton.icon(
            onPressed: _toggleDetection,
            icon: Icon(_isProcessing ? Icons.stop : Icons.play_arrow),
            label: Text(_isProcessing ? 'Stop' : 'Start'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.camera),
            onPressed: _captureImage,
            tooltip: 'Capture Image',
            iconSize: AppConstants.iconSizeLg,
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      final path = await cameraService.captureImage();
      LoggerService.info('Image captured: $path');
      _showSuccess('Image saved');
    } catch (e, stack) {
      LoggerService.error('Failed to capture image', error: e, stack: stack);
      _showError('Failed to capture image: $e');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'confidence':
        _showConfidenceDialog();
        break;
      case 'labels':
        // Toggle labels
        break;
    }
  }

  void _showConfidenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confidence Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set minimum confidence for detection'),
            Slider(
              value: 0.6,
              min: 0.3,
              max: 0.9,
              divisions: 6,
              label: '60%',
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing detection boxes on camera preview.
class ObjectDetectionPainter extends CustomPainter {
  final List<DetectedObject> objects;

  ObjectDetectionPainter({required this.objects});

  @override
  void paint(Canvas canvas, Size size) {
    for (final object in objects) {
      final rect = object.boundingBox;
      final paint = Paint()
        ..color = AppColors.detectionBox
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Draw bounding box
      canvas.drawRect(rect, paint);

      // Draw label background
      final distance = object.distance != null ? ' ${object.distance!.toStringAsFixed(1)}m' : '';
      final labelText = '${object.displayName} ${(object.confidence * 100).toStringAsFixed(0)}%$distance';
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          backgroundColor: AppColors.detectionBox,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 20,
        textPainter.width + 8,
        20,
      );
      final labelPaint = Paint()..color = AppColors.detectionBox;
      canvas.drawRect(labelRect, labelPaint);
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
