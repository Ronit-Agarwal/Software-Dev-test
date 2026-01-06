# SignSync Architecture Overview

High-level system design, data flow, and component architecture for the SignSync application.

## Table of Contents

- [System Architecture](#system-architecture)
- [Data Flow](#data-flow)
- [State Management](#state-management)
- [ML Pipeline Architecture](#ml-pipeline-architecture)
- [Component Architecture](#component-architecture)
- [Security Architecture](#security-architecture)
- [Performance Architecture](#performance-architecture)

---

## System Architecture

### High-Level Overview

SignSync follows a modular, layered architecture designed for scalability, maintainability, and performance:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │   Home      │ │ Translation │ │  Detection  │ │  Chat   │ │
│  │   Screen    │ │   Screen    │ │   Screen    │ │ Screen  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     Widget Layer                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │  Camera     │ │  Translation│ │  Detection  │ │  Chat   │ │
│  │   Preview   │ │   Display   │ │   Results   │ │ Widget  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │     ML      │ │   Camera    │ │    Audio    │ │  TTS    │ │
│  │  Service    │ │   Service   │ │   Service   │ │ Service │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │   Gemini    │ │ Permissions │ │  Storage    │ │  Face   │ │
│  │ AI Service  │ │   Service   │ │   Service   │ │Recog.   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     Core Layer                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │   Error     │ │   Logging   │ │ Navigation  │ │  Theme  │ │
│  │  Handling   │ │   Service   │ │   Router    │ │ Service │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │   Local     │ │   Model     │ │   Cache     │ │  User   │ │
│  │   Storage   │ │   Files     │ │   Data      │ │Prefs    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Architecture Principles

#### 1. Separation of Concerns
- **UI Layer**: Only presentation logic and user interactions
- **Service Layer**: Business logic and external integrations
- **Core Layer**: Cross-cutting concerns (logging, error handling)
- **Data Layer**: Data persistence and model management

#### 2. Dependency Inversion
- Services depend on abstractions (interfaces)
- UI depends on services through providers
- No direct dependencies between layers

#### 3. Single Responsibility
- Each service handles one domain (ML, camera, audio, etc.)
- Each widget has a single purpose
- Each model represents one data entity

#### 4. Open/Closed Principle
- Services can be extended without modification
- New features added through composition
- Existing code remains stable

---

## Data Flow

### Primary Data Flow

```
Camera Input → CameraService → Frame Extraction → ML Processing → Result Display
     │               │                │                │              │
     ▼               ▼                ▼                ▼              ▼
┌─────────┐    ┌─────────┐      ┌─────────┐      ┌─────────┐    ┌─────────┐
│  User   │───▶│ Camera  │─────▶│ Preproc │─────▶│   CNN   │───▶│  Text   │
│ Signs   │    │Service  │      │  and    │      │   +     │    │Output   │
└─────────┘    └─────────┘      │Frame    │      │  LSTM   │    └─────────┘
                              │Buffer    │      │   +     │
                              └─────────┘      │  YOLO   │
                                              └─────────┘
```

### Event Flow

#### ASL Translation Flow
```
1. User Signs → Camera captures frame
2. Frame → Preprocessing → CNN prediction
3. CNN result → Temporal buffer → LSTM sequence
4. Sequence → Translation → Text output
5. Text → TTS → Audio output (optional)
```

#### Object Detection Flow
```
1. Camera frame → YOLO processing
2. YOLO → Object detection + bounding boxes
3. Detection → Spatial audio + visual overlay
4. Alert → TTS + haptic feedback
```

#### Sound Detection Flow
```
1. Audio input → Audio processing
2. Audio → ML classification (sound events)
3. Classification → Alert filtering
4. Alert → Visual + audio + haptic feedback
```

### State Management Flow

```
┌─────────────────────────────────────────────────────────┐
│                    App State                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ User State  │  │ Camera State│  │ ML State    │     │
│  │ - Settings  │  │ - Status    │  │ - Models    │     │
│  │ - Preferences│  │ - Frames    │  │ - Results   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │Chat History │  │Permissions  │  │Audio State  │     │
│  │- Messages   │  │- Status     │  │- Recording  │     │
│  │- Context    │  │- Requests   │  │- Events     │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Provider   │    │  Provider   │    │  Provider   │
│   Layer     │    │   Layer     │    │   Layer     │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## State Management

### Riverpod Architecture

SignSync uses Riverpod for state management, providing a robust and type-safe solution:

#### Provider Hierarchy
```
ProviderScope (App Root)
├── appConfigProvider (AppConfig)
├── routerProvider (GoRouter)
├── cameraControllerProvider (CameraController)
├── mlInferenceControllerProvider (MLInferenceController)
├── audioControllerProvider (AudioController)
└── [Screen-specific providers]
```

#### State Patterns

##### 1. Future Providers (Async Operations)
```dart
@riverpod
class CameraController extends _$CameraController {
  @override
  Future<CameraState> build() async {
    return await _initializeCamera();
  }

  Future<void> startCamera() async {
    state = const AsyncValue.loading();
    try {
      final cameraState = await _cameraService.start();
      state = AsyncValue.data(cameraState);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}
```

##### 2. State Providers (Mutable State)
```dart
@riverpod
class AppConfigController extends _$AppConfigController {
  @override
  AppConfig build() {
    return AppConfig.load();
  }

  void updateThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    state.save();
  }
}
```

##### 3. Stream Providers (Real-time Data)
```dart
@riverpod
Stream<List<DetectedObject>> detectedObjectsStream(
  DetectedObjectsStreamRef ref,
) {
  return ref.watch(yoloDetectionServiceProvider).detectionsStream;
}
```

#### State Flow Patterns

##### 1. Loading → Data → Error
```dart
// In widgets
Widget build(BuildContext context, WidgetRef ref) {
  final cameraState = ref.watch(cameraControllerProvider);
  
  return cameraState.when(
    loading: () => const LoadingIndicator(),
    data: (state) => CameraPreview(controller: state.controller),
    error: (error, stack) => ErrorDisplay(error: error),
  );
}
```

##### 2. Manual State Management
```dart
class MlInferenceController extends StateNotifier<MlInferenceState> {
  MlInferenceController(this._mlService) : super(MlInferenceState.initial());

  final MlInferenceService _mlService;

  Future<void> processFrame(CameraImage frame) async {
    state = state.copyWith(isProcessing: true);
    
    try {
      final result = await _mlService.processFrame(frame);
      state = state.copyWith(
        isProcessing: false,
        latestResult: result,
      );
    } catch (error) {
      state = state.copyWith(
        isProcessing: false,
        error: error.toString(),
      );
    }
  }
}
```

---

## ML Pipeline Architecture

### Multi-Model Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                   Input Processing                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │Frame Queue  │  │Preprocessing│  │ Quality     │          │
│  │  (30 FPS)   │  │  Pipeline   │  │  Check      │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Parallel Processing                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    CNN      │  │    LSTM     │  │    YOLO     │          │
│  │  (Static)   │  │ (Sequence)  │  │ (Objects)   │          │
│  │             │  │             │  │             │          │
│  │ ResNet-50   │  │  3-Layer    │  │  YOLOv8     │          │
│  │ 224x224     │  │ 30 Frames   │  │ 640x640     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Result Aggregation                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Confidence  │  │ Temporal    │  │ Spatial     │          │
│  │  Filter     │  │  Smoothing  │  │  Alert      │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Output Formatting                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Text      │  │  Detection  │  │   Audio     │          │
│  │ Translation │  │   Boxes     │  │  Alerts     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### CNN Pipeline (Static Signs)

#### Input Processing
1. **Frame Capture**: 30 FPS camera input
2. **Preprocessing**:
   - Resize to 224x224 pixels
   - Normalize pixel values [0,1]
   - Convert to tensor format
   - Apply data augmentation (brightness, contrast)

#### Model Architecture
```
Input: [224, 224, 3] RGB Image
    ↓
ResNet-50 Base (Pre-trained on ImageNet)
    ↓
Custom ASL Classification Head
    ↓
Output: [num_classes] probabilities
    ↓
Softmax → Class prediction
```

#### Post-processing
1. **Confidence Threshold**: Filter predictions < 0.85
2. **Non-maximum Suppression**: Remove duplicate detections
3. **Temporal Smoothing**: Average with previous 3 predictions
4. **Output**: ASL sign with confidence score

### LSTM Pipeline (Dynamic Signs)

#### Sequence Processing
1. **Temporal Buffer**: Maintain 30-frame sliding window
2. **Feature Extraction**: CNN features for each frame
3. **Sequence Analysis**: LSTM processes temporal patterns
4. **Context Integration**: Combine with spatial features

#### Model Architecture
```
Input: [30, 2048] (30 frames × CNN features)
    ↓
LSTM Layer 1 (256 units, return_sequences=True)
    ↓
LSTM Layer 2 (128 units)
    ↓
Dense Layer (64 units, ReLU)
    ↓
Output Layer: [num_sequences] probabilities
```

#### Sequence Logic
1. **Frame Collection**: Collect CNN predictions over time
2. **Feature Engineering**: Create temporal feature vectors
3. **Sequence Prediction**: LSTM identifies sign sequences
4. **Translation**: Convert sequences to text

### YOLO Pipeline (Object Detection)

#### Detection Process
1. **Frame Processing**: Resize to 640x640 for YOLO
2. **Model Inference**: YOLOv8-tiny for mobile optimization
3. **Post-processing**: Non-maximum suppression
4. **Spatial Processing**: Calculate object positions

#### Model Configuration
```
Model: YOLOv8n (nano) - Optimized for mobile
Input Size: 640x640
Output: [batch, num_detections, 85] (x, y, w, h, objectness, classes)
Confidence Threshold: 0.5
IoU Threshold: 0.45
```

#### Alert System
1. **Object Classification**: 80 COCO dataset classes
2. **Priority System**: Critical (person), High (vehicles), Normal (objects)
3. **Spatial Audio**: "Person at 3 o'clock"
4. **Distance Estimation**: Based on bounding box size

---

## Component Architecture

### Screen Architecture

#### Screen Structure Pattern
```dart
/// Base screen architecture pattern
class TranslationScreen extends ConsumerWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASL Translation')),
      body: Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 3,
            child: const CameraPreviewWidget(),
          ),
          
          // Translation Results
          Expanded(
            flex: 2,
            child: const TranslationDisplayWidget(),
          ),
          
          // Controls
          const TranslationControlsWidget(),
        ],
      ),
      
      // Floating Action Buttons
      floatingActionButton: const TranslationFAB(),
    );
  }
}
```

#### Widget Composition Pattern
```
Screen (Business Logic)
├── AppBar (Navigation & Actions)
├── Body (Main Content)
│   ├── Header (Mode Selection)
│   ├── Camera Preview (ML Input)
│   ├── Results Display (ML Output)
│   └── Controls (User Interaction)
└── FABs (Quick Actions)
```

### Widget Architecture

#### Widget Categories

##### 1. Presentation Widgets
- **Pure UI**: No business logic
- **Props-based**: Receive data through parameters
- **Stateless**: When possible for performance

##### 2. Container Widgets
- **State Management**: Connect to providers
- **Data Flow**: Handle state changes
- **Composition**: Combine multiple widgets

##### 3. Interaction Widgets
- **User Input**: Handle gestures and input
- **Action Dispatch**: Call service methods
- **Feedback**: Provide user feedback

#### Widget Hierarchy Example
```
TranslationDisplayWidget
├── ConfidenceIndicator
│   └── LinearProgressIndicator
├── SignTextWidget
│   └── AnimatedText
├── HistoryListWidget
│   └── ScrollableList
└── ActionButtonsWidget
    ├── ShareButton
    ├── ClearButton
    └── SettingsButton
```

### Service Architecture

#### Service Interface Pattern
```dart
/// Service interface
abstract class CameraServiceInterface {
  Future<void> initialize();
  Future<void> startCamera();
  Future<void> stopCamera();
  Stream<CameraFrame> get frameStream;
  CameraState get state;
}

/// Concrete implementation
class CameraService implements CameraServiceInterface {
  // Implementation with concrete dependencies
}
```

#### Service Composition
```
┌─────────────────────────────────────────────────────────┐
│                  Service Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ ML Service  │  │Camera Service│  │Audio Service│     │
│  │             │  │             │  │             │     │
│  │ Depends on: │  │ Depends on: │  │ Depends on: │     │
│  │ - CNN Model │  │ - Camera    │  │ - Mic       │     │
│  │ - LSTM Model│  │ - Permissions│  │ - TTS       │     │
│  │ - YOLO Model│  │ - Frame Proc│  │ - Alerts    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ TTS Service │  │Gemini Service│  │ Storage     │     │
│  │             │  │             │  │ Service     │     │
│  │ Depends on: │  │ Depends on: │  │             │     │
│  │ - Platform  │  │ - Gemini AI │  │ - SQLite    │     │
│  │ - Spatial   │  │ - Network   │  │ - Cache     │     │
│  │ - Queue     │  │ - Rate Lim. │  │ - User Prefs│     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## Security Architecture

### Data Privacy

#### Local Data Storage
- **Face Recognition Data**: Stored locally only
- **Chat History**: Optional cloud sync with user consent
- **User Settings**: Local SQLite database
- **ML Models**: Local asset files

#### Data Encryption
```dart
/// Encrypted storage for sensitive data
class SecureStorage {
  static const _storage = FlutterSecureStorage();
  
  Future<void> storeFaceData(String personId, List<double> features) async {
    final encrypted = await _encrypt(features);
    await _storage.write(key: 'face_$personId', value: encrypted);
  }
}
```

### Permission Model

#### Runtime Permissions
- **Camera**: Required for ASL detection and object recognition
- **Microphone**: Required for sound detection and voice features
- **Notifications**: Required for audio alerts and updates

#### Permission Flow
```
App Start → Request Permissions → User Response → 
├─ Granted → Enable Features
└─ Denied → Show Guidance → Settings → Manual Enable
```

### API Security

#### Rate Limiting
```dart
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _requests = Queue();
  
  Future<bool> canMakeRequest() async {
    final now = DateTime.now();
    _removeOldRequests(now);
    return _requests.length < maxRequests;
  }
}
```

#### API Key Management
- **Environment Variables**: API keys in environment, not code
- **Local Storage**: Encrypted storage for user-provided keys
- **Validation**: API key validation on startup

---

## Performance Architecture

### Memory Management

#### Frame Buffer Management
```dart
class FrameBuffer {
  static const int maxBufferSize = 30; // 1 second at 30fps
  final Queue<CameraImage> _buffer = Queue();
  
  void addFrame(CameraImage frame) {
    if (_buffer.length >= maxBufferSize) {
      _buffer.removeFirst().dispose();
    }
    _buffer.add(frame);
  }
}
```

#### Model Loading Strategy
```
App Start → Load Essential Models (CNN) → 
Background → Load Secondary Models (LSTM, YOLO) → 
Lazy Load → Load on-demand features
```

### Battery Optimization

#### Adaptive Processing
- **Foreground**: Full processing (30fps, all models)
- **Background**: Reduced processing (15fps, CNN only)
- **Low Battery**: Minimal processing (5fps, basic detection)

#### Intelligent Frame Skipping
```dart
class AdaptiveFrameProcessor {
  int _skipCount = 0;
  
  bool shouldProcessFrame() {
    if (_isLowPowerMode) {
      _skipCount++;
      return _skipCount % 3 == 0; // Process every 3rd frame
    }
    return true;
  }
}
```

### Network Optimization

#### Caching Strategy
```
┌─────────────────────────────────────────────────────────┐
│                   Cache Hierarchy                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ In-Memory   │  │   SQLite    │  │   File      │     │
│  │   (Fast)    │  │   (Medium)  │  │   (Slow)    │     │
│  │             │  │             │  │             │     │
│  │ - Current   │  │ - User Data │  │ - ML Models │     │
│  │   Results   │  │ - Chat Hist │  │ - Assets    │     │
│  │ - Settings  │  │ - Cache     │  │ - Downloads │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

#### Offline-First Design
- **Core Features**: Work without internet (ASL detection, basic translation)
- **AI Features**: Graceful degradation when offline
- **Sync Strategy**: Background sync when connection available

---

## Scalability Considerations

### Horizontal Scaling
- **Modular Architecture**: Easy to add new features
- **Service Independence**: Services can be scaled separately
- **Plugin Architecture**: Third-party integrations

### Performance Monitoring
```dart
class PerformanceMonitor {
  static void trackInferenceTime(String model, Duration duration) {
    LoggerService.info('Model: $model, Time: ${duration.inMilliseconds}ms');
    
    // Send to analytics for optimization
    Analytics.trackEvent('ml_inference_time', {
      'model': model,
      'duration_ms': duration.inMilliseconds,
      'device': DeviceInfo.model,
    });
  }
}
```

### Testing Architecture
```
┌─────────────────────────────────────────────────────────┐
│                 Test Architecture                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Unit Tests  │  │Widget Tests │  │Integration  │     │
│  │             │  │             │  │   Tests     │     │
│  │ - Services  │  │ - UI Logic  │  │ - User Flows│     │
│  │ - Models    │  │ - Widgets   │  │ - E2E       │     │
│  │ - Utils     │  │ - States    │  │ - Platform  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

This architecture provides a solid foundation for SignSync's ASL translation and accessibility features, enabling scalability, maintainability, and performance optimization across all components.