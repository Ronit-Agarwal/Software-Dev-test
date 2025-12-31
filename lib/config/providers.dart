import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/core/navigation/app_router.dart';
import 'package:signsync/core/theme/app_theme.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/camera_state.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/services/frame_extractor.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';

/// Root provider for the application configuration.
final appConfigProvider = ChangeNotifierProvider<AppConfig>((ref) {
  return AppConfig();
});

/// Provider for the GoRouter instance.
final routerProvider = Provider<GoRouter>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  return AppRouter.createRouter(appConfig);
});

/// Provider for permissions service.
final permissionsServiceProvider = Provider<PermissionsService>((_) {
  return PermissionsService();
});

/// Provider for camera service.
final cameraServiceProvider = ChangeNotifierProvider<CameraService>((ref) {
  return CameraService();
});

/// Provider for frame extractor service.
final frameExtractorProvider = ChangeNotifierProvider<FrameExtractor>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);

  return FrameExtractor(
    onFrame: (frame) {
      // Frames are processed and added to the buffer
      // ML inference will consume from this buffer
    },
    onPerformanceUpdate: (metrics) {
      // Handle performance updates
    },
  );
});

/// Provider for camera initialization state.
final cameraInitializedProvider = Provider<bool>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.isInitialized;
});

/// Provider for camera streaming state.
final cameraStreamingProvider = Provider<bool>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.isStreaming;
});

/// Provider for camera state.
final cameraStateProvider = Provider<CameraState>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.state;
});

/// Provider for camera FPS.
final cameraFpsProvider = Provider<double>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.currentFps;
});

/// Provider for frame extractor performance metrics.
final framePerformanceProvider = Provider<FramePerformanceMetrics>((ref) {
  final frameExtractor = ref.watch(frameExtractorProvider);
  return frameExtractor.performanceMetrics;
});

/// Provider for ML inference service.
final mlInferenceServiceProvider = ChangeNotifierProvider<MlInferenceService>((ref) {
  return MlInferenceService();
});

/// Provider for ML orchestrator service (main ML coordinator).
final mlOrchestratorProvider = ChangeNotifierProvider<MlOrchestratorService>((ref) {
  return MlOrchestratorService();
});

/// Provider for latest ML result.
final mlResultProvider = Provider<MlResult?>((ref) {
  final orchestrator = ref.watch(mlOrchestratorProvider);
  // Return the most recent result based on current mode
  switch (orchestrator.currentMode) {
    case AppMode.translation:
      return orchestrator.latestDynamicSign != null 
          ? MlResult.asl(dynamicSign: orchestrator.latestDynamicSign)
          : (orchestrator.latestAslSign != null
              ? MlResult.asl(staticSign: orchestrator.latestAslSign)
              : null);
    case AppMode.detection:
      return orchestrator.latestDetection != null
          ? MlResult.detection(frame: orchestrator.latestDetection!)
          : null;
    default:
      return null;
  }
});

/// Provider for ML performance metrics.
final mlPerformanceProvider = Provider<Map<String, dynamic>>((ref) {
  final orchestrator = ref.watch(mlOrchestratorProvider);
  return orchestrator.performanceMetrics;
});

/// Provider for the current app mode.
final appModeProvider = StateProvider<AppMode>((_) {
  return AppMode.translation;
});

/// Provider for the latest inference result.
final inferenceResultProvider = Provider<InferenceResult?>((ref) {
  final mlService = ref.watch(mlInferenceServiceProvider);
  return mlService.latestResult;
});

/// Provider for permission status.
final permissionStatusProvider = Provider<PermissionStatus>((ref) {
  final permissionsService = ref.watch(permissionsServiceProvider);
  return permissionsService.overallStatus;
});

/// Provider for checking if all required permissions are granted.
final allPermissionsGrantedProvider = Provider<bool>((ref) {
  final permissionsService = ref.watch(permissionsServiceProvider);
  return permissionsService.allPermissionsGranted;
});

/// Provider for high contrast mode.
final highContrastModeProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.highContrastMode;
});

/// Provider for theme data based on current settings.
final themeDataProvider = Provider<ThemeData>((ref) {
  final config = ref.watch(appConfigProvider);
  final isHighContrast = config.highContrastMode;

  if (isHighContrast) {
    return config.themeMode == ThemeMode.dark
        ? AppTheme.highContrastDarkTheme
        : AppTheme.highContrastLightTheme;
  }

  switch (config.themeMode) {
    case ThemeMode.light:
      return AppTheme.lightTheme;
    case ThemeMode.dark:
      return AppTheme.darkTheme;
    case ThemeMode.system:
      return AppTheme.lightTheme;
  }
});
