# SignSync

A production-grade Flutter application providing real-time ASL sign language translation, object detection, and sound alerts for accessibility.

## Key Features

- **ASL Translation**: Real-time sign recognition using CNN and LSTM models
  - Static signs: A-Z alphabet and numbers
  - Dynamic signs: Multi-sign sequences and phrases
  - 15-20 FPS processing with confidence scoring
- **Object Detection**: YOLO-based object recognition for accessibility
  - 80+ common object classes
  - Spatial audio positioning
  - Priority-based alert system
- **Sound Detection**: Environmental audio monitoring
  - Important sound alerts (doorbells, alarms)
  - Customizable sensitivity
  - Multi-modal feedback (visual, audio, haptic)
- **AI Assistant**: Google Gemini-powered chat support
  - ASL learning assistance
  - Voice input/output
  - Contextual help and guidance

## Quick Start

### Prerequisites
- Flutter 3.16.0+
- Dart 3.2.0+
- Android Studio / VS Code / Xcode
- iOS 13.0+ / Android 5.0+

### Installation

```bash
# Clone repository
git clone https://github.com/signsync/signsync.git
cd signsync

# Install dependencies
flutter pub get

# Generate required files
flutter packages pub run build_runner build

# Run on device/emulator
flutter run
```

### Optional Setup

**ML Models**: Place TFLite models in `assets/models/`:
- `asl_cnn.tflite` - CNN model for static signs
- `asl_lstm.tflite` - LSTM model for sequences  
- `yolo_detection.tflite` - YOLO model for objects

**AI Services**: Add API keys for enhanced features:
- Google Gemini API key for AI assistant
- Firebase configuration (optional)

See [docs/DEVELOPER_ONBOARDING.md](docs/DEVELOPER_ONBOARDING.md) for detailed setup instructions.

## Documentation

- [User Guide](docs/USER_GUIDE.md) - Complete user documentation
- [API Documentation](docs/API_DOCUMENTATION.md) - Service API reference
- [Developer Onboarding](docs/DEVELOPER_ONBOARDING.md) - Development setup
- [Architecture Overview](docs/ARCHITECTURE_OVERVIEW.md) - System design
- [Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md) - Common issues and solutions
- [Contributing Guidelines](CONTRIBUTING.md) - Contribution process

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/                   # Configuration
├── core/                     # Core functionality
├── models/                   # Data models
├── screens/                  # UI screens
├── services/                 # Business logic
├── utils/                    # Utilities
└── widgets/                  # Reusable components
```

## Development

### Testing

```bash
# Unit tests
flutter test

# Widget tests  
flutter test test/widgets/

# Integration tests
flutter test integration_test/

# With coverage
flutter test --coverage
```

### Code Quality

```bash
# Format code
flutter format .

# Analyze code
flutter analyze

# Generate code
flutter packages pub run build_runner build
```

### Building

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
flutter build ipa

# Web
flutter build web --release
```

## Performance

- **ASL Recognition**: 45ms inference time, 94.7% accuracy
- **Object Detection**: 85ms inference time, 52.7% mAP
- **Memory Usage**: 120-210MB depending on features
- **Battery**: Optimized for mobile devices

See [docs/ML_MODEL_DOCUMENTATION.md](docs/ML_MODEL_DOCUMENTATION.md) for detailed performance metrics.

## Accessibility

- WCAG 2.1 AA compliant
- Screen reader support (TalkBack/VoiceOver)
- High contrast mode
- Adjustable text sizes
- Keyboard navigation
- Haptic feedback

## Support

- [GitHub Issues](https://github.com/signsync/signsync/issues) - Bug reports and features
- [User Guide](docs/USER_GUIDE.md) - Detailed usage instructions
- [Troubleshooting](docs/TROUBLESHOOTING_GUIDE.md) - Common issues

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

We welcome contributions! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

Key areas for contribution:
- Accessibility improvements
- Performance optimizations
- Bug fixes
- Documentation updates
- Test coverage

## Privacy

- Face recognition data stored locally only
- Chat history optionally synced with user consent
- ML models run on-device for privacy
- No personal data shared with external services
