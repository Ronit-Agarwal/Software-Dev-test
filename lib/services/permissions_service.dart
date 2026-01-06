import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/services/storage_service.dart';

/// Service for managing app permissions across platforms.
///
/// This service handles requesting, checking, and managing runtime
/// permissions for camera, microphone, and storage access.
class PermissionsService {
  final StorageService? _storageService;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  PermissionStatus _photoLibraryStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  // Retry tracking
  int _cameraRequestCount = 0;
  int _microphoneRequestCount = 0;
  static const int _maxRetryAttempts = 3;

  PermissionsService([this._storageService]);

  // Getters for permission statuses
  PermissionStatus get cameraStatus => _cameraStatus;
  PermissionStatus get microphoneStatus => _microphoneStatus;
  PermissionStatus get photoLibraryStatus => _photoLibraryStatus;
  PermissionStatus get notificationStatus => _notificationStatus;
  int get cameraRequestCount => _cameraRequestCount;
  int get microphoneRequestCount => _microphoneRequestCount;

  /// Returns the overall permission status based on critical permissions.
  PermissionStatus get overallStatus {
    if (!_cameraStatus.isGranted) return _cameraStatus;
    if (!_microphoneStatus.isGranted) return _microphoneStatus;
    return PermissionStatus.granted;
  }

  /// Returns true if all required permissions are granted.
  bool get allPermissionsGranted {
    return _cameraStatus.isGranted && _microphoneStatus.isGranted;
  }

  /// Returns true if camera permission is granted.
  bool get hasCameraPermission => _cameraStatus.isGranted;

  /// Returns true if microphone permission is granted.
  bool get hasMicrophonePermission => _microphoneStatus.isGranted;

  /// Returns true if photo library permission is granted.
  bool get hasPhotoLibraryPermission => _photoLibraryStatus.isGranted;

  /// Initializes the permission service by checking current statuses.
  Future<void> initialize() async {
    LoggerService.info('Initializing permissions service');
    await _refreshAllPermissions();
  }

  /// Refreshes all permission statuses.
  Future<void> _refreshAllPermissions() async {
    if (Platform.isIOS) {
      _cameraStatus = await Permission.camera.status;
      _microphoneStatus = await Permission.microphone.status;
      _photoLibraryStatus = await Permission.photos.status;
      _notificationStatus = await Permission.notification.status;
    } else if (Platform.isAndroid) {
      _cameraStatus = await Permission.camera.status;
      _microphoneStatus = await Permission.microphone.status;
      _photoLibraryStatus = await Permission.storage.status;
      _notificationStatus = await Permission.notification.status;
    }
    LoggerService.debug('Permission statuses refreshed: camera=$_cameraStatus, mic=$_microphoneStatus');
  }

