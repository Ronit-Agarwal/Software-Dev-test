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
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';
import 'package:signsync/services/yolo_detection_service.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/services/asl_translation_service.dart';
import 'package:signsync/services/audio_service.dart';
import 'package:signsync/services/gemini_ai_service.dart';
import 'package:signsync/services/chat_history_service.dart';
import 'package:signsync/services/storage_service.dart';
import 'package:signsync/services/model_update_service.dart';
import 'package:signsync/services/consent_service.dart';

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
final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return PermissionsService(storageService);
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
  final storageService = ref.watch(storageServiceProvider);

  return MlOrchestratorService(
    cnnService: cnnService,
    lstmService: lstmService,
    yoloService: yoloService,
    ttsService: ttsService,
    faceService: faceService,
    storageService: storageService,
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

/// Provider for storage service.
final storageServiceProvider = ChangeNotifierProvider<StorageService>((ref) {
  final service = StorageService();
  Future.microtask(() => service.initialize());
  return service;
});

/// Provider for model update service.
final modelUpdateServiceProvider = ChangeNotifierProvider<ModelUpdateService>((ref) {
  final apiService = ApiService(); // Should use provider
  return ModelUpdateService(apiService);
});

/// Provider for consent service.
final consentServiceProvider = ChangeNotifierProvider<ConsentService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final service = ConsentService(storageService);
  Future.microtask(() => service.initialize());
  return service;
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
  final service = GeminiAiService();
  
  // Initialize with TTS service for voice output
  Future.microtask(() async {
    try {
      await service.initialize(
        apiKey: '', // API key should come from secure storage
        ttsService: ttsService,
      );
    } catch (e) {
      // Initialization failed, service will use offline fallback
    }
  });
  
  return service;
});

/// Provider for chat history service.
final chatHistoryServiceProvider = ChangeNotifierProvider<ChatHistoryService>((ref) {
  final service = ChatHistoryService();
  
  Future.microtask(() async {
    await service.initialize();
  });
  
  return service;
});

/// Provider for current app mode (starts with Dashboard).
final appModeProvider = StateProvider<AppMode>((_) {
  return AppMode.dashboard;
});
