# SignSync

A production-grade Flutter application for ASL sign language translation, object detection, and sound alerts.

## Features

- **ASL Translation**: Real-time ASL sign detection and translation
  - Static sign recognition using ResNet-50 CNN (A-Z + common words)
  - Dynamic sign recognition using LSTM (multi-sign sequences)
  - FP16 quantized models for efficient inference
  - 15-20 FPS with <100ms latency
  - Confidence threshold filtering (0.85+)
  - Temporal smoothing (3-5 frame window)
- **Object Detection**: Identify objects in your surroundings using camera
- **Sound Alerts**: Detect and notify for important sounds
- **AI Chat**: Chat with SignSync AI about sign language
- **Accessibility First**: WCAG AAA compliant, high contrast mode, screen reader support

## Getting Started

### Prerequisites

- Flutter 3.x+
- Dart 3.x+
- iOS 13+ / Android 21+

### Installation

1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter pub run build_runner build` to generate required files
4. Set up ML models (optional - see ML Model Setup below)
5. Set up Firebase (optional - see Firebase Setup)
6. Run `flutter run`

### ML Model Setup

The app requires TFLite models for ASL sign recognition. See [docs/MODEL_SETUP.md](docs/MODEL_SETUP.md) for detailed instructions:

1. **Option A: Use Pre-trained Models** (if available in project releases)
   - Download models from releases
   - Place `asl_cnn.tflite` in `assets/models/`

2. **Option B: Train Your Own Models**
   - Follow [docs/MODEL_SETUP.md](docs/MODEL_SETUP.md) for conversion
   - Train ResNet-50 CNN on ASL alphabet dataset
   - Convert to TFLite with FP16 quantization

3. **Option C: Run in Demo Mode**
   - The app will run without models for testing UI
   - ML features will show placeholder results

### Firebase Setup (Optional)

The app works in demo mode without Firebase. To enable Firebase features:

1. Create a Firebase project at https://console.firebase.google.com
2. Add iOS and Android apps with bundle/package ID: `com.signsync.app`
3. Download configuration files:
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Android: `google-services.json` → `android/app/`
4. Uncomment Firebase initialization in `lib/main.dart`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/                   # App configuration
│   ├── app_config.dart       # User settings
│   └── providers.dart        # Riverpod providers
├── core/                     # Core functionality
│   ├── error/                # Error handling
│   ├── logging/              # Logging service
│   ├── navigation/           # GoRouter setup
│   └── theme/                # App theming
├── models/                   # Data models
│   ├── asl_sign.dart         # ASL sign model
│   ├── app_mode.dart         # App mode enum
│   ├── chat_message.dart     # Chat model
│   ├── detected_object.dart  # Object detection model
│   └── noise_event.dart      # Sound event model
├── screens/                  # UI screens
│   ├── home/                 # Home screen
│   ├── translation/          # ASL translation
│   ├── detection/            # Object detection
│   ├── sound/                # Sound alerts
│   ├── chat/                 # AI chat
│   └── settings/             # Settings
├── services/                 # Business logic
│   ├── api_service.dart      # API calls
│   ├── audio_service.dart    # Audio processing
│   ├── camera_service.dart   # Camera management
│   ├── ml_inference_service.dart  # ML inference
│   └── permissions_service.dart   # Permissions
├── utils/                    # Utilities
│   ├── constants.dart        # App constants
│   ├── extensions.dart       # Dart extensions
│   └── helpers.dart          # Helper functions
└── widgets/                  # Reusable widgets
    └── common/               # Common widgets
```

## Dependencies

### State Management
- `flutter_riverpod` - State management
- `riverpod_generator` - Code generation for providers

### Navigation
- `go_router` - Declarative routing

### Firebase
- `firebase_core` - Firebase initialization
- `firebase_analytics` - Analytics

### Error Tracking
- `sentry_flutter` - Crash reporting
- `logger` - Structured logging

### Camera & ML
- `camera` - Camera access
- `google_mlkit_image_labeling` - Image labeling
- `google_mlkit_pose_detection` - Pose detection
- `tflite_flutter` - TensorFlow Lite

### Audio
- `flutter_sound` - Audio recording

### Platform Services
- `permission_handler` - Runtime permissions
- `path_provider` - File paths
- `shared_preferences` - Local storage

### Utilities
- `intl` - Localization
- `uuid` - Unique IDs
- `equatable` - Value equality

## Configuration

### Platform-Specific Permissions

#### iOS (Info.plist)
- Camera: `NSCameraUsageDescription`
- Microphone: `NSMicrophoneUsageDescription`
- Photo Library: `NSPhotoLibraryUsageDescription`

#### Android (AndroidManifest.xml)
- Camera: `android.permission.CAMERA`
- Microphone: `android.permission.RECORD_AUDIO`
- Storage: `android.permission.READ_EXTERNAL_STORAGE`

## Accessibility

- **Screen Readers**: Full Semantic widget support
- **High Contrast**: Toggle in Settings
- **Text Scaling**: Support for 0.8x to 2.0x
- **Haptic Feedback**: Vibration on actions
- **Minimum Touch Targets**: 44x44dp

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Generate code
flutter pub run build_runner build
```

## Versioning

This project uses semantic versioning. See [CHANGELOG.md](CHANGELOG.md) for details.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## Support

For issues and feature requests, please create a GitHub issue.
