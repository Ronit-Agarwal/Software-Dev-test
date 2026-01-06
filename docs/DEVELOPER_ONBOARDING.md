# SignSync Developer Onboarding Guide

Complete setup guide for new developers joining the SignSync project.

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Running the App](#running-the-app)
- [Testing](#testing)
- [Build and Deployment](#build-and-deployment)
- [Development Workflow](#development-workflow)
- [Code Style Guidelines](#code-style-guidelines)
- [Troubleshooting](#troubleshooting)

---

## Development Environment Setup

### Prerequisites

#### Required Software
- **Flutter SDK**: 3.16.0 or later
- **Dart SDK**: 3.2.0 or later
- **Android Studio**: Latest stable version
- **Xcode**: 14.0+ (for iOS development)
- **Git**: Latest version

#### System Requirements
- **macOS**: 12.0+ (Monterey) or later
- **Windows**: Windows 10/11 with WSL2
- **Linux**: Ubuntu 20.04+ or equivalent

### Flutter Installation

#### macOS
```bash
# Install Flutter SDK
brew install flutter

# Verify installation
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses
```

#### Windows
```bash
# Download Flutter SDK from flutter.dev
# Extract to C:\flutter
# Add C:\flutter\bin to PATH

# Verify installation
flutter doctor
```

#### Linux
```bash
# Install dependencies
sudo apt update
sudo apt install git curl unzip xz-utils zip

# Download and install Flutter
cd /opt
sudo wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
sudo tar xf flutter_linux_3.16.0-stable.tar.xz
sudo mv flutter /opt/

# Add to PATH
echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
flutter doctor
```

### IDE Setup

#### Android Studio
1. Install Android Studio
2. Install Flutter and Dart plugins:
   - Go to File → Settings → Plugins
   - Search for "Flutter" and install
   - Search for "Dart" and install
3. Configure Android SDK location
4. Set up Android emulator (optional)

#### VS Code
1. Install VS Code
2. Install Flutter and Dart extensions:
   - Flutter (Dart Code)
   - Dart (Dart Code)
   - Flutter Tree (Widget structure)
3. Install additional helpful extensions:
   - GitLens
   - Error Lens
   - Flutter Widget Snippets

### Platform-Specific Setup

#### Android Development
```bash
# Install Android SDK Command-line Tools
# Set ANDROID_HOME environment variable
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin

# Create Android Virtual Device (AVD)
flutter emulators --create --name dev_avd
```

#### iOS Development (macOS only)
```bash
# Install Xcode from App Store
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Install CocoaPods
sudo gem install cocoapods

# Trust certificates
sudo gem install ffi
```

### Additional Dependencies

```bash
# Flutter dependencies
flutter pub get

# Generate code
flutter packages pub run build_runner build

# Install development tools
npm install -g @angular/cli  # For web development
```

---

## Project Structure

SignSync follows Flutter best practices with a clear separation of concerns:

```
signsync/
├── android/                 # Android-specific code
│   ├── app/
│   └── build.gradle
├── ios/                     # iOS-specific code
│   ├── Runner/
│   └── Podfile
├── lib/                     # Dart source code
│   ├── main.dart           # App entry point
│   ├── config/             # App configuration
│   │   ├── app_config.dart
│   │   └── providers.dart
│   ├── core/               # Core functionality
│   │   ├── error/          # Error handling
│   │   ├── logging/        # Logging service
│   │   ├── navigation/     # GoRouter setup
│   │   └── theme/          # App theming
│   ├── models/             # Data models
│   ├── screens/            # UI screens
│   │   ├── home/
│   │   ├── translation/
│   │   ├── detection/
│   │   ├── sound/
│   │   ├── chat/
│   │   └── settings/
│   ├── services/           # Business logic
│   ├── utils/              # Utilities
│   └── widgets/            # Reusable widgets
├── assets/                 # App assets
│   ├── images/
│   ├── models/            # ML models
│   └── fonts/
├── docs/                   # Documentation
├── test/                   # Unit tests
├── integration_test/       # Integration tests
└── scripts/               # Build and deployment scripts
```

### Key Directories

#### `/lib/core/`
Contains app-wide functionality:
- **error/**: Exception classes and error handling
- **logging/**: Structured logging system
- **navigation/**: Routing configuration
- **theme/**: App theming and styling

#### `/lib/models/`
Data models and business entities:
- `app_mode.dart`: App mode enums
- `asl_sign.dart`: ASL sign model
- `detected_object.dart`: Object detection model
- `chat_message.dart`: Chat model

#### `/lib/services/`
Business logic and external integrations:
- `ml_inference_service.dart`: ML model management
- `camera_service.dart`: Camera operations
- `audio_service.dart`: Audio processing
- `gemini_ai_service.dart`: AI assistant

#### `/lib/screens/`
UI screens organized by feature:
- `home/`: Main dashboard
- `translation/`: ASL translation mode
- `detection/`: Object detection
- `sound/`: Sound alerts
- `chat/`: AI assistant
- `settings/`: App configuration

#### `/lib/widgets/`
Reusable UI components:
- `common/`: Shared components
- `dashboard/`: Dashboard widgets
- `translation/`: Translation UI
- `detection/`: Detection UI

---

## Running the App

### Development Mode

```bash
# Clone the repository
git clone https://github.com/signsync/signsync.git
cd signsync

# Install dependencies
flutter pub get

# Generate required files
flutter packages pub run build_runner build

# Run on connected device/emulator
flutter run

# Run with specific device
flutter run -d <device-id>

# Hot reload during development
flutter run --hot
```

### Platform-Specific Running

#### Android
```bash
# Start Android emulator
flutter emulators --launch dev_avd

# Run on Android
flutter run -d android

# Run with debug logging
flutter run --debug
```

#### iOS (macOS only)
```bash
# Open iOS simulator
open -a Simulator

# Run on iOS
flutter run -d ios

# Run on physical device
flutter run -d <device-id>
```

### Running with Features

#### Demo Mode (No External Dependencies)
```bash
# Run without Firebase/AI services
flutter run --dart-define=USE_DEMO_MODE=true
```

#### With AI Services
```bash
# Set environment variables
export GEMINI_API_KEY="your-api-key"
export GOOGLE_TRANSLATE_API_KEY="your-api-key"

# Run with AI features
flutter run --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

#### With Firebase
```bash
# Download Firebase config files
# Place GoogleService-Info.plist in ios/Runner/
# Place google-services.json in android/app/

# Run with Firebase
flutter run --dart-define=USE_FIREBASE=true
```

---

## Testing

### Unit Tests

```bash
# Run all unit tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/ml_inference_service_test.dart

# Run tests in watch mode
flutter test --watch
```

### Widget Tests

```bash
# Run widget tests
flutter test test/widgets/

# Run specific widget test
flutter test test/widgets/translation_display_test.dart
```

### Integration Tests

```bash
# Run integration tests
flutter test integration_test/

# Run specific integration test
flutter test integration_test/app_test.dart

# Run on specific platform
flutter test integration_test/ -d android
```

### Test Coverage

```bash
# Generate coverage report
flutter test --coverage

# View coverage in browser
genhtml coverage/lcov.info -o coverage/html
```

### Test Structure

Tests are organized to match source structure:
```
test/
├── services/
│   ├── ml_inference_service_test.dart
│   ├── camera_service_test.dart
│   └── audio_service_test.dart
├── widgets/
│   ├── translation_display_test.dart
│   └── camera_preview_test.dart
├── models/
│   ├── asl_sign_test.dart
│   └── detected_object_test.dart
└── app_test.dart (integration)
```

---

## Build and Deployment

### Debug Builds

```bash
# Android debug APK
flutter build apk --debug

# iOS debug build
flutter build ios --debug

# Web debug build
flutter build web --debug
```

### Release Builds

#### Android
```bash
# App Bundle (recommended for Play Store)
flutter build appbundle --release

# APK for direct distribution
flutter build apk --release

# Split APKs by architecture
flutter build apk --release --split-per-abi
```

#### iOS
```bash
# iOS App Store build
flutter build ios --release

# Archive for App Store
flutter build ipa
```

#### Web
```bash
# Production web build
flutter build web --release

# With specific renderer
flutter build web --release --web-renderer canvaskit
```

### Code Signing

#### Android
```bash
# Generate keystore
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Configure signing in android/app/build.gradle
android {
    signingConfigs {
        release {
            storeFile file('~/upload-keystore.jks')
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias "upload"
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
}
```

#### iOS
1. Configure signing in Xcode
2. Add development team and provisioning profile
3. For CI/CD, use `fastlane` or GitHub Actions

### Environment Configuration

#### Development
```bash
# Use development endpoints
flutter run --dart-define=ENVIRONMENT=development
```

#### Staging
```bash
# Use staging environment
flutter build apk --dart-define=ENVIRONMENT=staging
```

#### Production
```bash
# Production build
flutter build appbundle --dart-define=ENVIRONMENT=production
```

---

## Development Workflow

### Git Workflow

#### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/*`: Individual feature branches
- `hotfix/*`: Emergency fixes
- `release/*`: Release preparation

#### Standard Workflow
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "feat: add new feature"

# Push and create PR
git push origin feature/new-feature

# After review, merge to develop
# After testing, merge to main
```

#### Commit Message Format
```
type(scope): description

feat(translation): add dynamic sign recognition
fix(camera): resolve permission issue on Android
docs(api): update service documentation
test(ml): add LSTM model tests
```

### Code Quality

#### Linting
```bash
# Run linter
flutter analyze

# Fix auto-fixable issues
flutter analyze --fix

# Check specific file
flutter analyze lib/services/camera_service.dart
```

#### Formatting
```bash
# Format all code
flutter format .

# Format specific file
flutter format lib/main.dart
```

#### Code Generation
```bash
# Generate Riverpod providers
flutter packages pub run build_runner build

# Watch for changes (during development)
flutter packages pub run build_runner watch
```

### Pull Request Process

1. **Create Feature Branch**
   - Use descriptive branch name
   - Include issue number if applicable

2. **Implement Changes**
   - Follow coding standards
   - Add tests for new functionality
   - Update documentation

3. **Run Quality Checks**
   - `flutter analyze` - No linting errors
   - `flutter test` - All tests pass
   - `flutter format` - Code formatted

4. **Create Pull Request**
   - Clear description of changes
   - Link related issues
   - Include screenshots for UI changes

5. **Code Review**
   - Address reviewer feedback
   - Update PR as needed
   - Ensure CI checks pass

6. **Merge**
   - Squash commits if requested
   - Delete feature branch after merge

---

## Code Style Guidelines

### Dart Style Guide

#### Naming Conventions
```dart
// Classes and enums: PascalCase
class CameraService {}
enum AppMode {}

// Methods and variables: camelCase
void startCamera() {}
String currentError;

// Constants: SCREAMING_SNAKE_CASE
static const Duration TIMEOUT = Duration(seconds: 10);
final int MAX_RETRY_COUNT = 3;

// Private members: prefix with underscore
class _PrivateClass {}
String _privateVariable;
```

#### File Organization
```dart
// 1. Imports (standard, third-party, local)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signsync/models/asl_sign.dart';

// 2. Class definition
class AslTranslationService {
  // 3. Constants
  static const Duration DEFAULT_TIMEOUT = Duration(seconds: 5);
  
  // 4. Private fields
  final MlInferenceService _mlService;
  
  // 5. Public properties
  bool get isInitialized => _mlService.isModelLoaded;
  
  // 6. Constructor
  AslTranslationService({required MlInferenceService mlService})
      : _mlService = mlService;
  
  // 7. Public methods
  Future<String> translateSign(AslSign sign) async {
    // Implementation
  }
  
  // 8. Private methods
  String _processTranslation(String rawTranslation) {
    // Implementation
  }
}
```

#### Documentation
```dart
/// Service for ASL sign translation.
///
/// This service handles the translation of detected ASL signs into
/// human-readable text using machine learning models.
///
/// ## Usage
/// ```dart
/// final translator = AslTranslationService(mlService: mlService);
/// final translation = await translator.translateSign(sign);
/// print('Translated: $translation');
/// ```
class AslTranslationService {
  /// Translates an ASL sign to text.
  ///
  /// Takes a detected ASL sign and returns the corresponding text
  /// translation. Handles both static signs (letters) and dynamic
  /// signs (words and phrases).
  ///
  /// [sign] The ASL sign to translate, must not be null.
  ///
  /// Returns a [Future] that completes with the translated text,
  /// or throws [TranslationException] if translation fails.
  Future<String> translateSign(AslSign sign) async {
    // Implementation
  }
}
```

### Flutter-Specific Guidelines

#### Widgets
```dart
/// A custom widget for displaying ASL translation results.
///
/// This widget shows the recognized sign, its confidence level,
/// and provides options to save or share the translation.
class TranslationDisplay extends ConsumerWidget {
  const TranslationDisplay({
    super.key,
    required this.sign,
  });

  final AslSign sign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sign.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Confidence: ${(sign.confidence * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

#### State Management (Riverpod)
```dart
// Provider
@riverpod
class CameraController extends _$CameraController {
  @override
  Future<CameraState> build() async {
    return await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Implementation
  }
}

// Consumer
class CameraScreen extends ConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraControllerProvider);
    
    return cameraState.when(
      loading: () => const CircularProgressIndicator(),
      data: (state) => CameraPreview(controller: state.controller),
      error: (error, stack) => ErrorWidget(error.toString()),
    );
  }
}
```

#### Error Handling
```dart
/// Initializes the camera with comprehensive error handling.
///
/// Handles permission denials, device unavailability, and other
/// camera-related issues with user-friendly messages.
Future<void> initializeCamera() async {
  try {
    // Check permissions first
    final permission = await _permissionsService.requestCameraPermission();
    if (permission != PermissionStatus.granted) {
      throw PermissionException(
        'Camera permission is required for ASL translation',
        userMessage: 'Please enable camera permission in Settings',
      );
    }

    // Initialize camera
    await _cameraController.initialize();
    
    LoggerService.info('Camera initialized successfully');
  } on PermissionException catch (e) {
    _handlePermissionError(e);
    rethrow;
  } on CameraException catch (e) {
    LoggerService.error('Camera initialization failed', error: e);
    throw CameraException('Failed to initialize camera: ${e.message}');
  } catch (e, stack) {
    LoggerService.error('Unexpected error during camera init', error: e, stack: stack);
    rethrow;
  }
}
```

---

## Troubleshooting

### Common Development Issues

#### Flutter Doctor Issues
```bash
# Check Flutter installation
flutter doctor -v

# Fix Android licenses
flutter doctor --android-licenses

# Update Flutter
flutter upgrade
```

#### Build Errors
```bash
# Clean build cache
flutter clean
flutter pub get
flutter packages pub run build_runner build

# Clean platform builds
cd android && ./gradlew clean && cd ..
cd ios && rm -rf build/ && pod install && cd ..
```

#### Dependencies Issues
```bash
# Update dependencies
flutter pub upgrade

# Clean pub cache
flutter pub cache clean
flutter pub get

# Check for outdated packages
flutter pub outdated
```

#### Hot Reload Issues
```bash
# Restart Flutter daemon
flutter daemon

# Or restart IDE and Flutter process
```

#### iOS Build Issues
```bash
# Clean iOS build
cd ios
rm -rf build/
rm -rf Pods/
rm Podfile.lock
pod install
cd ..

# Reset Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### Android Build Issues
```bash
# Clean Android build
cd android
./gradlew clean
cd ..

# Clear Android build cache
rm -rf ~/.gradle/caches/
```

### Performance Issues

#### Slow Build Times
```bash
# Enable build caching
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub global activate flutter_devtools
flutter pub global run devtools
```

#### Large App Size
```bash
# Analyze app size
flutter build apk --analyze-size
flutter build ios --analyze-size

# Enable code shrinking
flutter build apk --release --obfuscate --split-debug-info=build/debug-info/
```

### Testing Issues

#### Tests Not Running
```bash
# Ensure test dependency is in pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0

# Regenerate test files
flutter packages pub run build_runner build
```

#### Mock Issues
```dart
// Use mockito for mocking dependencies
@GenerateMocks([CameraService, MlInferenceService])
import 'camera_service_test.mocks.dart';

// In tests
final mockCameraService = MockCameraService();
when(mockCameraService.initialize()).thenAnswer((_) async {});
```

### IDE Issues

#### VS Code Problems
```bash
# Reload VS Code window
Cmd+Shift+P → "Developer: Reload Window"

# Clear Dart analysis cache
Cmd+Shift+P → "Dart: Restart Analysis Server"
```

#### Android Studio Issues
```bash
# Invalidate caches
File → Invalidate Caches / Restart

# Clear Flutter build cache
flutter clean
```

### Getting Help

1. **Check Flutter Documentation**: https://flutter.dev/docs
2. **Search Existing Issues**: Check GitHub issues first
3. **Ask on Discord**: Flutter community Discord
4. **Create Detailed Issue**: Include Flutter doctor output, error logs, reproduction steps

### Useful Commands

```bash
# Get help on any Flutter command
flutter --help <command>

# List available devices
flutter devices

# Show Flutter version info
flutter --version

# Check pub packages
flutter pub deps

# Format Dart code
flutter format <file-or-directory>

# Run tests with verbose output
flutter test -v
```

---

## Next Steps

After completing this setup guide:

1. **Explore the codebase**: Start with `lib/main.dart`
2. **Run the app**: Follow the "Running the App" section
3. **Read documentation**: Check `docs/` folder for detailed docs
4. **Check existing issues**: Look for good first issues on GitHub
5. **Join the team**: Introduce yourself in the team chat
6. **Start contributing**: Pick a small issue to fix

## Resources

- **Flutter Documentation**: https://flutter.dev/docs
- **Dart Language Tour**: https://dart.dev/guides/language/language-tour
- **Riverpod Documentation**: https://riverpod.dev
- **SignSync GitHub**: https://github.com/signsync/signsync
- **Team Wiki**: Internal team documentation
- **API Documentation**: `docs/API_DOCUMENTATION.md`

Welcome to the SignSync team! 🎉