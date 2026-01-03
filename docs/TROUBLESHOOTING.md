# SignSync Troubleshooting Guide

## 🔧 Common Issues & Solutions

### 🚫 Camera Issues

#### Camera Permission Denied
**Problem**: App shows "Camera permission required" message
**Symptoms**: 
- Black camera screen
- Permission denied error
- "Camera unavailable" message

**Solutions**:
1. **Enable Camera Permission**
   - Android: Settings > Apps > SignSync > Permissions > Camera > Allow
   - iOS: Settings > Privacy & Security > Camera > SignSync > Enable

2. **Manual Permission Request**
   ```dart
   // Check current permission status
   final status = await Permission.camera.status;
   if (status.isDenied) {
     // Request permission
     final result = await Permission.camera.request();
     if (result.isGranted) {
       // Proceed with camera initialization
       await cameraService.initialize();
     }
   }
   ```

3. **Restart App**
   - Close SignSync completely
   - Restart the app
   - Grant permission when prompted

#### Camera Not Starting
**Problem**: Camera fails to initialize or start
**Symptoms**:
- "Camera initialization failed" error
- Long loading times (>10 seconds)
- App freeze when starting camera

**Solutions**:
1. **Check Camera Availability**
   ```dart
   final cameras = await availableCameras();
   if (cameras.isEmpty) {
     // No cameras available - device issue
     showDialog('No cameras found on this device');
   }
   ```

2. **Restart Camera Service**
   ```dart
   await cameraService.dispose();
   await Future.delayed(Duration(seconds: 2));
   await cameraService.initialize();
   ```

3. **Clear Camera Cache**
   - Android: Settings > Apps > SignSync > Storage > Clear Cache
   - iOS: Delete and reinstall app

4. **Check Device Compatibility**
   - Ensure Android 8.0+ or iOS 13.0+
   - Minimum 2GB RAM recommended
   - Camera resolution: 720p minimum

#### Low Light Performance
**Problem**: Camera quality poor in low light conditions
**Symptoms**:
- Dark, noisy video feed
- Frequent ML detection failures
- High battery usage

**Solutions**:
1. **Enable Flash**
   - Tap flash icon in camera interface
   - Enable auto-flash mode
   - Ensure flash is available on device

2. **Improve Lighting**
   - Move to better lit area
   - Use device's screen as light source
   - Position subject near window

3. **Adjust Camera Settings**
   ```dart
   // Enable low-light optimization
   await cameraService.optimizeForLowLight();
   
   // Check auto-flash suggestion
   final shouldUseFlash = await cameraService.shouldEnableFlashForLowLight();
   if (shouldUseFlash) {
     await cameraService.autoEnableFlashIfNeeded();
   }
   ```

### 🧠 ML Model Issues

#### Model Loading Failed
**Problem**: ML models fail to load or initialize
**Symptoms**:
- "Model initialization failed" error
- No ASL translation results
- Object detection not working

**Solutions**:
1. **Verify Model Files**
   ```bash
   # Check if model files exist
   ls -la assets/models/
   # Should contain:
   # - asl_cnn.tflite
   # - asl_lstm.tflite
   # - yolov11.tflite
   # - face_recognition.tflite
   ```

2. **Download Missing Models**
   ```dart
   // Check model availability
   final modelExists = await File('assets/models/asl_cnn.tflite').exists();
   if (!modelExists) {
     // Download model from network
     await ModelUpdateService.downloadMissingModels();
   }
   ```

3. **Clear Model Cache**
   - Android: Settings > Apps > SignSync > Storage > Clear Cache
   - iOS: Delete and reinstall app
   - Restart app after clearing

4. **Check Device Storage**
   - Ensure at least 500MB free space
   - Models require ~200MB total

#### Slow Inference Performance
**Problem**: ML processing is too slow (>500ms)
**Symptoms**:
- Laggy real-time translation
- Low FPS (under 15)
- High battery drain

**Solutions**:
1. **Enable Performance Mode**
   ```dart
   // Optimize for performance
   await mlOrchestrator.enablePerformanceMode();
   
   // Enable adaptive inference
   await mlOrchestrator.setAdaptiveInference(true);
   ```

2. **Reduce Model Complexity**
   ```dart
   // Use smaller models for low-end devices
   await mlOrchestrator.useLightweightModels();
   
   // Increase inference frequency threshold
   await mlOrchestrator.setInferenceFrequency(200); // Every 200ms
   ```

3. **Close Other Apps**
   - Close background applications
   - Restart device if memory usage is high
   - Enable battery optimization mode

4. **Device-Specific Optimization**
   ```dart
   // Optimize for device capability
   final deviceInfo = await DeviceInfoPlugin().androidInfo;
   if (deviceInfo.totalMemory < 3 * 1024 * 1024 * 1024) {
     // Low-memory device optimization
     await mlOrchestrator.optimizeForLowMemoryDevice();
   }
   ```

### 🔊 Audio/TTS Issues

