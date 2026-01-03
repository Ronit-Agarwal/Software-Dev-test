# Test Suite Configuration

## Directory Structure

```
test/
├── helpers/
│   └── mocks.dart          # Mock classes and test utilities
├── services/
│   ├── camera_service_test.dart
│   ├── gemini_ai_service_test.dart
│   ├── ml_orchestrator_service_test.dart
│   ├── tts_service_test.dart
│   └── audio_service_test.dart
├── widgets/
│   ├── dashboard_widgets_test.dart
│   ├── settings_widgets_test.dart
│   └── common_widgets_test.dart
├── integration/
│   └── e2e_asl_translation_test.dart
├── accessibility/
│   └── accessibility_test.dart
├── models_test.dart
├── utils_test.dart
└── coverage_config.yaml
```

## Running Tests

### Run All Tests

```bash
# Run all tests with coverage
flutter test --coverage

# Using the test runner script
./scripts/run_tests.sh
```

### Run Specific Test Suites

```bash
# Unit tests only
./scripts/run_tests.sh --unit-only

# Widget tests only
./scripts/run_tests.sh --widget-only

# Include integration tests
./scripts/run_tests.sh --integration

# Without coverage
./scripts/run_tests.sh --no-coverage

# Watch mode for development
./scripts/run_tests.sh --watch
```

### Run Individual Test Files

```bash
# Run specific test file
flutter test test/services/camera_service_test.dart

# Run specific test group
flutter test test/services/camera_service_test.dart --name "CameraService Initialization"
```

## Coverage

### View Coverage Report

```bash
# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
start coverage/html/index.html  # Windows
```

### Coverage Requirements

- **Overall Target:** 85%
- **Critical Components:** 90%
- **Models:** 95%
- **Utils:** 90%

## Test Types

### Unit Tests

Test individual functions, classes, and methods in isolation.

- Services
- Models
- Utils
- Extensions

**Example:**
```dart
test('should initialize with valid API key', () async {
  await service.initialize(apiKey: 'test-key');
  expect(service.isInitialized, true);
});
```

### Widget Tests

Test widgets in isolation with mocked dependencies.

- Screens
- Custom widgets
- Layouts
- Interactions

**Example:**
```dart
testWidgets('should render dashboard screen', (tester) async {
  await tester.pumpWidget(
    ProviderScope(child: DashboardScreen())
  );
  expect(find.text('Dashboard'), findsOneWidget);
});
```

### Integration Tests

Test the complete app flow across multiple components.

- User workflows
- Mode switching
- Camera to inference to UI
- API integration

**Example:**
```dart
testWidgets('Complete ASL translation workflow', (tester) async {
  await tester.pumpWidget(ProviderScope(child: SignSyncApp()));
  await tester.tap(find.text('Translation'));
  // ... verify workflow
});
```

### Accessibility Tests

Verify WCAG AAA compliance.

- Screen reader compatibility
- Touch target sizes
- Color contrast
- Keyboard navigation
- Text scaling

**Example:**
```dart
testWidgets('interactive elements meet touch target size', (tester) async {
  final buttons = find.byType(ElevatedButton);
  for (final button in buttons.evaluate()) {
    final size = button.size!;
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  }
});
```

## Mocking

### Using Mocktail

```dart
import 'package:mocktail/mocktail.dart';

class MockCameraService extends Mock implements CameraService {}

void main() {
  late MockCameraService mockCameraService;

  setUp(() {
    mockCameraService = MockCameraService();
    // Register fallback values
    registerFallbackValue(CameraImage(...));
  });
}
```

### Registering Fallbacks

```dart
void main() {
  setUpAll(() {
    registerMockFallbacks();
  });
}
```

## Test Naming Conventions

### File Names

- Unit tests: `<name>_test.dart`
- Widget tests: `<name>_widgets_test.dart`
- Integration tests: `e2e_<workflow>_test.dart`
- Accessibility tests: `accessibility_test.dart`

### Test Names

```dart
// Good - descriptive
test('should initialize with valid API key', () {});

testWidgets('should display error message when API call fails', (tester) async {});

// Avoid - vague
test('init test', () {});

testWidgets('test error', (tester) async {});
```

### Test Groups

```dart
group('CameraService Initialization', () {
  test('should start uninitialized', () {});
  test('should initialize successfully', () {});
});

group('CameraService Error Handling', () {
  test('should throw error without permission', () {});
  test('should handle network errors', () {});
});
```

## Common Test Patterns

### Asynchronous Tests

```dart
test('should complete asynchronous operation', () async {
  final result = await service.doSomethingAsync();
  expect(result, isNotNull);
});
```

### Waiting for Async

```dart
testWidgets('should show loading indicator', (tester) async {
  await tester.pumpWidget(MyWidget());
  await tester.pump(); // First frame
  await tester.pump(Duration(seconds: 1)); // Wait
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

### Provider Testing

```dart
testWidgets('should update when provider changes', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProvider.overrideWithValue(MockService()),
      ],
      child: MyWidget(),
    ),
  );

  // Trigger provider change
  tester.container.read(myProvider.notifier).update();
  await tester.pump();

  expect(find.text('Updated'), findsOneWidget);
});
```

### Finding Widgets

```dart
// By text
find.text('Hello')
find.textContaining('World')

// By type
find.byType(ElevatedButton)
find.byType(TextField)

// By key
find.byKey(Key('my-widget-key'))

// By widget predicate
find.byWidgetPredicate((widget) =>
  widget is Text && widget.data?.startsWith('Hello') == true)
```

## CI/CD Integration

Tests run automatically on:
- Push to main/develop branches
- Pull requests
- Daily scheduled runs (2 AM UTC)

See `.github/workflows/test.yml` for configuration.

## Troubleshooting

### Tests Time Out

```dart
test('long running test', () async {
  await tester.pumpWidget(MyWidget());
  await tester.pumpAndSettle(Duration(seconds: 30));
}, timeout: const Timeout(Duration(seconds: 45)));
```

### Platform-Specific Tests

```dart
testWidgets('iOS specific feature', (tester) async {
  if (!Platform.isIOS) {
    return; // Skip on non-iOS platforms
  }
  // Test iOS-specific code
});
```

### Skipping Tests

```dart
test('feature under development', () {
  return;
}, skip: 'Feature not implemented yet');
```

## Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/cookbook/testing)
- [Mocktail Documentation](https://pub.dev/packages/mocktail)
- [Test Coverage Guide](https://flutter.dev/docs/testing/code-coverage)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
