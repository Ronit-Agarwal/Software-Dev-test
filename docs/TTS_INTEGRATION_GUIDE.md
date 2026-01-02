# TTS Integration Guide

## Overview

The TTS (Text-to-Speech) service provides real-time audio alerts for object detection, integrated with native platform TTS engines:
- **iOS**: AVSpeechSynthesizer (Speech Framework)
- **Android**: TextToSpeech API

## Features

### 1. Native Platform TTS
- Automatic platform-specific TTS engine selection
- Support for multiple languages and voices
- Hardware acceleration for smooth playback

### 2. Alert Priority System
Objects are prioritized for audio announcements:

**Critical Priority** (immediate):
- person

**High Priority** (important):
- car, truck, bus, motorcycle, bicycle (vehicles)
- traffic light, stop sign (signage)

**Medium Priority** (obstacles):
- chair, couch, table, bench (furniture)
- door, stair (navigation hazards)

**Low Priority** (general):
- bottle, cup, book, laptop, cell phone, clock, tv

### 3. Spatial Audio Support
Based on object position in the camera frame:
- **Left zone**: "Person to your left, 5 feet ahead"
- **Center zone**: "Chair, 2 feet ahead"
- **Right zone**: "Car to your right, 10 feet ahead"

### 4. Audio Result Caching
- Prevents duplicate announcements within 5 seconds
- Cache key based on object label and distance
- Automatic cleanup of old cache entries
- Reduces unnecessary speech and user fatigue

### 5. Volume Control
- Adjustable volume: 0.0 to 1.0
- Adjustable speech rate: 0.0 to 1.0 (1.0 = normal)
- Adjustable pitch: 0.5 to 2.0
- Persisted settings across sessions

### 6. Queue Management
- Priority-based alert queue
- Processes up to 3 alerts per frame
- Automatically queues high-priority alerts
- Graceful handling of concurrent requests

## Installation

### 1. Add Dependency

The `flutter_tts: ^3.8.5` package is already added to `pubspec.yaml`.

### 2. iOS Configuration

No additional configuration required. iOS uses AVSpeechSynthesizer from the Speech Framework.

### 3. Android Configuration

No additional configuration required. Android uses the system TextToSpeech API.

## Usage

### Basic TTS Usage

```dart
import 'package:signsync/services/tts_service.dart';

final ttsService = TtsService();

// Initialize TTS
await ttsService.initialize();

// Speak text
await ttsService.speak('Hello, world');

// Stop speech
await ttsService.stop();

// Pause speech
await ttsService.pause();

// Resume speech
await ttsService.resume();
```

### Audio Alerts for Object Detection

```dart
// Generate alert for single object
final object = DetectedObject(
  label: 'person',
  displayName: 'Person',
  confidence: 0.92,
  boundingBox: Rect.fromLTWH(100, 200, 150, 300),
  distance: 1.5, // meters
);

await ttsService.generateAlert(object);
// Output: "Person, 5 feet ahead" or "Person to your left, 5 feet ahead"

// Generate alerts for multiple objects
final objects = [object1, object2, object3];
await ttsService.generateAlerts(objects);
// Automatically sorted by priority and confidence
```

### Configuration

```dart
// Set volume (0.0 - 1.0)
await ttsService.setVolume(0.8);

// Set speech rate (0.0 - 1.0, where 1.0 is normal)
await ttsService.setSpeechRate(0.9);

// Set pitch (0.5 - 2.0)
await ttsService.setPitch(1.0);

// Enable/disable spatial audio
ttsService.setSpatialAudioEnabled(true);

// Change language
await ttsService.setLanguage('en-US');

// Get available languages
final languages = await ttsService.getLanguages();
print('Available languages: $languages');
```

### Integration with ML Orchestrator

```dart
// Audio alerts are automatically generated during object detection
final orchestrator = MlOrchestratorService();

// Enable audio alerts
orchestrator.setAudioAlertsEnabled(true);

// Enable spatial audio
orchestrator.setSpatialAudioEnabled(true);

// Adjust TTS settings
await orchestrator.setTtsVolume(0.8);
await orchestrator.setTtsSpeechRate(0.9);

// Process camera frame (alerts generated automatically)
final result = await orchestrator.processFrame(cameraImage);

// Disable audio alerts
orchestrator.setAudioAlertsEnabled(false);
```

### Monitoring and Statistics

```dart
// Check if speaking
if (ttsService.isSpeaking) {
  print('Currently speaking...');
}

// Get statistics
final stats = ttsService.statistics;
print('Total alerts: ${stats['totalAlerts']}');
print('Duplicates filtered: ${stats['duplicatesFiltered']}');
print('Average speech duration: ${stats['averageSpeechDuration']}ms');
print('Queue size: ${stats['queuedAlerts']}');
print('Volume: ${stats['volume']}');
print('Speech rate: ${stats['speechRate']}');
```

