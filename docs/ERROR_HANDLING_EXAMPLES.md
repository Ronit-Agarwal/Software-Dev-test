# Error Handling Usage Examples

This document provides examples of how to use the new error handling features implemented in Task 19A.

## 1. Permission Error Handling

### Basic Permission Request with Retry

```dart
class MyScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsService = ref.watch(permissionsServiceProvider);

    if (!permissionsService.hasCameraPermission) {
      return CameraPermissionDeniedWidget(
        isPermanentlyDenied: permissionsService.cameraStatus.isPermanentlyDenied,
        onRequestPermission: () async {
          final granted = await ref.read(permissionsServiceProvider).requestCameraPermission();
          if (granted) {
            // Permission granted, proceed with camera
          }
        },
        onOpenSettings: () {
          ref.read(permissionsServiceProvider).openSettings();
        },
      );
    }

    return CameraPreview();
  }
}
```

### Handling Permission Exceptions

```dart
try {
  final cameraService = ref.read(cameraServiceProvider);
  await cameraService.initialize();
} on PermissionException catch (e) {
  // User-friendly message already in e.message
  showUserFriendlyError(e);

  if (e.message.contains('permanently denied')) {
    // Guide user to settings
    showSettingsDialog();
  } else {
    // Show retry option
    showRetryDialog(onRetry: () async {
      await cameraService.initialize();
    });
  }
}
```

## 2. Model Loading Error Handling

### Loading Model with Timeout

```dart
class ModelLoaderService {
  Future<bool> loadModelWithFallback(String modelPath) async {
    try {
      final cnnService = CnnInferenceService();
      await cnnService.initialize(modelPath: modelPath);
      return true;
    } on ModelLoadException catch (e) {
      LoggerService.error('Model load failed', error: e);

      // Show fallback UI
      showModelUnavailableWidget(
        modelType: 'CNN',
        error: e.message,
        onRetry: () async {
          final success = await loadModelWithFallback(modelPath);
          return success;
        },
      );

      return false;
    } catch (e) {
      LoggerService.error('Unexpected error', error: e);
      return false;
    }
  }
}
```

### Model Unavailable Fallback in UI

```dart
class InferenceScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cnnService = ref.watch(cnnInferenceServiceProvider);

    if (!cnnService.isModelLoaded) {
      return ModelUnavailableWidget(
        modelType: 'ResNet-50 CNN',
        error: cnnService.error,
        onRetry: () async {
          try {
            await ref.read(cnnInferenceServiceProvider).initialize();
          } catch (e) {
            // Error already logged
          }
        },
        onGoToSettings: () {
          Navigator.push(context, SettingsRoute());
        },
      );
    }

    return CameraPreviewWidget(
      onFrame: (image) async {
        final sign = await cnnService.processFrame(image);
        if (sign != null) {
          displaySign(sign);
        }
      },
    );
  }
}
```

## 3. Inference Error Handling

### Automatic Retry with Error Messages

```dart
class SignTranslator {
  final CnnInferenceService _cnnService;

  Future<AslSign?> translateFrame(CameraImage image) async {
    try {
      final sign = await _cnnService.processFrame(image);
      return sign;
    } on InferenceException catch (e) {
      // Error already retried automatically
      if (e.message.contains('corrupted')) {
        LoggerService.warn('Frame corrupted, skipping');
        return null; // Skip this frame
      }

      // Max retries reached, show user-friendly message
      showErrorSnackbar(
        'AI processing error. Please try adjusting lighting or camera angle.',
      );

      return null;
    } catch (e) {
      LoggerService.error('Unexpected inference error', error: e);
      return null;
    }
  }
}
```

### Corrupted Frame Recovery

```dart
class CameraFrameHandler {
  final CnnInferenceService _cnnService;
  int _consecutiveCorruptedFrames = 0;

  void handleFrame(CameraImage image) async {
    try {
      final sign = await _cnnService.processFrame(image);

      if (sign != null) {
        // Valid frame with sign detected
        _consecutiveCorruptedFrames = 0;
        displaySign(sign);
      } else {
        // Valid frame but no sign detected
        _consecutiveCorruptedFrames = 0;
      }
    } on MlInferenceException catch (e) {
      if (e.message.contains('corrupted')) {
        _consecutiveCorruptedFrames++;

        if (_consecutiveCorruptedFrames >= 3) {
          // Multiple corrupted frames in a row
          showCameraErrorDialog(
            'Camera feed appears corrupted. Please check camera connection.',
            actions: [
              DialogAction(
                label: 'Restart Camera',
                onPressed: () => restartCamera(),
              ),
              DialogAction(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        } else {
          // Single corrupted frame, skip
          LoggerService.warn('Corrupted frame $_consecutiveCorruptedFrames/3');
        }
      }
    }
  }
}
```

## 4. User-Friendly Error Messages

### Using ErrorMessageHelper

```dart
void showErrorDialog(dynamic error, BuildContext context) {
  final title = ErrorMessageHelper.getErrorTitle(error);
  final message = ErrorMessageHelper.getUserMessage(error);
  final suggestion = ErrorMessageHelper.getActionSuggestion(error);
  final isRecoverable = ErrorMessageHelper.isRecoverable(error);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        if (isRecoverable && suggestion != null)
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              // Handle retry based on error type
              if (error is PermissionException) {
                await retryPermission();
              } else if (error is ModelLoadException) {
                await retryModelLoad();
              } else {
                await retryOperation();
              }
            },
            child: Text(suggestion!),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
      ],
    ),
  );
}

// Usage
try {
  await cameraService.startStreaming(onFrame: processFrame);
} catch (e) {
  showErrorDialog(e, context);
}
```

### Error Snackbar

