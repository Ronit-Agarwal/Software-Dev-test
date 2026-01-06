/// Global constants used throughout the app.
///
/// This file contains all hardcoded values to ensure consistency
/// and make updates easier.
class AppConstants {
  // App Info
  static const String appName = 'SignSync';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Legal
  static const String privacyPolicyUrl = 'https://signsync.app/legal/privacy';
  static const String termsOfServiceUrl = 'https://signsync.app/legal/terms';
  static const String supportEmail = 'support@signsync.app';

  // API
  static const String apiBaseUrl = 'https://api.signsync.app/v1';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int apiMaxRetries = 3;

  // ML Inference
  static const double inferenceConfidenceThreshold = 0.6;
  static const int inferenceFps = 30;
  static const Duration inferenceTimeout = Duration(seconds: 5);

  // Camera
  static const ResolutionPreset cameraResolution = ResolutionPreset.medium;
  static const int cameraFps = 30;

  // Audio
  static const double audioNoiseThreshold = 0.3;
  static const int audioSampleRate = 16000;
  static const int audioBufferSize = 1024;

  // Animation
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration quickAnimationDuration = Duration(milliseconds: 150);

  // Spacing
  static const double spacingXxs = 4.0;
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Corner Radius
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusCircular = 50.0;

  // Icons
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  // Touch Targets
  static const double minTouchTarget = 44.0;
  static const double recommendedTouchTarget = 48.0;

  // Text
  static const double textScaleMin = 0.8;
  static const double textScaleMax = 2.0;
  static const double textScaleDefault = 1.0;

  // Delays
  static const Duration debounceDelay = Duration(milliseconds: 300);
  static const Duration throttleDelay = Duration(milliseconds: 500);

  // Limits
  static const int maxChatHistory = 50;
  static const int maxDetectedObjects = 10;
  static const int maxSignHistory = 100;

  // Feature Flags
  static const bool enableObjectDetection = true;
  static const bool enableSoundAlerts = true;
  static const bool enableChatFeature = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
}

/// Supported locales for the app.
class AppLocales {
  static const List<Locale> supported = [
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('zh'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
  ];

  static const String english = 'en';
  static const String spanish = 'es';
  static const String french = 'fr';
  static const String german = 'de';
  static const String chinese = 'zh';
  static const String japanese = 'ja';
  static const String korean = 'ko';
  static const String portuguese = 'pt';

  /// Gets the display name for a locale.
  static String getDisplayName(String code) {
    switch (code) {
      case english:
        return 'English';
      case spanish:
        return 'Español';
      case french:
        return 'Français';
      case german:
        return 'Deutsch';
      case chinese:
        return '中文';
      case japanese:
        return '日本語';
      case korean:
        return '한국어';
      case portuguese:
        return 'Português';
      default:
        return code;
    }
  }
}

/// Route paths for the app.
class AppRoutes {
  static const String home = '/';
  static const String translation = '/translation';
  static const String detection = '/detection';
  static const String sound = '/sound';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String permission = '/permission';
}

/// Navigation indices for bottom navigation.
class NavIndices {
  static const int translation = 0;
  static const int detection = 1;
  static const int sound = 2;
  static const int chat = 3;
}

/// Camera resolution presets.
enum ResolutionPreset {
  low,
  medium,
  high,
  veryHigh,
  ultraHigh,
}

/// Session timeout settings.
class SessionTimeouts {
  static const Duration camera = Duration(minutes: 5);
  static const Duration audio = Duration(minutes: 5);
  static const Duration chat = Duration(hours: 1);
  static const Duration app = Duration(hours: 4);
}
