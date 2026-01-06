import 'package:flutter/foundation.dart';
import 'package:signsync/core/error/exceptions.dart';

/// Helper utility for generating user-friendly error messages.
///
/// Converts technical exceptions into messages that are easy for users to understand.
class ErrorMessageHelper {
  /// Gets a user-friendly message for an exception.
  static String getUserMessage(dynamic error) {
    if (error == null) {
      return 'An unknown error occurred.';
    }

    final errorString = error.toString().toLowerCase();

    // Permission errors
    if (error is PermissionException) {
      return error.message;
    }

    if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      if (errorString.contains('camera')) {
        return 'Camera access is required to use this feature. '
            'Please grant camera permission in your device settings.';
      } else if (errorString.contains('microphone')) {
        return 'Microphone access is required for this feature. '
            'Please grant microphone permission in your device settings.';
      } else {
        return 'Permission is required to use this feature. '
            'Please check your device settings.';
      }
    }

    // Camera errors
    if (error is CameraException || errorString.contains('camera')) {
      if (errorString.contains('no cameras') ||
          errorString.contains('not available')) {
        return 'No camera is available on this device. '
            'Please ensure your device has a working camera.';
      } else if (errorString.contains('timed out')) {
        return 'Camera initialization timed out. '
            'Please try again or restart the app.';
      } else if (errorString.contains('already in use')) {
        return 'Camera is already in use by another app. '
            'Please close other camera apps and try again.';
      } else if (errorString.contains('disconnected')) {
        return 'Camera was disconnected. Please check your camera connection and try again.';
      } else {
        return 'Camera error occurred. Please try again or restart the app.';
      }
    }

    // Model loading errors
    if (error is ModelLoadException || errorString.contains('model load')) {
      if (errorString.contains('not found') ||
          errorString.contains('asset')) {
        return 'Required model files are missing. '
            'Please reinstall the app or contact support.';
      } else if (errorString.contains('timed out')) {
        return 'Model loading timed out. '
            'Please check your device performance and try again.';
      } else if (errorString.contains('format') ||
                 errorString.contains('corrupted')) {
        return 'Model file is corrupted or invalid. '
            'Please reinstall the app.';
      } else if (errorString.contains('incompatible')) {
        return 'Model file is not compatible with this device. '
            'Please update the app.';
      } else {
        return 'Failed to load AI model. '
            'Please try again or reinstall the app.';
      }
    }

    // Inference errors
    if (error is InferenceException || errorString.contains('inference')) {
      if (errorString.contains('not loaded')) {
        return 'AI model is not loaded. Please wait a moment and try again.';
      } else if (errorString.contains('corrupted') ||
                 errorString.contains('camera feed')) {
        return 'Camera feed appears corrupted. '
            'Please restart the camera or check your camera.';
      } else if (errorString.contains('timeout')) {
        return 'Processing timed out. Please try again.';
      } else {
        return 'AI processing error occurred. Please try again.';
      }
    }

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return 'Network error occurred. '
          'Please check your internet connection and try again.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    }

    // Memory errors
    if (errorString.contains('memory') ||
        errorString.contains('out of memory')) {
      return 'Device memory is low. Please close other apps and try again.';
    }

    // Default message
    if (errorString.length > 100) {
      return errorString.substring(0, 100) + '...';
    }

    return 'An error occurred: ${error.toString()}';
  }

  /// Gets a title for error dialogs.
  static String getErrorTitle(dynamic error) {
    if (error == null) {
      return 'Error';
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission')) {
      return 'Permission Required';
    }

    if (errorString.contains('camera')) {
      return 'Camera Error';
    }

    if (errorString.contains('model load')) {
      return 'Model Loading Error';
    }

    if (errorString.contains('inference')) {
      return 'AI Processing Error';
    }

    if (errorString.contains('network')) {
      return 'Network Error';
    }

    if (errorString.contains('timeout')) {
      return 'Timeout Error';
    }

    if (errorString.contains('memory')) {
      return 'Memory Error';
    }

    return 'Error';
  }

  /// Checks if an error is recoverable (can be retried).
  static bool isRecoverable(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // Network errors are often recoverable
    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return true;
    }

    // Timeout errors are recoverable
    if (errorString.contains('timeout')) {
      return true;
    }

    // Temporary errors are recoverable
    if (errorString.contains('temporary') ||
        errorString.contains('unavailable')) {
      return true;
    }

    // Permission denied is NOT recoverable (requires user action)
    if (errorString.contains('permission') && errorString.contains('denied')) {
      return false;
    }

    // Model not found is NOT recoverable (requires reinstall)
    if (errorString.contains('model') && errorString.contains('not found')) {
      return false;
    }

    return false;
  }

  /// Gets action suggestion for the error.
  static String? getActionSuggestion(dynamic error) {
    if (error == null) return null;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission') && errorString.contains('denied')) {
      return 'Go to Settings';
    }

    if (errorString.contains('camera')) {
      return 'Restart Camera';
    }

    if (errorString.contains('network')) {
      return 'Check Connection';
    }

    if (errorString.contains('memory')) {
      return 'Close Other Apps';
    }

    if (errorString.contains('model load')) {
      return 'Reinstall App';
    }

    if (errorString.contains('timeout')) {
      return 'Try Again';
    }

    return 'Try Again';
  }
}