```dart
void showErrorSnackbar(dynamic error, BuildContext context) {
  final message = ErrorMessageHelper.getUserMessage(error);
  final suggestion = ErrorMessageHelper.getActionSuggestion(error);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (suggestion != null)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                // Handle action
                if (suggestion == 'Go to Settings') {
                  openSettings();
                } else if (suggestion == 'Retry') {
                  retryOperation();
                }
              },
              child: Text(
                suggestion!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
    ),
  );
}
```

## 5. Graceful Degradation

### Feature Degradation Strategy

```dart
class MlOrchestratorService {
  final CnnInferenceService _cnnService;
  final LstmInferenceService _lstmService;

  Future<MlResult> processFrame(CameraImage image) async {
    // Try CNN first (static signs)
    try {
      if (_cnnService.isModelLoaded) {
        final sign = await _cnnService.processFrame(image);
        if (sign != null) {
          return MlResult.aslStatic(sign: sign);
        }
      }
    } on ModelLoadException catch (e) {
      LoggerService.warn('CNN model unavailable: $e');
      // Fall back to other modes
    }

    // Try LSTM (dynamic signs)
    try {
      if (_lstmService.isModelLoaded) {
        final sign = await _lstmService.processFrame(image);
        if (sign != null) {
          return MlResult.aslDynamic(sign: sign);
        }
      }
    } on ModelLoadException catch (e) {
      LoggerService.warn('LSTM model unavailable: $e');
      // Fall back to detection mode
    }

    // All models failed, return degraded result
    return MlResult.error(
      'AI models temporarily unavailable. '
      'Some features may not work until models load.',
    );
  }
}
```

### UI Degradation Example

```dart
class FeatureMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cnnModel = ref.watch(cnnInferenceServiceProvider);
    final lstmModel = ref.watch(lstmInferenceServiceProvider);

    return ListView(
      children: [
        // Static ASL (requires CNN)
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('Static ASL Recognition'),
          enabled: cnnModel.isModelLoaded,
          subtitle: cnnModel.isModelLoaded
              ? null
              : const Text('Model not loaded - feature unavailable'),
          onTap: () => navigateToStaticAsl(),
        ),

        // Dynamic ASL (requires CNN + LSTM)
        ListTile(
          leading: const Icon(Icons.video_library),
          title: const Text('Dynamic ASL Recognition'),
          enabled: cnnModel.isModelLoaded && lstmModel.isModelLoaded,
          subtitle: (!cnnModel.isModelLoaded || !lstmModel.isModelLoaded)
              ? const Text('Models not loaded - feature unavailable')
              : null,
          onTap: () => navigateToDynamicAsl(),
        ),

        // Object Detection (may have separate model)
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Object Detection'),
          onTap: () => navigateToDetection(),
        ),
      ],
    );
  }
}
```

## 6. Error Recovery Strategies

### Automatic Recovery

```dart
class AutoRecoveryService {
  final ErrorRecoveryService _errorRecovery;

  AutoRecoveryService() : _errorRecovery = ErrorRecoveryService() {
    _errorRecovery.initialize();
  }

  Future<void> handleOperation<T>(
    Future<T> Function() operation,
    String context,
  ) async {
    try {
      return await operation();
    } catch (e, stack) {
      final result = _errorRecovery.recordError(
        e,
        context,
        stackTrace: stack,
        recoverable: true,
      );

      if (result.recovered) {
        LoggerService.info('Auto-recovery successful for $context');
        return await operation(); // Retry once
      }

      // Not recoverable, show user message
      final message = ErrorMessageHelper.getUserMessage(e);
      showErrorDialog(message, context);
      rethrow;
    }
  }
}

// Usage
await AutoRecoveryService().handleOperation(
  () => cameraService.startStreaming(onFrame: processFrame),
  'camera_streaming',
);
```

### Circuit Breaker Pattern

```dart
class SafeApiService {
  final ErrorRecoveryService _errorRecovery;
  static const String _serviceName = 'api_service';

  Future<T> safeApiCall<T>(Future<T> Function() apiCall) async {
    // Check circuit breaker
    if (!_errorRecovery.isServiceAvailable(_serviceName)) {
      throw Exception('Service temporarily unavailable (circuit breaker open)');
    }

    try {
      final result = await apiCall();

      // Record success to close circuit
      _errorRecovery.recordSuccess(_serviceName);

      return result;
    } catch (e) {
      // Record failure, may open circuit
      _errorRecovery.recordFailure(_serviceName);

      // Circuit breaker handles retry logic
      final result = _errorRecovery.recordError(e, 'api_call');

      if (!result.recovered) {
        rethrow;
      }

      return await apiCall(); // Retry if recovered
    }
  }
}
```

## 7. Testing Error Handling

### Mocking Errors for Testing

```dart
void main() {
  test('handles permission denial gracefully', () async {
    final service = MockPermissionsService();

    when(service.requestCameraPermission())
        .thenAnswer((_) async => false);

    final result = await service.requestCameraPermission();

    expect(result, false);
    verify(service.requestCameraPermission()).called(1);
  });

  test('retries on model load failure', () async {
    final service = CnnInferenceService();

    // Mock model load to fail first time
    expect(() async => await service.initialize(),
        throwsA(isA<ModelLoadException>()));

    // Verify retry count increased
    // Verify user-friendly message generated
  });
}
```

## Summary

The error handling system provides:

1. **User-friendly messages** instead of technical errors
2. **Automatic retry** with exponential backoff
3. **Timeout protection** for long-running operations
4. **Corrupted frame detection** to prevent crashes
5. **Fallback UI** when features unavailable
6. **Graceful degradation** - partial functionality when models fail
7. **Recovery strategies** - automatic and manual
8. **Comprehensive logging** for debugging

All error handling is integrated with existing services and provides clear guidance to users when issues occur.