#### No Audio Output
**Problem**: TTS not working or no sound alerts
**Symptoms**:
- Silent object detection alerts
- No AI assistant voice responses
- "Audio service unavailable" error

**Solutions**:
1. **Check Audio Permissions**
   - Android: Settings > Apps > SignSync > Permissions > Microphone > Allow
   - iOS: Settings > Privacy & Security > Microphone > SignSync > Enable

2. **Verify TTS Engine**
   ```dart
   // Check TTS availability
   final isAvailable = await flutterTts.isLanguageAvailable('en-US');
   if (!isAvailable) {
     // Try alternative language
     await flutterTts.setLanguage('en-GB');
   }
   ```

3. **Adjust Audio Settings**
   ```dart
   // Increase volume
   await ttsService.setVolume(1.0);
   
   // Adjust speech rate
   await ttsService.setSpeechRate(1.0);
   
   // Enable spatial audio
   await ttsService.enableSpatialAudio(true);
   ```

4. **Device Audio Settings**
   - Check device volume levels
   - Disable "Do Not Disturb" mode
   - Ensure ringer is not muted
   - Check Bluetooth audio device connection

#### Spatial Audio Not Working
**Problem**: Can't hear left/right positioning in alerts
**Symptoms**:
- All sounds come from center
- No directional audio cues
- Missing "left/right" positioning

**Solutions**:
1. **Enable Spatial Audio**
   ```dart
   // Check if spatial audio is enabled
   if (!ttsService.spatialAudioEnabled) {
     await ttsService.enableSpatialAudio(true);
   }
   ```

2. **Check Audio Format**
   - Ensure device supports stereo audio
   - Use headphones for best spatial experience
   - Check device audio settings

3. **Test Spatial Zones**
   - Move object to left side of screen
   - Should hear "on your left, [object]"
   - Move to right side for "on your right"

### 🤖 AI Assistant Issues

#### AI Not Responding
**Problem**: AI assistant doesn't respond to messages
**Symptoms**:
- "AI service unavailable" message
- Long loading times (>30 seconds)
- Network timeout errors

**Solutions**:
1. **Check API Configuration**
   ```dart
   // Verify API key
   if (ApiConfig.geminiApiKey.isEmpty) {
     // API key missing
     showDialog('AI service not configured');
   }
   ```

2. **Network Connectivity**
   - Check internet connection
   - Disable VPN if active
   - Try different WiFi/mobile data

3. **Rate Limiting**
   ```dart
   // Check if rate limited
   final canMakeRequest = geminiAiService.checkRateLimit();
   if (!canMakeRequest) {
     final waitTime = geminiAiService.getRateLimitWaitTime();
     showDialog('Please wait ${waitTime.inSeconds} seconds');
   }
   ```

4. **Offline Mode**
   - App automatically falls back to offline responses
   - Check if offline mode is active
   - Limited but functional responses available

#### Poor AI Responses
**Problem**: AI responses are irrelevant or incorrect
**Symptoms**:
- Off-topic responses
- Incorrect sign language information
- Inappropriate responses

**Solutions**:
1. **Context Reset**
   ```dart
   // Clear chat history
   await geminiAiService.clearChatHistory();
   
   // Restart conversation
   await geminiAiService.sendMessage('Hello, I need help with ASL');
   ```

2. **Improve Prompt**
   - Be more specific in questions
   - Provide context in messages
   - Use proper ASL terminology

3. **Update System Prompt**
   - Check if app has latest AI configuration
   - Restart app to refresh AI context

### 📱 Performance Issues

#### App Running Slowly
**Problem**: General app performance is poor
**Symptoms**:
- Slow screen transitions
- Delayed button responses
- High memory usage

**Solutions**:
1. **Restart App**
   - Close SignSync completely
   - Wait 10 seconds
   - Restart app

2. **Clear App Cache**
   - Android: Settings > Apps > SignSync > Storage > Clear Cache
   - iOS: Delete and reinstall app

3. **Close Background Apps**
   - Close unnecessary running apps
   - Free up device memory
   - Restart device if needed

4. **Enable Performance Mode**
   ```dart
   // Enable all performance optimizations
   await performanceOptimizer.enableMaximumPerformance();
   ```

#### High Battery Usage
**Problem**: App drains battery quickly
**Symptoms**:
- Battery drains >10% per hour
- Device gets warm during use
- Background battery usage

**Solutions**:
1. **Enable Battery Optimization**
   ```dart
   // Enable battery saving mode
   await mlOrchestrator.enableBatteryOptimization();
   
   // Reduce inference frequency
   await mlOrchestrator.setInferenceFrequency(500); // Every 500ms
   ```

2. **Disable Non-Essential Features**
   - Turn off spatial audio
   - Reduce camera resolution
   - Disable always-on detection

3. **Check Device Settings**
   - Android: Settings > Battery > Battery Optimization > SignSync > Don't optimize
   - Ensure app can run in background when needed

4. **Update App**
   - Check for app updates
   - Performance improvements in newer versions

