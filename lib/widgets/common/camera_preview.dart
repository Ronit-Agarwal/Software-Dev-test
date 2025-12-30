import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/models/camera_state.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/utils/constants.dart';

/// Camera preview widget that displays the camera feed with full lifecycle management.
///
/// This widget provides a consistent camera preview interface with:
/// - Proper lifecycle management
/// - Visual indicator when camera is active
/// - Camera on/off toggle with haptic feedback
/// - Accessibility labels for screen readers
/// - Error handling with user-friendly messages
/// - Support for portrait and landscape orientations
class CameraPreviewWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final bool showFps;
  final VoidCallback? onCameraToggle;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onToggleFlash;
  final Widget Function(BuildContext, CameraFrame)? frameBuilder;

  const CameraPreviewWidget({
    super.key,
    this.showControls = true,
    this.showFps = false,
    this.onCameraToggle,
    this.onSwitchCamera,
    this.onToggleFlash,
    this.frameBuilder,
  });

  @override
  ConsumerState<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends ConsumerState<CameraPreviewWidget>
    with WidgetsBindingObserver {
  bool _isRecordingIndicatorVisible = false;
  Timer? _recordingIndicatorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showRecordingIndicator();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingIndicatorTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraService = ref.read(cameraServiceProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        cameraService.onAppForeground();
        break;
      case AppLifecycleState.paused:
        cameraService.onAppBackground();
        break;
      default:
        break;
    }
  }

  void _showRecordingIndicator() {
    setState(() {
      _isRecordingIndicatorVisible = true;
    });

    // Hide after 3 seconds
    _recordingIndicatorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isRecordingIndicatorVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(cameraServiceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: _calculateAspectRatio(cameraService),
          child: _buildCameraPreview(cameraService, constraints),
        );
      },
    );
  }

  double _calculateAspectRatio(CameraService cameraService) {
    if (cameraService.controller == null) {
      return 4.0 / 3.0; // Default aspect ratio
    }
    final size = cameraService.controller!.value.previewSize;
    if (size == null) return 4.0 / 3.0;
    return size.width / size.height;
  }

  Widget _buildCameraPreview(CameraService cameraService, BoxConstraints constraints) {
    switch (cameraService.state) {
      case CameraState.initializing:
      case CameraState.starting:
      case CameraState.preparingStream:
      case CameraState.retrying:
        return _buildLoadingState();

      case CameraState.permissionDenied:
        return _buildPermissionDeniedState();

      case CameraState.noCamerasAvailable:
        return _buildNoCameraState();

      case CameraState.disabled:
        return _buildDisabledState();

      case CameraState.error:
        return _buildErrorState(cameraService.error);

      case CameraState.ready:
      case CameraState.streaming:
        return _buildCameraPreviewStream(cameraService);

      case CameraState.disposed:
        return _buildDisposedState();
    }
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: AppConstants.iconSizeXl,
              height: AppConstants.iconSizeXl,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: AppColors.onSurfaceVariantLight,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: AppColors.errorLight.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_off,
              size: AppConstants.iconSizeXl,
              color: AppColors.error,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: Text(
                'Camera permission denied',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: Text(
                'Please enable camera access in settings to use this feature.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            ElevatedButton.icon(
              onPressed: () async {
                await _openSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCameraState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: AppConstants.iconSizeXl,
              color: AppColors.onSurfaceVariantLight,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'No camera available',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'This device does not have a camera.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: AppConstants.iconSizeXl,
              color: AppColors.onSurfaceVariantLight.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Camera disabled',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Tap the button below to enable the camera.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            FilledButton.icon(
              onPressed: () async {
                await _toggleCamera();
              },
              icon: const Icon(Icons.camera),
              label: const Text('Enable Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: AppColors.errorLight.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppConstants.iconSizeXl,
              color: AppColors.error,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: Text(
                'Camera Error',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: Text(
                  errorMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await _retryCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                FilledButton.icon(
                  onPressed: () async {
                    await _openSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisposedState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Center(
        child: Text(
          'Camera disposed',
          style: TextStyle(
            color: AppColors.onSurfaceVariantLight,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreviewStream(CameraService cameraService) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(
              cameraService.controller!,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          // Recording indicator
          if (_isRecordingIndicatorVisible && cameraService.isStreaming)
            Positioned(
              top: AppConstants.spacingMd,
              left: AppConstants.spacingMd,
              child: _buildRecordingIndicator(),
            ),

          // FPS indicator (optional)
          if (widget.showFps && cameraService.isStreaming)
            Positioned(
              top: AppConstants.spacingMd,
              right: AppConstants.spacingMd,
              child: _buildFpsIndicator(cameraService.currentFps),
            ),

          // Controls overlay
          if (widget.showControls)
            Positioned.fill(
              child: _buildControlsOverlay(cameraService),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppConstants.spacingXs),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFpsIndicator(double fps) {
    final color = fps >= 25
        ? AppColors.success
        : fps >= 20
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        '${fps.toStringAsFixed(1)} FPS',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(CameraService cameraService) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cameraOverlay.withOpacity(0.3),
            Colors.transparent,
            Colors.transparent,
            AppColors.cameraOverlay.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row - status and flash toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Camera status
                _buildStatusChip(cameraService),
                // Flash toggle
                if (cameraService.hasFlash)
                  IconButton(
                    onPressed: () async {
                      await _toggleFlash();
                    },
                    icon: Icon(
                      cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    tooltip: cameraService.isFlashOn ? 'Turn off flash' : 'Turn on flash',
                  ),
              ],
            ),

            // Bottom row - camera controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Camera toggle
                IconButton(
                  onPressed: () async {
                    await _toggleCamera();
                  },
                  icon: Icon(
                    cameraService.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                    size: AppConstants.iconSizeLg,
                  ),
                  tooltip: cameraService.isCameraEnabled ? 'Turn off camera' : 'Turn on camera',
                ),

                // Switch camera
                if (cameraService.availableCameras.length > 1)
                  IconButton(
                    onPressed: () async {
                      await _switchCamera();
                    },
                    icon: const Icon(
                      Icons.cameraswitch,
                      color: Colors.white,
                      size: AppConstants.iconSizeLg,
                    ),
                    tooltip: 'Switch camera',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(CameraService cameraService) {
    Color statusColor;
    String statusText;

    switch (cameraService.state) {
      case CameraState.streaming:
        statusColor = AppColors.success;
        statusText = 'Recording';
        break;
      case CameraState.ready:
        statusColor = AppColors.info;
        statusText = 'Ready';
        break;
      case CameraState.retrying:
        statusColor = AppColors.warning;
        statusText = 'Retrying...';
        break;
      default:
        statusColor = AppColors.outlineLight;
        statusText = 'Idle';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _toggleCamera() async {
    final cameraService = ref.read(cameraServiceProvider);
    await cameraService.toggleCamera();
    widget.onCameraToggle?.call();
    _showRecordingIndicator();
  }

  Future<void> _switchCamera() async {
    final cameraService = ref.read(cameraServiceProvider);
    await cameraService.switchCamera();
    widget.onSwitchCamera?.call();
  }

  Future<void> _toggleFlash() async {
    final cameraService = ref.read(cameraServiceProvider);
    await cameraService.toggleFlash();
    widget.onToggleFlash?.call();
  }

  Future<void> _retryCamera() async {
    final cameraService = ref.read(cameraServiceProvider);
    await cameraService.initialize();
    await cameraService.startCamera();
  }

  Future<void> _openSettings() async {
    try {
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      // Fallback - just open settings
    }
  }
}

/// A camera preview placeholder with a button.
class CameraPreviewPlaceholder extends ConsumerWidget {
  final VoidCallback onCameraPermissionRequest;
  final bool isPermissionDenied;

  const CameraPreviewPlaceholder({
    super.key,
    required this.onCameraPermissionRequest,
    this.isPermissionDenied = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariantLight,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionDenied ? Icons.camera_off : Icons.videocam,
              size: AppConstants.iconSizeXl,
              color: AppColors.onSurfaceVariantLight,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              isPermissionDenied
                  ? 'Camera permission denied'
                  : 'Camera not available',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              isPermissionDenied
                  ? 'Please enable camera access in settings'
                  : 'Tap below to enable camera',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            ElevatedButton.icon(
              onPressed: onCameraPermissionRequest,
              icon: const Icon(Icons.camera),
              label: const Text('Enable Camera'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact camera preview for small screens.
class CompactCameraPreview extends ConsumerWidget {
  const CompactCameraPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService = ref.watch(cameraServiceProvider);

    return SizedBox(
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: cameraService.isInitialized && cameraService.controller != null
            ? CameraPreview(cameraService.controller!)
            : Container(
                color: AppColors.surfaceVariantLight,
                child: const Center(
                  child: Icon(Icons.camera_alt),
                ),
              ),
      ),
    );
  }
}

/// A full-screen camera preview for immersive mode.
class FullScreenCameraPreview extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final bool showControls;
  final bool showCloseButton;

  const FullScreenCameraPreview({
    super.key,
    this.onClose,
    this.showControls = true,
    this.showCloseButton = true,
  });

  @override
  State<FullScreenCameraPreview> createState() => _FullScreenCameraPreviewState();
}

class _FullScreenCameraPreviewState extends ConsumerState<FullScreenCameraPreview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, child) {
                  final cameraService = ref.watch(cameraServiceProvider);

                  if (!cameraService.isInitialized) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  return CameraPreview(
                    cameraService.controller!,
                    child: const SizedBox.shrink(),
                  );
                },
              ),
            ),

            // Close button
            if (widget.showCloseButton)
              Positioned(
                top: AppConstants.spacingMd,
                left: AppConstants.spacingMd,
                child: IconButton(
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'Close camera',
                ),
              ),

            // Controls
            if (widget.showControls)
              Positioned(
                bottom: AppConstants.spacingXl,
                left: 0,
                right: 0,
                child: _buildBottomControls(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Consumer(
      builder: (context, ref, child) {
        final cameraService = ref.watch(cameraServiceProvider);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Toggle camera
            IconButton(
              onPressed: cameraService.availableCameras.length > 1
                  ? () async {
                      await cameraService.switchCamera();
                    }
                  : null,
              icon: const Icon(
                Icons.cameraswitch,
                color: Colors.white,
                size: 32,
              ),
              tooltip: 'Switch camera',
            ),

            // Capture button
            IconButton(
              onPressed: () async {
                await _capturePhoto();
              },
              icon: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                ),
                child: const Icon(
                  Icons.camera,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              tooltip: 'Capture photo',
            ),

            // Toggle flash
            IconButton(
              onPressed: cameraService.hasFlash
                  ? () async {
                      await cameraService.toggleFlash();
                    }
                  : null,
              icon: Icon(
                cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 32,
              ),
              tooltip: cameraService.isFlashOn ? 'Turn off flash' : 'Turn on flash',
            ),
          ],
        );
      },
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      final path = await cameraService.captureImage();
      LoggerService.info('Photo captured: $path');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      LoggerService.error('Failed to capture photo', error: e, stack: stack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