  /// Requests camera permission.
  ///
  /// Returns true if permission was granted.
  /// Throws [PermissionException] if permission is permanently denied.
  Future<bool> requestCameraPermission() async {
    try {
      _cameraRequestCount++;
      LoggerService.info('Requesting camera permission (attempt $_cameraRequestCount/$_maxRetryAttempts)');
      final status = await Permission.camera.request();
      _cameraStatus = status;

      if (_storageService != null) {
        await _storageService!.logEvent('request_camera_permission', details: status.toString());
      }

      if (status.isGranted) {
        LoggerService.info('Camera permission granted');
        _cameraRequestCount = 0; // Reset counter on success
        return true;
      } else if (status.isPermanentlyDenied) {
        LoggerService.warn('Camera permission permanently denied');
        throw PermissionException(
          _getPermanentlyDeniedMessage('camera'),
          permissionType: 'camera',
        );
      } else if (status.isDenied && _cameraRequestCount >= _maxRetryAttempts) {
        LoggerService.warn('Camera permission denied after $_maxRetryAttempts attempts');
        throw PermissionException(
          _getRetryExceededMessage('camera'),
          permissionType: 'camera',
        );
      } else {
        LoggerService.warn('Camera permission denied');
        return false;
      }
    } on PlatformException catch (e, stack) {
      LoggerService.error('Platform error requesting camera permission', error: e, stack: stack);
      throw PermissionException(
        _getPlatformErrorMessage('camera'),
        permissionType: 'camera',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Requests microphone permission.
  ///
  /// Returns true if permission was granted.
  /// Throws [PermissionException] if permission is permanently denied.
  Future<bool> requestMicrophonePermission() async {
    try {
      LoggerService.info('Requesting microphone permission');
      final status = await Permission.microphone.request();
      _microphoneStatus = status;

      if (_storageService != null) {
        await _storageService!.logEvent('request_microphone_permission', details: status.toString());
      }

      if (status.isGranted) {
        LoggerService.info('Microphone permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        LoggerService.warn('Microphone permission permanently denied');
        throw const PermissionException(
          'Microphone permission is required for sound detection. Please enable it in app settings.',
          permissionType: 'microphone',
        );
      } else {
        LoggerService.warn('Microphone permission denied');
        return false;
      }
    } on PlatformException catch (e, stack) {
      LoggerService.error('Platform error requesting microphone permission', error: e, stack: stack);
      throw const PermissionException('Failed to request microphone permission');
    }
  }

  /// Requests photo library permission (iOS only).
  ///
  /// Returns true if permission was granted.
  Future<bool> requestPhotoLibraryPermission() async {
    try {
      LoggerService.info('Requesting photo library permission');
      final status = await Permission.photos.request();
      _photoLibraryStatus = status;

      if (status.isGranted) {
        LoggerService.info('Photo library permission granted');
        return true;
      } else {
        LoggerService.warn('Photo library permission denied');
        return false;
      }
    } on PlatformException catch (e, stack) {
      LoggerService.error('Platform error requesting photo library permission', error: e, stack: stack);
      throw const PermissionException('Failed to request photo library permission');
    }
  }

  /// Requests notification permission.
  ///
  /// Returns true if permission was granted.
  Future<bool> requestNotificationPermission() async {
    try {
      LoggerService.info('Requesting notification permission');
      final status = await Permission.notification.request();
      _notificationStatus = status;

      if (status.isGranted) {
        LoggerService.info('Notification permission granted');
        return true;
      } else {
        LoggerService.warn('Notification permission denied');
        return false;
      }
    } on PlatformException catch (e, stack) {
      LoggerService.error('Platform error requesting notification permission', error: e, stack: stack);
      return false;
    }
  }

  /// Requests all required permissions at once.
  ///
  /// Returns a map of permission results.
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    LoggerService.info('Requesting all required permissions');
    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    // Update cached statuses
    for (final entry in results.entries) {
      switch (entry.key) {
        case Permission.camera:
          _cameraStatus = entry.value;
          break;
        case Permission.microphone:
          _microphoneStatus = entry.value;
          break;
        default:
          break;
      }
    }

    // Check if all critical permissions are granted
    final allGranted = results.values.every((status) => status.isGranted);
    if (allGranted) {
      LoggerService.info('All permissions granted');
    } else {
      LoggerService.warn('Some permissions denied: $results');
    }

    return results;
  }

  /// Opens the app settings page.
  Future<void> openSettings() async {
    LoggerService.info('Opening app settings');
    await openAppSettings();
  }

  /// Checks if a specific permission is granted.
  Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Checks if the app should show permission rationale.
  Future<bool> shouldShowRationale(Permission permission) async {
    return await permission.shouldShowRequestRationale;
  }

  /// Resets retry counters.
  void resetRetryCounters() {
    _cameraRequestCount = 0;
    _microphoneRequestCount = 0;
    LoggerService.debug('Permission retry counters reset');
  }

  /// Gets a user-friendly message for permanently denied permissions.
  String _getPermanentlyDeniedMessage(String permissionType) {
    switch (permissionType.toLowerCase()) {
      case 'camera':
        return 'Camera access was permanently denied. To enable it, go to Settings > SignSync > Camera and toggle it on.';
      case 'microphone':
        return 'Microphone access was permanently denied. To enable it, go to Settings > SignSync > Microphone and toggle it on.';
      default:
        return '$permissionType permission was permanently denied. Please enable it in app settings.';
    }
  }

  /// Gets a user-friendly message for exceeded retry attempts.
  String _getRetryExceededMessage(String permissionType) {
    switch (permissionType.toLowerCase()) {
      case 'camera':
        return 'Camera access is required to use this feature. Please try again or go to Settings to enable it.';
      case 'microphone':
        return 'Microphone access is required to use this feature. Please try again or go to Settings to enable it.';
      default:
        return '$permissionType permission is required. Please enable it in app settings.';
    }
  }

  /// Gets a user-friendly message for platform errors.
  String _getPlatformErrorMessage(String permissionType) {
    return 'Failed to request $permissionType permission. Please try restarting the app.';
  }

  /// Gets a user-friendly rationale message.
  Future<String> getPermissionRationale(String permissionType) async {
    switch (permissionType.toLowerCase()) {
      case 'camera':
        return 'SignSync needs camera access to recognize ASL signs and detect objects. This helps translate sign language in real-time.';
      case 'microphone':
        return 'SignSync needs microphone access to detect sounds and provide audio feedback. This enhances the accessibility experience.';
      default:
        return 'SignSync needs this permission to provide its features.';
    }
  }
}

/// Extension on PermissionStatus for easier checking.
extension PermissionStatusExtension on PermissionStatus {
  bool get isGranted => this == PermissionStatus.granted;
  bool get isDenied => this == PermissionStatus.denied;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
  bool get isLimited => this == PermissionStatus.limited;
}