### 🔒 Privacy & Security Issues

#### Data Not Syncing
**Problem**: Settings or data not saving properly
**Symptoms**:
- Settings reset after restart
- Chat history lost
- User preferences not applied

**Solutions**:
1. **Check Storage Permissions**
   - Android: Settings > Apps > SignSync > Permissions > Storage > Allow
   - iOS: Settings > Privacy & Security > Photos > SignSync > Full Access

2. **Verify Encryption**
   ```dart
   // Check if storage service is working
   final isEncrypted = await storageService.isDataEncrypted();
   if (!isEncrypted) {
     // Re-initialize encryption
     await storageService.reinitializeEncryption();
   }
   ```

3. **Clear Corrupted Data**
   ```dart
   // Reset to defaults
   await settingsService.resetToDefaults();
   await storageService.clearAllData();
   ```

#### Privacy Concerns
**Problem**: Worried about data privacy
**Symptoms**:
- Questions about data collection
- Concerns about cloud uploads
- Request for privacy information

**Solutions**:
1. **Privacy Information**
   ```dart
   // Show privacy information
   showDialog(
     'SignSync Privacy Policy',
     content: '''
     • All ML processing happens on-device
     • No cloud uploads of camera data
     • Face recognition data stays local
     • Chat history encrypted locally
     • No tracking or analytics by default
     ''',
   );
   ```

2. **Data Export**
   ```dart
   // Allow users to export their data
   await storageService.exportUserData();
   ```

3. **Data Deletion**
   ```dart
   // Allow users to delete all data
   await storageService.deleteAllUserData();
   ```

## 🐛 Debugging Tools

### Enable Debug Mode
```dart
// Enable debug logging
LoggerService.setLevel(LogLevel.debug);

// Enable performance monitoring
PerformanceMonitor.enableProfiling();

// Check service health
final health = await mlOrchestrator.performHealthCheck();
print('Service Health: $health');
```

### Log Analysis
```bash
# View app logs (Android)
adb logcat | grep SignSync

# View crash logs (iOS)
Xcode > Devices > View Device Logs

# Performance profiling
flutter run --profile --enable-software-rendering
```

### Test Commands
```bash
# Run all tests
flutter test --coverage

# Test specific features
flutter test test/services/camera_service_test.dart
flutter test test/services/ml_orchestrator_service_test.dart

# Integration tests
flutter test integration_test/

# Accessibility tests
flutter test test/accessibility/
```

## 📞 Getting Help

### Self-Help Resources
1. **In-App Help**
   - Settings > Help & Support
   - Tutorial screens (first-time users)
   - FAQ section

2. **Online Resources**
   - Documentation: https://docs.signsync.app
   - FAQ: https://signsync.app/faq
   - Video tutorials: https://youtube.com/signsync

### Contact Support
- **Email**: support@signsync.app
- **Response Time**: 24-48 hours
- **Include**: Device model, OS version, app version, detailed issue description

### Report Bugs
- **GitHub Issues**: https://github.com/your-org/signsync/issues
- **Include**: Steps to reproduce, expected vs actual behavior, logs
- **Severity Levels**:
  - Critical: App crash, data loss
  - High: Major feature broken
  - Medium: Feature works but with issues
  - Low: Minor UI issues, suggestions

### Feature Requests
- **User Feedback**: support@signsync.app
- **Community Forum**: https://community.signsync.app
- **Upvote existing requests**: GitHub issues

## 🔧 Advanced Troubleshooting

### Device-Specific Issues

#### Samsung Galaxy Devices
- **Issue**: Camera crashes on Samsung devices
- **Solution**: Disable Samsung camera optimization
  ```dart
  // Samsung-specific camera settings
  await cameraService.disableSamsungOptimizations();
  ```

#### OnePlus Devices
- **Issue**: Background app killing
- **Solution**: Add to battery optimization whitelist
  - Settings > Battery > Battery Optimization > SignSync > Don't optimize

#### iPhone Devices
- **Issue**: Microphone not working on iOS
- **Solution**: Reset privacy settings
  - Settings > Privacy & Security > Microphone > Reset
  - Restart app and re-grant permissions

### Performance Profiling
```dart
// Memory usage monitoring
class MemoryProfiler {
  static void startMonitoring() {
    Timer.periodic(Duration(seconds: 30), (timer) {
      final info = ProcessInfo.currentRss;
      final mb = info / (1024 * 1024);
      print('Memory Usage: ${mb.toStringAsFixed(1)} MB');
      
      if (mb > 500) {
        // Trigger memory warning
        MemoryManager.triggerMemoryWarning();
      }
    });
  }
}
```

### Network Debugging
```dart
// Network connectivity check
class NetworkDebugger {
  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  static void logNetworkState() {
    Connectivity().onConnectivityChanged.listen((result) {
      print('Network state: $result');
    });
  }
}
```

This comprehensive troubleshooting guide covers the most common issues users might encounter with SignSync, along with detailed solutions and debugging tools to ensure a smooth user experience.