# Contributing to SignSync

Thank you for your interest in contributing to SignSync! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Contribution Guidelines](#contribution-guidelines)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Accessibility Guidelines](#accessibility-guidelines)
- [Release Process](#release-process)

---

## Code of Conduct

### Our Pledge

We are committed to making SignSync a welcoming and inclusive project for everyone. We pledge to make participation in this project a harassment-free experience for everyone.

### Standards

**Encouraged Behavior:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable Behavior:**
- Trolling, insulting/derogatory comments
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

### Enforcement

Instances of unacceptable behavior may be reported to the project team. All complaints will be reviewed and investigated promptly and fairly.

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Flutter SDK**: 3.16.0 or later
- **Dart SDK**: 3.2.0 or later
- **Development Environment**: Android Studio, VS Code, or Xcode
- **Git**: Latest version
- **Device/Emulator**: For testing changes

### First-Time Setup

1. **Fork the Repository**
   ```bash
   git clone https://github.com/your-username/signsync.git
   cd signsync
   ```

2. **Set Up Development Environment**
   ```bash
   # Install dependencies
   flutter pub get
   
   # Generate required files
   flutter packages pub run build_runner build
   
   # Run tests to verify setup
   flutter test
   ```

3. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Finding Issues

**Good First Issues:**
- Look for issues labeled `good first issue`
- These are typically small fixes or documentation updates
- They help you learn the codebase

**Help Wanted:**
- Issues labeled `help wanted` need assistance
- More complex than good first issues
- Great for learning while contributing

**Accessibility Issues:**
- We prioritize accessibility improvements
- Look for `accessibility` labels
- High impact on user experience

---

## Development Workflow

### Branch Naming Convention

Use descriptive branch names:
- `feature/asl-translation-improvements`
- `fix/camera-permission-issues`
- `docs/api-documentation-update`
- `test/add-object-detection-tests`
- `refactor/camera-service-cleanup`

### Commit Messages

Follow conventional commits format:
```
type(scope): description

feat(translation): add dynamic sign recognition
fix(camera): resolve permission issue on Android
docs(api): update service documentation
test(ml): add LSTM model tests
refactor(ui): simplify translation display
style(widget): format camera preview code
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding tests
- `refactor`: Code refactoring
- `style`: Formatting, missing semi colons, etc
- `chore`: Maintenance tasks

### Development Process

1. **Choose an Issue**
   - Comment on the issue to claim it
   - Wait for assignment or confirmation

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/descriptive-name
   ```

3. **Make Changes**
   - Follow coding standards
   - Add tests for new functionality
   - Update documentation

4. **Test Thoroughly**
   ```bash
   # Run all tests
   flutter test
   
   # Run specific test files
   flutter test test/services/camera_service_test.dart
   
   # Test on physical device
   flutter run -d your-device-id
   ```

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

6. **Push and Create PR**
   ```bash
   git push origin feature/descriptive-name
   ```

---

## Contribution Guidelines

### What to Contribute

**High Priority:**
- Bug fixes
- Accessibility improvements
- Performance optimizations
- Documentation updates
- Test coverage improvements

**Feature Requests:**
- Discuss new features in issues first
- Ensure alignment with project goals
- Consider accessibility impact
- Provide clear use cases

**Documentation:**
- API documentation
- User guides
- Code comments
- Tutorial content

### What NOT to Include

**Avoid:**
- Breaking existing functionality
- Unnecessary dependencies
- Platform-specific code without testing
- Hardcoded values
- TODO comments in production code

### Code Quality Requirements

**Before Submitting:**
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] New features have tests
- [ ] Documentation updated
- [ ] No linting errors
- [ ] Accessibility considerations addressed

---

## Pull Request Process

### PR Checklist

**Before Creating PR:**
- [ ] Branch is up to date with main
- [ ] All tests pass locally
- [ ] Code follows style guidelines
- [ ] Commit messages are clear
- [ ] Documentation updated if needed
- [ ] Self-review completed

### PR Template

When creating a PR, use this template:

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring
- [ ] Test improvements

## Testing
- [ ] Unit tests pass
- [ ] Widget tests pass
- [ ] Integration tests pass
- [ ] Tested on device/emulator
- [ ] Accessibility testing completed

## Screenshots
Include screenshots for UI changes.

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where needed
- [ ] I have made corresponding changes
- [ ] Any dependent changes have been merged
```

### Review Process

**Review Criteria:**
1. **Code Quality**: Clean, readable, maintainable code
2. **Functionality**: Does the change work as intended?
3. **Testing**: Adequate test coverage
4. **Accessibility**: Meets accessibility standards
5. **Performance**: No performance regressions
6. **Documentation**: Code is well-documented

**Review Timeline:**
- Small changes: 1-2 days
- Medium changes: 3-5 days
- Large changes: 1 week

**Reviewers:**
- At least 2 reviewers required
- Accessibility reviewer for UI changes
- Technical reviewer for complex changes

---

## Coding Standards

### Dart Style Guide

**File Organization:**
```dart
// 1. Imports
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

**Naming Conventions:**
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

// Private members: underscore prefix
class _PrivateClass {}
String _privateVariable;
```

### Flutter-Specific Guidelines

**Widget Structure:**
```dart
/// A widget for displaying ASL translation results.
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

**Error Handling:**
```dart
/// Initializes camera with comprehensive error handling.
Future<void> initializeCamera() async {
  try {
    // Check permissions
    final permission = await _permissionsService.requestCameraPermission();
    if (permission != PermissionStatus.granted) {
      throw PermissionException(
        'Camera permission required for ASL translation',
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

### Documentation Requirements

**Class Documentation:**
```dart
/// Service for ASL sign translation.
///
/// This service handles the translation of detected ASL signs into
/// human-readable text using machine learning models. It supports both
/// static signs (alphabet) and dynamic signs (words and phrases).
///
/// ## Usage
/// ```dart
/// final translator = AslTranslationService(mlService: mlService);
/// final translation = await translator.translateSign(sign);
/// print('Translated: $translation');
/// ```
///
/// ## Features
/// - Real-time ASL sign recognition
/// - Support for alphabet and common words
/// - Confidence scoring
/// - Temporal sequence processing
class AslTranslationService {
```

**Method Documentation:**
```dart
/// Translates an ASL sign to text.
///
/// Takes a detected ASL sign and returns the corresponding text
/// translation. Handles both static signs (letters) and dynamic
/// signs (words and phrases) with confidence scoring.
///
/// [sign] The ASL sign to translate, must not be null.
/// [includeConfidence] Whether to include confidence score in output.
///
/// Returns a [Future] that completes with the translated text,
/// or throws [TranslationException] if translation fails.
///
/// Example:
/// ```dart
/// final sign = AslSign(label: 'A', confidence: 0.95);
/// final translation = await translator.translateSign(sign);
/// print(translation); // "A"
/// ```
Future<String> translateSign(
  AslSign sign, {
  bool includeConfidence = false,
}) async {
```

---

## Testing Requirements

### Test Coverage Goals

**Current Goals:**
- Unit tests: 80% coverage
- Widget tests: 70% coverage
- Integration tests: 60% coverage

**Critical Areas (90%+ coverage):**
- Core services (ML, Camera, Audio)
- Permission handling
- Error handling
- Data models

### Test Structure

**Unit Tests:**
```dart
void main() {
  group('AslTranslationService', () {
    late AslTranslationService translator;
    late MockMlInferenceService mockMlService;

    setUp(() {
      mockMlService = MockMlInferenceService();
      translator = AslTranslationService(mlService: mockMlService);
    });

    test('should translate ASL sign to text', () async {
      // Arrange
      final sign = AslSign(label: 'A', confidence: 0.95);
      
      // Act
      final result = await translator.translateSign(sign);
      
      // Assert
      expect(result, 'A');
    });

    test('should throw exception for null sign', () async {
      // Arrange
      final sign = null;
      
      // Act & Assert
      expect(
        () => translator.translateSign(sign),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

**Widget Tests:**
```dart
void main() {
  group('TranslationDisplay Widget', () {
    testWidgets('should display sign label and confidence', (tester) async {
      // Arrange
      final sign = AslSign(label: 'HELLO', confidence: 0.87);
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: TranslationDisplay(sign: sign),
        ),
      );
      
      // Assert
      expect(find.text('HELLO'), findsOneWidget);
      expect(find.text('87.0%'), findsOneWidget);
    });
  });
}
```

**Integration Tests:**
```dart
void main() {
  group('ASL Translation Flow', () {
    testWidgets('complete translation workflow', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to translation mode
      await tester.tap(find.text('ASL Translation'));
      await tester.pumpAndSettle();

      // Grant permissions
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      // Verify camera is active
      expect(find.byType(CameraPreview), findsOneWidget);

      // Simulate sign detection
      await simulateSignDetection('A');
      
      // Verify translation appears
      expect(find.text('A'), findsOneWidget);
    });
  });
}
```

### Testing Guidelines

**Test Best Practices:**
1. **Arrange-Act-Assert** pattern
2. **Descriptive test names**
3. **One concept per test**
4. **Mock external dependencies**
5. **Test error cases**
6. **Test accessibility features**

**Mocking Guidelines:**
```dart
// Use mockito for mocking
@GenerateMocks([CameraService, MlInferenceService])
import 'camera_service_test.mocks.dart';

// In tests
final mockCameraService = MockCameraService();
when(mockCameraService.initialize()).thenAnswer((_) async {});

when(mockCameraService.startCamera())
  .thenThrow(CameraException('Permission denied'));
```

---

## Documentation

### Types of Documentation

**Code Documentation:**
- Class and method documentation
- Inline comments for complex logic
- API documentation for services

**User Documentation:**
- Feature guides
- Troubleshooting guides
- Accessibility guides

**Developer Documentation:**
- Architecture documentation
- Setup guides
- Contributing guidelines

### Documentation Standards

**Code Documentation:**
```dart
/// Brief description of the class/method.
///
/// Detailed description of functionality, usage, and important notes.
///
/// ## Example
/// ```dart
/// final service = MyService();
/// await service.doSomething();
/// ```
///
/// ## Parameters
/// [param1] Description of param1
/// [param2] Description of param2
///
/// ## Returns
/// Description of return value
///
/// ## Throws
/// [ExceptionType] When this condition occurs
void myMethod(String param1, int param2) {
```

**README Updates:**
- Keep feature lists current
- Update installation instructions
- Maintain compatibility information
- Update screenshots when UI changes

**Documentation Style:**
- Use clear, concise language
- Include practical examples
- Provide step-by-step instructions
- Include troubleshooting tips

---

## Accessibility Guidelines

### WCAG 2.1 AA Compliance

**All contributions must meet WCAG 2.1 AA standards:**

**Perceivable:**
- Provide text alternatives for images
- Ensure sufficient color contrast (4.5:1 minimum)
- Resize text without loss of functionality
- Use more than one sense for information

**Operable:**
- Make all functionality keyboard accessible
- Give users enough time to read content
- Don't use content that causes seizures
- Help users navigate and find content

**Understandable:**
- Make text readable and understandable
- Make content appear and operate predictably
- Help users avoid and correct mistakes

**Robust:**
- Maximize compatibility with assistive technologies
- Use valid HTML/semantic markup

### Accessibility Testing

**Automated Testing:**
```dart
// Test semantic markup
testWidgets('TranslationDisplay has semantic labels', (tester) async {
  final sign = AslSign(label: 'A', confidence: 0.95);
  
  await tester.pumpWidget(
    MaterialApp(
      home: TranslationDisplay(sign: sign),
    ),
  );
  
  // Verify semantic labels
  expect(find.bySemanticsLabel('ASL Sign: A'), findsOneWidget);
  expect(find.bySemanticsLabel('Confidence: 95%'), findsOneWidget);
});
```

**Manual Testing Checklist:**
- [ ] Screen reader navigation
- [ ] Keyboard-only navigation
- [ ] High contrast mode
- [ ] Text scaling (up to 200%)
- [ ] Focus indicators
- [ ] Color contrast
- [ ] Alternative text for images

### Accessibility Implementation

**Semantic Widgets:**
```dart
// Good: Use semantic widgets
Semantics(
  label: 'ASL Sign detected: ${sign.label}',
  hint: 'Confidence: ${(sign.confidence * 100).toStringAsFixed(1)}%',
  child: Text(sign.label),
)

// Avoid: Non-semantic containers
Container(
  child: Text(sign.label), // No semantic meaning
)
```

**Focus Management:**
```dart
// Manage focus for dynamic content
FocusScope.of(context).requestFocus(_focusNode);

// Ensure focus indicators
TextField(
  focusNode: _focusNode,
  decoration: InputDecoration(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 2,
      ),
    ),
  ),
)
```

---

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

**MAJOR.MINOR.PATCH**
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Types

**Hotfix Release:**
- Critical bug fixes
- Security patches
- Emergency accessibility fixes

**Patch Release:**
- Bug fixes
- Minor improvements
- Documentation updates

**Minor Release:**
- New features
- API additions
- Significant improvements

**Major Release:**
- Breaking changes
- Architecture changes
- Major feature additions

### Release Checklist

**Before Release:**
- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version number updated
- [ ] Accessibility testing completed
- [ ] Performance benchmarks met
- [ ] Security review completed

**Release Process:**
1. Create release branch
2. Update version numbers
3. Update CHANGELOG.md
4. Create pull request for review
5. Merge to main after approval
6. Create GitHub release
7. Deploy to app stores

### CHANGELOG Format

```markdown
# Changelog

## [1.2.0] - 2024-01-15

### Added
- Dynamic ASL sign sequence recognition
- Spatial audio for object detection
- Face recognition enrollment

### Changed
- Improved camera initialization speed
- Updated ML model to version 2.1
- Enhanced accessibility features

### Fixed
- Camera permission handling on Android 12+
- Audio alert delays in object detection
- Memory leak in LSTM inference

### Security
- Updated TensorFlow Lite to 2.12.1
- Fixed potential data exposure in chat history

## [1.1.0] - 2023-12-01

### Added
- AI assistant integration
- Customizable confidence thresholds
- Multiple language support

[Previous versions...]
```

---

## Community

### Communication Channels

**GitHub:**
- Issues: Bug reports and feature requests
- Discussions: Community questions and ideas
- Pull requests: Code contributions

**Discord:**
- Real-time chat and support
- Development discussions
- Community meetups

**Social Media:**
- Twitter: @SignSyncApp
- YouTube: SignSync Tutorials
- LinkedIn: SignSync Project

### Recognition

**Contributors:**
- Listed in README.md
- Featured in release notes
- GitHub contributors page

**Special Recognition:**
- Accessibility champions
- Documentation contributors
- Bug hunters
- Beta testers

### Getting Help

**For Contributors:**
1. Check existing documentation
2. Search through existing issues
3. Ask in GitHub Discussions
4. Join Discord community
5. Contact maintainers directly

**Maintainers:**
- [@maintainer1](https://github.com/maintainer1)
- [@maintainer2](https://github.com/maintainer2)

---

## Thank You!

Thank you for contributing to SignSync! Your contributions help make ASL translation more accessible for everyone. Every contribution, no matter how small, makes a difference.

**Questions?**
- Read the [FAQ](docs/FAQ.md)
- Check [existing issues](https://github.com/signsync/signsync/issues)
- Join our [Discord community](https://discord.gg/signsync)
- Contact maintainers

**Ready to contribute?**
1. Pick a [good first issue](https://github.com/signsync/signsync/labels/good%20first%20issue)
2. Follow our [setup guide](docs/DEVELOPER_ONBOARDING.md)
3. Make your changes
4. Submit a pull request

Welcome to the SignSync community! 🎉