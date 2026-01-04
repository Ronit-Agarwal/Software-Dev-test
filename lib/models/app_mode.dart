import 'package:equatable/equatable.dart';

/// Represents the current mode of the application.
///
/// The app operates in different modes based on the user's
/// selected functionality: Dashboard, ASL translation, object detection, sound alerts, or AI chat.
enum AppMode {
  dashboard('Dashboard', 'Overview and quick actions'),
  translation('ASL Translation', 'Translate ASL signs to text'),
  detection('Object Detection', 'Identify objects in your surroundings'),
  sound('Sound Alerts', 'Detect and alert for important sounds'),
  chat('AI Chat', 'Chat with AI about sign language'),
  settings('Settings', 'App configuration and preferences');

  final String displayName;
  final String description;

  const AppMode(this.displayName, this.description);

  /// Returns the route path for this mode.
  String get routePath {
    switch (this) {
      case AppMode.dashboard:
        return '/dashboard';
      case AppMode.translation:
        return '/translation';
      case AppMode.detection:
        return '/detection';
      case AppMode.sound:
        return '/sound';
      case AppMode.chat:
        return '/chat';
      case AppMode.settings:
        return '/settings';
    }
  }

  /// Returns the route name for this mode.
  String get routeName {
    switch (this) {
      case AppMode.dashboard:
        return 'dashboard';
      case AppMode.translation:
        return 'translation';
      case AppMode.detection:
        return 'detection';
      case AppMode.sound:
        return 'sound';
      case AppMode.chat:
        return 'chat';
      case AppMode.settings:
        return 'settings';
    }
  }

  /// Returns the navigation index for this mode.
  int get navigationIndex {
    switch (this) {
      case AppMode.dashboard:
        return 0;
      case AppMode.translation:
        return 1;
      case AppMode.detection:
        return 2;
      case AppMode.sound:
        return 3;
      case AppMode.chat:
        return 4;
      case AppMode.settings:
        return 5;
    }
  }

  /// Gets the next mode in the navigation order.
  AppMode get next {
    switch (this) {
      case AppMode.dashboard:
        return AppMode.translation;
      case AppMode.translation:
        return AppMode.detection;
      case AppMode.detection:
        return AppMode.sound;
      case AppMode.sound:
        return AppMode.chat;
      case AppMode.chat:
        return AppMode.settings;
      case AppMode.settings:
        return AppMode.dashboard;
    }
  }

  /// Gets the previous mode in the navigation order.
  AppMode get previous {
    switch (this) {
      case AppMode.dashboard:
        return AppMode.settings;
      case AppMode.translation:
        return AppMode.dashboard;
      case AppMode.detection:
        return AppMode.translation;
      case AppMode.sound:
        return AppMode.detection;
      case AppMode.chat:
        return AppMode.sound;
      case AppMode.settings:
        return AppMode.chat;
    }
  }

  /// Returns the mode from a navigation index.
  static AppMode fromNavigationIndex(int index) {
    switch (index) {
      case 0:
        return AppMode.dashboard;
      case 1:
        return AppMode.translation;
      case 2:
        return AppMode.detection;
      case 3:
        return AppMode.sound;
      case 4:
        return AppMode.chat;
      case 5:
        return AppMode.settings;
      default:
        return AppMode.dashboard;
    }
  }

  /// Returns the mode from a route path.
  static AppMode fromRoutePath(String path) {
    switch (path) {
      case '/dashboard':
        return AppMode.dashboard;
      case '/translation':
        return AppMode.translation;
      case '/detection':
        return AppMode.detection;
      case '/sound':
        return AppMode.sound;
      case '/chat':
        return AppMode.chat;
      case '/settings':
        return AppMode.settings;
      default:
        return AppMode.dashboard;
    }
  }
}

/// State for the inference service.
class InferenceState with EquatableMixin {
  final bool isActive;
  final bool isProcessing;
  final DateTime? lastInferenceTime;
  final String? error;

  const InferenceState({
    this.isActive = false,
    this.isProcessing = false,
    this.lastInferenceTime,
    this.error,
  });

  /// Creates an inactive state.
  factory InferenceState.inactive() {
    return const InferenceState();
  }

  /// Creates an active/processing state.
  factory InferenceState.processing() {
    return const InferenceState(
      isActive: true,
      isProcessing: true,
    );
  }

  /// Creates a state with an error.
  factory InferenceState.error(String error) {
    return InferenceState(
      isActive: false,
      isProcessing: false,
      error: error,
    );
  }

  /// Creates a successful inference state.
  factory InferenceState.success() {
    return InferenceState(
      isActive: true,
      isProcessing: false,
      lastInferenceTime: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [isActive, isProcessing, lastInferenceTime, error];

  InferenceState copyWith({
    bool? isActive,
    bool? isProcessing,
    DateTime? lastInferenceTime,
    String? error,
  }) {
    return InferenceState(
      isActive: isActive ?? this.isActive,
      isProcessing: isProcessing ?? this.isProcessing,
      lastInferenceTime: lastInferenceTime ?? this.lastInferenceTime,
      error: error ?? this.error,
    );
  }
}

/// Result from ML inference.
class InferenceResult with EquatableMixin {
  final dynamic data;
  final double confidence;
  final DateTime timestamp;
  final String? error;

  const InferenceResult({
    this.data,
    this.confidence = 0.0,
    DateTime? timestamp,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a result with data.
  factory InferenceResult.success({
    required dynamic data,
    double confidence = 1.0,
  }) {
    return InferenceResult(
      data: data,
      confidence: confidence,
    );
  }

  /// Creates a result with an error.
  factory InferenceResult.error(String error) {
    return InferenceResult(error: error);
  }

  /// Returns true if this is a successful result.
  bool get isSuccess => error == null && data != null;

  @override
  List<Object?> get props => [data, confidence, timestamp, error];
}
