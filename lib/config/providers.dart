import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:signsync/config/app_config.dart';
import 'package:signsync/core/navigation/app_router.dart';
import 'package:signsync/core/theme/app_theme.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/camera_state.dart';
import 'package:signsync/services/asl_translation_service.dart';
import 'package:signsync/services/audio_service.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/services/chat_history_service.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/data_management_service.dart';
import 'package:signsync/services/encryption_service.dart';
import 'package:signsync/services/face_recognition_service.dart';
import 'package:signsync/services/frame_extractor.dart';
import 'package:signsync/services/gemini_ai_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';
import 'package:signsync/services/ml_inference_service.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';
import 'package:signsync/services/permission_audit_service.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/services/privacy_config_service.dart';
import 'package:signsync/services/result_cache_service.dart';
import 'package:signsync/services/secure_storage_service.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/services/yolo_detection_service.dart';

/// Root provider for the application configuration.
final appConfigProvider = ChangeNotifierProvider<AppConfig>((ref) {
  return AppConfig();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService(secureStorage: ref.read(secureStorageServiceProvider));
});

final privacyConfigServiceProvider = ChangeNotifierProvider<PrivacyConfigService>((ref) {
  final service = PrivacyConfigService();
  Future.microtask(service.initialize);
  return service;
});

final permissionAuditServiceProvider = Provider<PermissionAuditService>((ref) {
  return PermissionAuditService(encryption: ref.read(encryptionServiceProvider));
});

final resultCacheServiceProvider = ChangeNotifierProvider<ResultCacheService>((ref) {
  return ResultCacheService(encryption: ref.read(encryptionServiceProvider));
});

final dataManagementServiceProvider = Provider<DataManagementService>((ref) {
  return DataManagementService(
    chatHistory: ref.read(chatHistoryServiceProvider),
    resultCache: ref.read(resultCacheServiceProvider),
    permissionAudit: ref.read(permissionAuditServiceProvider),
    secureStorage: ref.read(secureStorageServiceProvider),
  );
});

/// Provider for the GoRouter instance.
final routerProvider = Provider<GoRouter>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  return AppRouter.createRouter(appConfig);
});

/// Provider for permissions service.
final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  return PermissionsService(auditService: ref.read(permissionAuditServiceProvider));
});

/// Provider for camera service.
final cameraServiceProvider = ChangeNotifierProvider<CameraService>((ref) {
  return CameraService();
});

/// Provider for ASL translation service (English to ASL).
final aslTranslationServiceProvider = ChangeNotifierProvider<AslTranslationService>((ref) {
  return AslTranslationService();
});

/// Provider for audio service (noise detection).
final audioServiceProvider = ChangeNotifierProvider<AudioService>((ref) {
  return AudioService();
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
  final orchestrator = ref.watch(mlOrchestratorProvider);
  return MlInferenceService(orchestrator: orchestrator);
});

/// Provider for face recognition service.
final faceRecognitionServiceProvider = ChangeNotifierProvider<FaceRecognitionService>((ref) {
  return FaceRecognitionService();
});

/// Provider for ML orchestrator service (main ML coordinator).
final mlOrchestratorServiceProvider = ChangeNotifierProvider<MlOrchestratorService>((ref) {
  final cnnService = ref.watch(cnnInferenceServiceProvider);
  final lstmService = ref.watch(lstmInferenceServiceProvider);
  final yoloService = ref.watch(yoloDetectionServiceProvider);
  final ttsService = ref.watch(ttsServiceProvider);
  final faceService = ref.watch(faceRecognitionServiceProvider);
  final resultCache = ref.watch(resultCacheServiceProvider);

  return MlOrchestratorService(
    cnnService: cnnService,
    lstmService: lstmService,
    yoloService: yoloService,
    ttsService: ttsService,
    faceService: faceService,
    resultCache: resultCache,
  );
});

/// Old provider name for backward compatibility
final mlOrchestratorProvider = mlOrchestratorServiceProvider;

/// Provider for CNN inference service (ResNet-50 for static ASL signs).
final cnnInferenceServiceProvider = ChangeNotifierProvider<CnnInferenceService>((ref) {
  return CnnInferenceService();
});

/// Provider for LSTM inference service (temporal ASL sign recognition).
final lstmInferenceServiceProvider = ChangeNotifierProvider<LstmInferenceService>((ref) {
  final cnnService = ref.watch(cnnInferenceServiceProvider);
  return LstmInferenceService(cnnService: cnnService);
});

/// Provider for YOLO detection service (real-time object detection).
final yoloDetectionServiceProvider = ChangeNotifierProvider<YoloDetectionService>((ref) {
  return YoloDetectionService();
});

/// Provider for TTS service (text-to-speech audio alerts).
final ttsServiceProvider = ChangeNotifierProvider<TtsService>((ref) {
  return TtsService();
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

/// Provider for Gemini AI service.
final geminiAiServiceProvider = ChangeNotifierProvider<GeminiAiService>((ref) {
  final ttsService = ref.watch(ttsServiceProvider);
  final privacy = ref.watch(privacyConfigServiceProvider);
  final secureStorage = ref.read(secureStorageServiceProvider);

  final service = GeminiAiService();

  Future.microtask(() async {
    if (!privacy.cloudAiEnabled) return;
    final apiKey = await secureStorage.read(key: 'gemini_api_key');
    if (apiKey == null || apiKey.isEmpty) return;

    try {
      await service.initialize(apiKey: apiKey, ttsService: ttsService);
    } catch (_) {
      // Leave uninitialized: service will fall back to offline responses.
    }
  });

  return service;
});

/// Provider for chat history service.
final chatHistoryServiceProvider = ChangeNotifierProvider<ChatHistoryService>((ref) {
  return ChatHistoryService(encryption: ref.read(encryptionServiceProvider));
});

/// Provider for current app mode (starts with Dashboard).
final appModeProvider = StateProvider<AppMode>((_) {
  return AppMode.dashboard;
});
