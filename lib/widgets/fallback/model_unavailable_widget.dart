import 'package:flutter/material.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Widget displayed when ML models are unavailable or failed to load.
///
/// Provides user-friendly messaging and fallback actions.
class ModelUnavailableWidget extends StatelessWidget {
  final String? modelType;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onGoToSettings;

  const ModelUnavailableWidget({
    super.key,
    this.modelType,
    this.error,
    this.onRetry,
    this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Title
          Text(
            'AI Model Unavailable',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingSm),

          // Description
          Text(
            _getDescription(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingSm),

          // Error Details (if provided)
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.2),
                ),
              ),
              child: Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),

              if (onRetry != null && onGoToSettings != null)
                const SizedBox(width: AppConstants.spacingSm),

              if (onGoToSettings != null)
                OutlinedButton.icon(
                  onPressed: onGoToSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                ),
            ],
          ),

          // Help text
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'If this problem persists, please reinstall the app or contact support.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getDescription() {
    if (modelType != null) {
      switch (modelType!.toLowerCase()) {
        case 'cnn':
          return 'The ASL recognition model could not be loaded. '
              'This feature will not be available until the model loads successfully.';
        case 'lstm':
          return 'The dynamic sign recognition model could not be loaded. '
              'Static sign recognition is still available.';
        case 'yolo':
          return 'The object detection model could not be loaded. '
              'ASL recognition is still available.';
        default:
          return 'The AI model could not be loaded. '
              'This feature will be unavailable.';
      }
    }

    return 'One or more AI models could not be loaded. '
        'Some features may not be available.';
  }
}

/// Widget displayed when camera permission is denied.
class CameraPermissionDeniedWidget extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onOpenSettings;

  const CameraPermissionDeniedWidget({
    super.key,
    this.isPermanentlyDenied = false,
    this.onRequestPermission,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Permission Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Title
          Text(
            isPermanentlyDenied
                ? 'Camera Permission Denied'
                : 'Camera Permission Required',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingSm),

          // Description
          Text(
            isPermanentlyDenied
                ? 'Camera access was previously denied. '
                    'To enable camera features, go to your device settings and allow camera access.'
                : 'SignSync needs camera access to recognize ASL signs and detect objects. '
                    'This helps translate sign language in real-time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingLg),

          // Actions
          if (isPermanentlyDenied) ...[
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ] else ...[
            if (onRequestPermission != null)
              FilledButton.icon(
                onPressed: onRequestPermission,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Allow Camera Access'),
              ),
          ],
        ],
      ),
    );
  }
}