### Error Handling

```dart
try {
  await ttsService.initialize();
} on TtsException catch (e) {
  print('TTS error: ${e.message}');
  // Fallback: Use visual alerts only
}

try {
  await ttsService.speak('Alert message');
} catch (e) {
  print('Failed to speak: $e');
  // Fallback: Show visual notification
}
```

## Alert Message Format

Alerts follow a consistent format:

```
{object_name} [{direction}], {distance}
```

Examples:
- "Person, 5 feet ahead"
- "Person to your left, 5 feet ahead"
- "Chair, 2 feet ahead"
- "Car to your right, 10 feet ahead"

### Distance Formatting

| Distance (meters) | Speech Text |
|-------------------|-------------|
| < 0.3             | "very close" |
| 0.3 - 0.9         | "a few feet ahead" |
| 1 - 3             | "3 feet ahead" |
| 3 - 10            | "X feet ahead" |
| > 10              | "about X0 feet ahead" |

## Performance Optimization

### 1. Duplicate Filtering
- Cache-based duplicate detection
- 5-second cooldown per object
- Prevents repetitive announcements

### 2. Priority Queue
- Critical alerts first (person, vehicles)
- High-confidence objects prioritized
- Maximum 3 alerts per frame to avoid spam

### 3. Lazy Loading
- TTS engine initialized on-demand
- Audio session shared across app
- Minimal memory footprint

### 4. Asynchronous Processing
- Non-blocking alert generation
- Queue-based processing
- Graceful degradation on errors

## Performance Targets

| Metric | Target |
|--------|--------|
| TTS initialization | < 500ms |
| Alert generation | < 10ms |
| Speech start latency | < 100ms |
| Duplicate filtering | < 1ms |
| Memory usage | < 10MB |
| CPU usage | < 5% when idle |

## Troubleshooting

### TTS Not Speaking

1. Check initialization:
```dart
if (!ttsService.isInitialized) {
  await ttsService.initialize();
}
```

2. Check volume:
```dart
if (ttsService.volume == 0.0) {
  await ttsService.setVolume(0.8);
}
```

3. Check if audio is playing:
```dart
if (ttsService.isSpeaking) {
  print('Already speaking, will queue next alert');
}
```

### Too Many Alerts

1. Adjust duplicate cooldown:
```dart
// Edit TtsService._duplicateCooldown
static const Duration _duplicateCooldown = Duration(seconds: 10); // Increase
```

2. Reduce alerts per frame:
```dart
// Edit TtsService.generateAlerts
for (final object in sortedObjects.take(1)) { // Reduce from 3 to 1
  await generateAlert(object);
}
```

3. Increase confidence threshold:
```dart
// Filter by higher confidence
final sortedObjects = objects
    .where((obj) => obj.confidence >= 0.85) // Increase from 0.70
    .toList();
```

### Spatial Audio Not Working

1. Enable spatial audio:
```dart
ttsService.setSpatialAudioEnabled(true);
```

2. Check object position:
```dart
final direction = _calculateSpatialDirection(object);
print('Object direction: $direction');
```

## Best Practices

1. **Initialize Early**: Initialize TTS service during app startup
2. **Handle Errors**: Always wrap TTS calls in try-catch
3. **User Control**: Provide settings to enable/disable alerts
4. **Volume Awareness**: Respect device volume and silent mode
5. **Rate Limiting**: Don't overwhelm user with too many alerts
6. **Clear Messages**: Use simple, natural language
7. **Spatial Consistency**: Keep spatial audio direction terminology consistent

## Example Widget Integration

```dart
class ObjectDetectionScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends ConsumerState<ObjectDetectionScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize TTS
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orchestrator = ref.watch(mlOrchestratorProvider);
    final ttsService = ref.watch(ttsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Object Detection'),
        actions: [
          // Toggle audio alerts
          IconButton(
            icon: Icon(orchestrator.audioAlertsEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              orchestrator.setAudioAlertsEnabled(!orchestrator.audioAlertsEnabled);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview and detection overlay
          CameraPreviewWidget(),

          // Audio settings
          if (orchestrator.audioAlertsEnabled)
            Column(
              children: [
                Slider(
                  value: ttsService.volume,
                  onChanged: (value) => ttsService.setVolume(value),
                ),
                Slider(
                  value: ttsService.speechRate,
                  onChanged: (value) => ttsService.setSpeechRate(value),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

## Next Steps

The TTS integration is now complete and ready for use with object detection. The system will automatically generate spatial audio alerts when objects are detected in the camera feed.

Ready for **Task 7: English-to-ASL Translation**
