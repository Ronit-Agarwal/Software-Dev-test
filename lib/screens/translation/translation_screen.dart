import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/camera_state.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/common/camera_preview.dart';
import 'package:signsync/widgets/common/translation_display.dart';

/// Translation screen for ASL sign detection.
///
/// This screen handles camera input, ML inference for ASL signs,
/// and displays the translation results.
class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = false;
  AslSign? _currentSign;
  final List<AslSign> _signHistory = [];
  final TextEditingController _manualInputController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkPermissions();
    LoggerService.info('Translation screen initialized');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final permissionsService = ref.read(permissionsServiceProvider);
    await permissionsService.requestCameraPermission();
  }

  Future<void> _toggleTranslation() async {
    setState(() => _isProcessing = !_isProcessing);

    if (_isProcessing) {
      await _startTranslation();
    } else {
      _stopTranslation();
    }
  }

  Future<void> _startTranslation() async {
    LoggerService.info('Starting ASL translation');
    AnalyticsEvent.logTranslationStarted();

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

      // Start streaming for ML inference
      if (cameraService.state != CameraState.streaming) {
        await cameraService.startStreaming(onFrame: _processFrame);
      }

      LoggerService.info('ASL translation started');
    } catch (e, stack) {
      LoggerService.error('Failed to start translation', error: e, stack: stack);
      setState(() => _isProcessing = false);
      _showError('Failed to start camera: $e');
    }
  }

  void _stopTranslation() {
    LoggerService.info('Stopping ASL translation');
    AnalyticsEvent.logTranslationStopped(
      durationMs: DateTime.now().millisecondsSinceEpoch,
    );

    final cameraService = ref.read(cameraServiceProvider);
    cameraService.stopStreaming();
    setState(() => _isProcessing = false);
  }

  void _processFrame(dynamic image) async {
    if (!_isProcessing) return;

    try {
      final mlService = ref.read(mlInferenceServiceProvider);
      final result = await mlService.processImage(image);

      if (result is InferenceResult && result.data is AslSign) {
        final sign = result.data as AslSign;
        if (sign.confidence >= 0.6) {
          setState(() {
            _currentSign = sign;
            _signHistory.insert(0, sign);
            if (_signHistory.length > AppConstants.maxSignHistory) {
              _signHistory.removeLast();
            }
          });
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
        title: const Text('ASL Translation'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () => ref.read(cameraServiceProvider).switchCamera(),
            tooltip: 'Switch Camera',
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showManualInputDialog(),
            tooltip: 'Manual Input',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistoryBottomSheet(),
            tooltip: 'History',
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
                if (_isProcessing)
                  _buildDetectionOverlay(),

                // Processing Indicator
                if (_isProcessing)
                  _buildProcessingIndicator(),
              ],
            ),
          ),

          // Translation Display
          Expanded(
            flex: 2,
            child: TranslationDisplayWidget(
              currentSign: _currentSign,
              signHistory: _signHistory,
            ),
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
              Icons.camera_alt,
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
              onPressed: _checkPermissions,
              icon: const Icon(Icons.camera),
              label: const Text('Enable Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _currentSign != null
                  ? AppColors.signConfidenceHigh
                  : AppColors.primary.withOpacity(0.5),
              width: 3,
            ),
          ),
          child: CustomPaint(
            painter: DetectionOverlayPainter(),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Positioned(
      top: AppConstants.spacingMd,
      right: AppConstants.spacingMd,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: AppConstants.iconSizeSm,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Detecting',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Toggle Button
          FilledButton.icon(
            onPressed: _toggleTranslation,
            icon: Icon(_isProcessing ? Icons.stop : Icons.play_arrow),
            label: Text(_isProcessing ? 'Stop' : 'Start'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
            ),
          ),

          // Flash Toggle
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => ref.read(cameraServiceProvider).toggleFlash(),
            tooltip: 'Toggle Flash',
            iconSize: AppConstants.iconSizeLg,
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Input'),
        content: TextField(
          controller: _manualInputController,
          decoration: const InputDecoration(
            labelText: 'Enter text',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              final sign = AslSign.fromWord(value);
              setState(() {
                _signHistory.insert(0, sign);
              });
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_manualInputController.text.isNotEmpty) {
                final sign = AslSign.fromWord(_manualInputController.text);
                setState(() {
                  _signHistory.insert(0, sign);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXl),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppConstants.spacingMd),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                'Sign History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _signHistory.length,
                  itemBuilder: (context, index) {
                    final sign = _signHistory[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(sign.letter.isNotEmpty ? sign.letter : sign.word[0].toUpperCase()),
                      ),
                      title: Text(sign.word),
                      subtitle: Text('Confidence: ${(sign.confidence * 100).toStringAsFixed(1)}%'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for detection overlay.
class DetectionOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw corner indicators
    const cornerLength = 40.0;
    const cornerWidth = 3.0;
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    for (final corner in corners) {
      // Horizontal line
      canvas.drawRect(
        Rect.fromLTWH(
          corner.dx - (corner == corners[0] || corner == corners[2] ? 0 : cornerLength),
          corner.dy - (corner == corners[0] || corner == corners[1] ? 0 : cornerLength),
          cornerLength,
          cornerWidth,
        ),
        paint..color = AppColors.primary,
      );

      // Vertical line
      canvas.drawRect(
        Rect.fromLTWH(
          corner.dx - (corner == corners[0] || corner == corners[2] ? 0 : cornerWidth),
          corner.dy - (corner == corners[0] || corner == corners[1] ? 0 : cornerLength),
          cornerWidth,
          cornerLength,
        ),
        paint..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
