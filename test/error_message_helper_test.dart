import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/utils/error_message_helper.dart';

void main() {
  group('ErrorMessageHelper', () {
    test('getUserMessage returns user-friendly message for PermissionException', () {
      final error = const PermissionException(
        'Camera permission denied',
        permissionType: 'camera',
      );

      final message = ErrorMessageHelper.getUserMessage(error);

      expect(message, contains('Camera access is required'));
      expect(message, contains('grant camera permission'));
    });

    test('getUserMessage returns user-friendly message for ModelLoadException', () {
      final error = const ModelLoadException(
        'Model file not found',
        modelPath: 'assets/models/asl_cnn.tflite',
        modelType: 'ResNet-50',
      );

      final message = ErrorMessageHelper.getUserMessage(error);

      expect(message, contains('model files are missing'));
      expect(message, contains('reinstall'));
    });

    test('getUserMessage returns user-friendly message for CameraException', () {
      final error = const CameraException('no_cameras', 'No cameras available');

      final message = ErrorMessageHelper.getUserMessage(error);

      expect(message, contains('camera is available'));
      expect(message, contains('working camera'));
    });

    test('getUserMessage returns user-friendly message for inference timeout', () {
      final error = InferenceException('Inference timed out');

      final message = ErrorMessageHelper.getUserMessage(error);

      expect(message, contains('Processing timed out'));
      expect(message, contains('try again'));
    });

    test('getErrorTitle returns correct title for permission errors', () {
      final error = const PermissionException('Denied', permissionType: 'camera');

      final title = ErrorMessageHelper.getErrorTitle(error);

      expect(title, 'Permission Required');
    });

    test('getErrorTitle returns correct title for camera errors', () {
      final error = const CameraException('no_cameras', 'No cameras');

      final title = ErrorMessageHelper.getErrorTitle(error);

      expect(title, 'Camera Error');
    });

    test('getErrorTitle returns correct title for model errors', () {
      final error = const ModelLoadException('Load failed', modelType: 'CNN');

      final title = ErrorMessageHelper.getErrorTitle(error);

      expect(title, 'Model Loading Error');
    });

    test('isRecoverable returns true for network errors', () {
      final error = Exception('Network connection failed');

      final isRecoverable = ErrorMessageHelper.isRecoverable(error);

      expect(isRecoverable, true);
    });

    test('isRecoverable returns true for timeout errors', () {
      final error = Exception('Operation timed out');

      final isRecoverable = ErrorMessageHelper.isRecoverable(error);

      expect(isRecoverable, true);
    });

    test('isRecoverable returns false for permission denied errors', () {
      final error = const PermissionException('Denied', permissionType: 'camera');

      final isRecoverable = ErrorMessageHelper.isRecoverable(error);

      expect(isRecoverable, false);
    });

    test('isRecoverable returns false for model not found errors', () {
      final error = const ModelLoadException('Model not found');

      final isRecoverable = ErrorMessageHelper.isRecoverable(error);

      expect(isRecoverable, false);
    });

    test('getActionSuggestion returns suggestion for permission errors', () {
      final error = const PermissionException('Denied', permissionType: 'camera');

      final suggestion = ErrorMessageHelper.getActionSuggestion(error);

      expect(suggestion, 'Go to Settings');
    });

    test('getActionSuggestion returns suggestion for network errors', () {
      final error = Exception('Network connection failed');

      final suggestion = ErrorMessageHelper.getActionSuggestion(error);

      expect(suggestion, 'Check Connection');
    });

    test('getActionSuggestion returns suggestion for timeout errors', () {
      final error = Exception('Operation timed out');

      final suggestion = ErrorMessageHelper.getActionSuggestion(error);

      expect(suggestion, 'Try Again');
    });

    test('getActionSuggestion returns suggestion for memory errors', () {
      final error = Exception('Out of memory');

      final suggestion = ErrorMessageHelper.getActionSuggestion(error);

      expect(suggestion, 'Close Other Apps');
    });

    test('getActionSuggestion returns suggestion for model load errors', () {
      final error = const ModelLoadException('Load failed');

      final suggestion = ErrorMessageHelper.getActionSuggestion(error);

      expect(suggestion, 'Reinstall App');
    });
  });
}
