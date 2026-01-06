# SignSync API Documentation

Complete API reference for all services and components in the SignSync application.

## Table of Contents

- [ML Inference Services](#ml-inference-services)
- [Camera Service](#camera-service)
- [Audio Service](#audio-service)
- [TTS Service](#tts-service)
- [Gemini AI Service](#gemini-ai-service)
- [Permissions Service](#permissions-service)
- [Storage Service](#storage-service)
- [YOLO Detection Service](#yolo-detection-service)
- [ASL Translation Service](#asl-translation-service)
- [Face Recognition Service](#face-recognition-service)

---

## ML Inference Services

### MlInferenceService

Main service for machine learning inference operations.

```dart
final mlService = MlInferenceService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isModelLoaded` | `bool` | Whether ML models are loaded and ready |
| `isProcessing` | `bool` | Whether inference is currently running |
| `latestResult` | `InferenceResult?` | Most recent inference result |
| `currentMode` | `AppMode` | Current inference mode |
| `error` | `String?` | Current error state |
| `confidenceThreshold` | `double` | Minimum confidence for valid detection (0.6) |

#### Methods

##### `initialize({AppMode mode = AppMode.translation})`

Initializes the ML inference service with specified mode.

**Parameters:**
- `mode` - Application mode (default: `AppMode.translation`)

**Returns:** `Future<void>`

**Throws:**
- `ModelLoadException` - If model loading fails
- `PermissionException` - If camera permission denied

```dart
await mlService.initialize(mode: AppMode.translation);
```

##### `processFrame(CameraImage frame)`

Processes a camera frame for inference.

**Parameters:**
- `frame` - Camera frame from CameraService

**Returns:** `Future<InferenceResult?>`

**Example:**
```dart
final result = await mlService.processFrame(cameraImage);
if (result != null) {
  print('Detected: ${result.label}');
}
```

##### `setMode(AppMode mode)`

Changes the inference mode.

**Parameters:**
- `mode` - New application mode

**Example:**
```dart
mlService.setMode(AppMode.detection);
```

---

### MlOrchestratorService

Orchestrates multiple ML models for comprehensive inference.

```dart
final orchestrator = MlOrchestratorService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `bool` | Whether all models are loaded |
| `isProcessing` | `bool` | Whether inference pipeline is active |
| `currentMode` | `AppMode` | Current application mode |
| `latestInference` | `InferenceResult?` | Most recent result |
| `statistics` | `Map<String, dynamic>` | Performance statistics |

#### Methods

##### `initialize({AppMode initialMode = AppMode.translation})`

Initializes all ML models for the specified mode.

**Parameters:**
- `initialMode` - Starting application mode

**Returns:** `Future<void>`

##### `processFrame(CameraImage frame, {AppMode? overrideMode})`

Processes frame through appropriate ML pipeline.

**Parameters:**
- `frame` - Camera frame to process
- `overrideMode` - Optional mode override

**Returns:** `Future<InferenceResult?>`

##### `updateModelConfiguration(String modelType, Map<String, dynamic> config)`

Updates configuration for specific model.

**Parameters:**
- `modelType` - Model identifier ('cnn', 'lstm', 'yolo')
- `config` - New configuration parameters

---

### CnnInferenceService

ResNet-50 based CNN for static ASL sign recognition.

```dart
final cnnService = CnnInferenceService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isModelLoaded` | `bool` | CNN model ready state |
| `isProcessing` | `bool` | Processing state |
| `confidenceThreshold` | `double` | Detection confidence threshold |
| `inputSize` | `Size` | Model input dimensions (224x224) |

#### Methods

##### `initialize()`

Loads CNN model for static sign recognition.

**Returns:** `Future<void>`

##### `predictSign(CameraImage frame)`

Predicts ASL sign from camera frame.

**Parameters:**
- `frame` - Preprocessed camera frame

**Returns:** `Future<AslSign?>`

**Example:**
```dart
final sign = await cnnService.predictSign(frame);
if (sign != null) {
  print('Sign: ${sign.label} (${sign.confidence})');
}
```

##### `preprocessFrame(CameraImage frame)`

Preprocesses camera frame for CNN input.

**Parameters:**
- `frame` - Raw camera frame

**Returns:** `List<List<List<List<double>>>>`

---

### LstmInferenceService

LSTM-based temporal sequence recognition for dynamic ASL signs.

```dart
final lstmService = LstmInferenceService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isModelLoaded` | `bool` | LSTM model ready state |
| `sequenceLength` | `int` | Frames needed for prediction (30) |
| `temporalWindow` | `Duration` | Time window for sequence (2.0s) |
| `bufferSize` | `int` | Maximum sequence buffer (100) |

#### Methods

##### `initialize()`

Loads LSTM model for temporal sequence recognition.

**Returns:** `Future<void>`

##### `addFrame(CameraImage frame, AslSign prediction)`

Adds frame and prediction to temporal sequence.

**Parameters:**
- `frame` - Camera frame
- `prediction` - CNN prediction for frame

##### `getSequencePrediction()`

Gets prediction for current temporal sequence.

**Returns:** `Future<AslSign?>`

---

## Camera Service

### CameraService

Comprehensive camera management with ML integration.

```dart
final cameraService = CameraService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `controller` | `CameraController?` | Active camera controller |
| `state` | `CameraState` | Current camera state |
| `isInitialized` | `bool` | Camera ready state |
| `isStreaming` | `bool` | Active streaming state |
| `currentFps` | `double` | Current frames per second |
| `hasFlash` | `bool` | Flash capability |
| `isFlashOn` | `bool` | Flash state |
| `lowLightDetected` | `bool` | Low light detection |

#### Methods

##### `initialize()`

Initializes camera service with permission handling.

**Returns:** `Future<void>`

**Throws:**
- `PermissionException` - If camera permission denied
- `CameraException` - If camera initialization fails

##### `startCamera()`

Starts camera streaming with ML integration.

**Parameters:**
- `cameraDirection` - Camera lens direction (default: back)

**Returns:** `Future<void>`

**Example:**
```dart
await cameraService.startCamera(CameraLensDirection.back);
```

##### `stopCamera()`

Stops camera streaming and releases resources.

**Returns:** `Future<void>`

##### `toggleFlash()`

Toggles camera flash on/off.

**Returns:** `Future<bool>` - New flash state

##### `setExposure(double value)`

Sets camera exposure value.

**Parameters:**
- `value` - Exposure value (-2.0 to 2.0)

##### `getFrame(CameraImage frame)`

Gets processed frame for ML inference.

**Parameters:**
- `frame` - Camera frame to process

**Returns:** `Future<CameraFrame?>`

---

## Audio Service

### AudioService

Audio recording and sound detection service.

```dart
final audioService = AudioService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `bool` | Audio service ready state |
| `isRecording` | `bool` | Recording active state |
| `error` | `String?` | Current error state |
| `detectedEvents` | `List<NoiseEvent>` | Recent noise events |
| `noiseThreshold` | `double` | Noise detection threshold (0.5) |
| `hapticEnabled` | `bool` | Haptic feedback enabled |

#### Methods

##### `initialize()`

Initializes audio service and loads ML model.

**Returns:** `Future<void>`

##### `startRecording()`

Starts audio recording and noise detection.

**Returns:** `Future<void>`

##### `stopRecording()`

Stops audio recording.

**Returns:** `Future<void>`

##### `setNoiseThreshold(double threshold)`

Sets noise detection sensitivity.

**Parameters:**
- `threshold` - Threshold value (0.0 to 1.0)

##### `enableHapticFeedback(bool enabled)`

Enables/disables haptic feedback for detected sounds.

**Parameters:**
- `enabled` - Enable haptic feedback

---

## TTS Service

### TtsService

Text-to-speech service for object detection alerts.

```dart
final ttsService = TtsService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `bool` | TTS ready state |
| `isSpeaking` | `bool` | Currently speaking |
| `error` | `String?` | Current error state |
| `currentLanguage` | `String?` | Active language code |
| `volume` | `double` | Speech volume (0.0 to 1.0) |
| `speechRate` | `double` | Speech rate (0.1 to 1.0) |
| `spatialAudioEnabled` | `bool` | Spatial audio enabled |

#### Methods

##### `initialize()`

Initializes native TTS engine.

**Returns:** `Future<void>`

##### `speak(String text)`

Speaks text with spatial audio positioning.

**Parameters:**
- `text` - Text to speak
- `priority` - Alert priority (default: normal)

**Returns:** `Future<void>`

**Example:**
```dart
await ttsService.speak('Person detected at 3 o\'clock', AlertPriority.high);
```

##### `speakDetection(DetectedObject object)`

Speaks object detection result.

**Parameters:**
- `object` - Detected object with position

**Returns:** `Future<void>`

##### `setLanguage(String languageCode)`

Sets TTS language.

**Parameters:**
- `languageCode` - ISO language code (e.g., 'en-US')

##### `stop()`

Stops current speech.

**Returns:** `Future<void>`

---

## Gemini AI Service

### GeminiAiService

Google Gemini 2.5 powered AI assistant.

```dart
final geminiService = GeminiAiService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `bool` | AI service ready state |
| `isLoading` | `bool` | Request processing state |
| `error` | `String?` | Current error state |
| `voiceEnabled` | `bool` | Voice I/O enabled |
| `isOnline` | `bool` | Network connectivity |

#### Methods

##### `initialize({required String apiKey, TtsService? ttsService})`

Initializes Gemini AI with API key.

**Parameters:**
- `apiKey` - Google Gemini API key
- `ttsService` - Optional TTS service for voice

**Returns:** `Future<void>`

##### `sendMessage(String message)`

Sends message to AI assistant.

**Parameters:**
- `message` - User message
- `includeContext` - Include app context

**Returns:** `Future<String>` - AI response

**Example:**
```dart
final response = await geminiService.sendMessage(
  'How do I sign "hello" in ASL?'
);
print('AI: $response');
```

##### `setVoiceEnabled(bool enabled)`

Enables/disables voice input/output.

**Parameters:**
- `enabled` - Enable voice features

##### `updateAppContext(Map<String, dynamic> context)`

Updates AI with current app context.

**Parameters:**
- `context` - Current app state context

---

## Permissions Service

### PermissionsService

Runtime permission management service.

```dart
final permissionsService = PermissionsService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `cameraPermission` | `PermissionStatus` | Camera permission state |
| `microphonePermission` | `PermissionStatus` | Microphone permission state |
| `locationPermission` | `PermissionStatus` | Location permission state |

#### Methods

##### `requestCameraPermission()`

Requests camera permission with user guidance.

**Returns:** `Future<PermissionStatus>`

##### `requestMicrophonePermission()`

Requests microphone permission.

**Returns:** `Future<PermissionStatus>`

##### `isPermissionGranted(Permission permission)`

Checks if permission is granted.

**Parameters:**
- `permission` - Permission to check

**Returns:** `Future<bool>`

##### `openSettings()`

Opens app settings for manual permission management.

**Returns:** `Future<void>`

---

## Storage Service

### StorageService

Local data storage and caching service.

```dart
final storageService = StorageService();
```

#### Methods

##### `saveChatHistory(List<ChatMessage> messages)`

Saves chat history to local storage.

**Parameters:**
- `messages` - List of chat messages

**Returns:** `Future<void>`

##### `loadChatHistory()`

Loads chat history from storage.

**Returns:** `Future<List<ChatMessage>>`

##### `saveDetectedObjects(List<DetectedObject> objects)`

Saves object detection cache.

**Parameters:**
- `objects` - List of detected objects

##### `loadDetectedObjects()`

Loads cached object detections.

**Returns:** `Future<List<DetectedObject>>`

##### `clearCache()`

Clears all cached data.

**Returns:** `Future<void>`

---

## YOLO Detection Service

### YoloDetectionService

Real-time object detection using YOLO models.

```dart
final yoloService = YoloDetectionService();
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isModelLoaded` | `bool` | YOLO model ready state |
| `confidenceThreshold` | `double` | Detection confidence (0.5) |
| `inputSize` | `Size` | Model input size (640x640) |

#### Methods

##### `initialize()`

Loads YOLO model for object detection.

**Returns:** `Future<void>`

##### `detectObjects(CameraImage frame)`

Detects objects in camera frame.

**Parameters:**
- `frame` - Camera frame to analyze

**Returns:** `Future<List<DetectedObject>>`

**Example:**
```dart
final objects = await yoloService.detectObjects(frame);
for (final object in objects) {
  print('${object.label} at ${object.boundingBox}');
}
```

---

## ASL Translation Service

### AslTranslationService

ASL sign translation and sequence management.

```dart
final aslService = AslTranslationService();
```

#### Methods

##### `translateSign(AslSign sign)`

Translates detected ASL sign.

**Parameters:**
- `sign` - Detected ASL sign

**Returns:** `String` - Translation text

##### `buildSequence(List<AslSign> signs)`

Builds complete phrase from sign sequence.

**Parameters:**
- `signs` - List of detected signs

**Returns:** `String` - Complete translation

##### `getSignDefinition(String label)`

Gets detailed definition for sign.

**Parameters:**
- `label` - Sign label

**Returns:** `Future<String>` - Sign definition

---

## Face Recognition Service

### FaceRecognitionService

Face enrollment and recognition for person identification.

```dart
final faceService = FaceRecognitionService();
```

#### Methods

##### `initialize()`

Initializes face recognition system.

**Returns:** `Future<void>`

##### `enrollFace(String personId, List<CameraImage> samples)`

Enrolls face with multiple samples.

**Parameters:**
- `personId` - Unique person identifier
- `samples` - Multiple face images

**Returns:** `Future<void>`

##### `recognizeFace(CameraImage frame)`

Recognizes face in camera frame.

**Parameters:**
- `frame` - Camera frame containing face

**Returns:** `Future<FaceRecognitionResult?>`

---

## Error Handling

All services implement consistent error handling:

```dart
try {
  await service.initialize();
} on PermissionException catch (e) {
  // Handle permission errors
  print('Permission required: ${e.userMessage}');
} on ModelLoadException catch (e) {
  // Handle model loading errors
  print('Model error: ${e.modelType} - ${e.message}');
} catch (e) {
  // Handle general errors
  print('Error: $e');
}
```

## Performance Considerations

### Model Loading
- Load models asynchronously to avoid UI blocking
- Cache loaded models for reuse across sessions
- Use FP16 quantization for mobile optimization

### Memory Management
- Process frames in background threads
- Release camera resources when not needed
- Monitor memory usage and adjust quality accordingly

### Battery Optimization
- Reduce inference frequency when app is backgrounded
- Use lower resolution for continuous processing
- Implement intelligent frame skipping

## Testing

All services include comprehensive test coverage:

```bash
# Run service tests
flutter test test/services/

# Run integration tests
flutter test integration_test/
```

## Platform Differences

### iOS
- Uses AVFoundation for camera and audio
- NSCameraUsageDescription required in Info.plist
- Uses iOS Speech framework for TTS

### Android
- Uses Camera2 API for camera access
- CAMERA and RECORD_AUDIO permissions required
- Uses Android TextToSpeech API

---

For more detailed implementation examples, see the [GitHub repository](https://github.com/signsync/signsync) and individual service test files.