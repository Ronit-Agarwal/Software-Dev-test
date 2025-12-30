import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Camera preview widget that displays the camera feed.
///
/// This widget provides a consistent camera preview interface with
/// proper lifecycle management.
class CameraPreviewWidget extends ConsumerWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService = ref.watch(cameraServiceProvider);

    if (!cameraService.isInitialized) {
      return _buildPlaceholder();
    }

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
          // Overlay
          Positioned.fill(
            child: _buildOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
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
              color: AppColors.outlineLight,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Camera initializing...',
              style: TextStyle(
                color: AppColors.onSurfaceVariantLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
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
    );
  }
}

/// A camera preview placeholder with a button.
class CameraPreviewPlaceholder extends StatelessWidget {
  final VoidCallback onCameraPermissionRequest;
  final bool isPermissionDenied;

  const CameraPreviewPlaceholder({
    super.key,
    required this.onCameraPermissionRequest,
    this.isPermissionDenied = false,
  });

  @override
  Widget build(BuildContext context) {
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
