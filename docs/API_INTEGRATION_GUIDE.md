# SignSync API Integration Guide

Complete guide for integrating external APIs and services with SignSync for enhanced functionality.

## Table of Contents

- [Gemini AI API Integration](#gemini-ai-api-integration)
- [Text-to-Speech Integration](#text-to-speech-integration)
- [Google Translate API](#google-translate-api)
- [Firebase Services](#firebase-services)
- [Rate Limiting and Error Handling](#rate-limiting-and-error-handling)
- [Security Best Practices](#security-best-practices)

---

## Gemini AI API Integration

### Overview

SignSync integrates Google Gemini 2.5 Pro for the AI assistant feature, providing contextual help for ASL learning and app usage.

### Setup

#### 1. Get API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy the key securely

#### 2. Configure in App

```dart
// Add to environment variables
const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

// Or store securely in user settings
class GeminiConfig {
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String modelName = 'gemini-2.5-pro';
}
```

#### 3. Initialize Service

```dart
final geminiService = GeminiAiService();
await geminiService.initialize(
  apiKey: geminiApiKey,
  ttsService: ttsService,
);
```

### Usage Examples

#### Basic Chat

```dart
// Send message to AI assistant
final response = await geminiService.sendMessage(
  'How do I sign "thank you" in ASL?',
  includeContext: true,
);

print('AI Response: $response');
```

#### Context-Aware Conversations

```dart
// Provide app context for better responses
await geminiService.updateAppContext({
  'currentMode': 'asl_translation',
  'userLevel': 'beginner',
  'deviceInfo': DeviceInfo.model,
});

// Ask contextual question
final response = await geminiService.sendMessage(
  'Why is the camera not recognizing my signs?',
  includeContext: true,
);
```

#### Voice Integration

```dart
// Enable voice input/output
geminiService.setVoiceEnabled(true);

// AI will automatically use TTS for responses
final response = await geminiService.sendMessage(
  'Please explain ASL grammar basics',
  includeContext: true,
);
```

### Error Handling

```dart
try {
  final response = await geminiService.sendMessage(message);
} on GeminiApiException catch (e) {
  switch (e.code) {
    case 'quota_exceeded':
      // Show quota exceeded message
      break;
    case 'invalid_api_key':
      // Prompt for new API key
      break;
    case 'rate_limit_exceeded':
      // Implement retry logic
      break;
  }
} on NetworkException catch (e) {
  // Handle network issues
  // Provide offline fallback
}
```

### Rate Limiting

```dart
class GeminiRateLimiter {
  static const int maxRequestsPerMinute = 60;
  static const int maxRequestsPerDay = 1500;
  
  final Queue<DateTime> _requestTimestamps = Queue();
  
  Future<bool> canMakeRequest() async {
    final now = DateTime.now();
    
    // Remove old requests (older than 1 minute)
    _removeOldRequests(now, Duration(minutes: 1));
    
    // Check per-minute limit
    if (_requestTimestamps.length >= maxRequestsPerMinute) {
      return false;
    }
    
    // Check daily limit
    _removeOldRequests(now, Duration(days: 1));
    if (_requestTimestamps.length >= maxRequestsPerDay) {
      return false;
    }
    
    _requestTimestamps.add(now);
    return true;
  }
}
```

---

## Text-to-Speech Integration

### Platform-Specific TTS

#### Android (TextToSpeech)

```dart
class AndroidTtsService {
  late TextToSpeech _tts;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    _tts = TextToSpeech();
    
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);
    
    _isInitialized = true;
  }
  
  Future<void> speak(String text, {double volume = 1.0}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _tts.setVolume(volume);
    await _tts.speak(text);
  }
  
  Future<void> stop() async {
    await _tts.stop();
  }
  
  void dispose() {
    _tts.stop();
    _tts.shutdown();
  }
}
```

#### iOS (AVSpeechSynthesizer)

```dart
class IosTtsService {
  late AVSpeechSynthesizer _synthesizer;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    _synthesizer = AVSpeechSynthesizer();
    _isInitialized = true;
  }
  
  Future<void> speak(String text, {String language = 'en-US'}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final utterance = AVSpeechUtterance(string: text);
    utterance.voice = AVSpeechSynthesisVoice(languageCode: language);
    utterance.rate = 0.5;
    utterance.pitch = 1.0;
    
    await _synthesizer.speak(utterance);
  }
  
  Future<void> stop() async {
    _synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate);
  }
}
```

### Unified TTS Interface

```dart
abstract class TtsServiceInterface {
  Future<void> initialize();
  Future<void> speak(String text, {String? language});
  Future<void> stop();
  void dispose();
  bool get isSpeaking;
}

class TtsService implements TtsServiceInterface {
  late TtsServiceInterface _platformTts;
  
  Future<void> initialize() async {
    if (Platform.isAndroid) {
      _platformTts = AndroidTtsService();
    } else if (Platform.isIOS) {
      _platformTts = IosTtsService();
    } else {
      throw UnsupportedError('Platform not supported');
    }
    
    await _platformTts.initialize();
  }
  
  // Delegate all calls to platform implementation
  Future<void> speak(String text, {String? language}) =>
      _platformTts.speak(text, language: language);
      
  Future<void> stop() => _platformTts.stop();
  void dispose() => _platformTts.dispose();
  bool get isSpeaking => _platformTts.isSpeaking;
}
```

### Spatial Audio Integration

```dart
class SpatialAudioTts {
  final TtsServiceInterface _tts;
  
  SpatialAudioTts(this._tts);
  
  Future<void> speakWithPosition(
    String text,
    String position, // e.g., "3 o'clock"
  ) async {
    final spatialText = '$text at $position';
    await _tts.speak(spatialText);
  }
  
  Future<void> speakObjectDetection(
    String object,
    String position,
    String distance,
  ) async {
    final message = '$object detected at $position, approximately $distance';
    await _tts.speak(message);
  }
  
  Future<void> speakEmergencyAlert(String alert) async {
    // Use urgent tone and repeat
    await _tts.speak('EMERGENCY: $alert');
    await Future.delayed(Duration(seconds: 2));
    await _tts.speak(alert);
  }
}
```

---

## Google Translate API

### Setup

#### 1. Enable Translation API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable Cloud Translation API
4. Create credentials (API Key or Service Account)

#### 2. Configuration

```dart
class TranslateConfig {
  static const String baseUrl = 'https://translation.googleapis.com/language/translate/v2';
  static const String apiKey = String.fromEnvironment('TRANSLATE_API_KEY');
}
```

### Basic Translation

```dart
class GoogleTranslateService {
  final String _apiKey;
  
  GoogleTranslateService(this._apiKey);
  
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final uri = Uri.parse('${TranslateConfig.baseUrl}?key=$_apiKey');
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'target': targetLanguage,
        'source': sourceLanguage,
        'format': 'text',
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['translations'][0]['translatedText'];
    } else {
      throw TranslateException('Translation failed: ${response.statusCode}');
    }
  }
  
  Future<List<String>> detectLanguage(String text) async {
    final uri = Uri.parse('https://translation.googleapis.com/language/translate/v2/detect?key=$_apiKey');
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'q': text}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['detections'][0]
          .map((detection) => detection['language'] as String)
          .toList();
    } else {
      throw TranslateException('Language detection failed');
    }
  }
}
```

### Batch Translation for ASL

```dart
class AslTranslationService {
  final GoogleTranslateService _translateService;
  
  AslTranslationService(this._translateService);
  
  Future<String> translateAslToText(List<String> signs) async {
    // Convert ASL signs to English text
    final englishText = _convertSignsToText(signs);
    
    // Translate to user's preferred language
    final targetLang = UserPreferences.getLanguage();
    
    if (targetLang == 'en') {
      return englishText;
    }
    
    return await _translateService.translate(
      text: englishText,
      targetLanguage: targetLang,
      sourceLanguage: 'en',
    );
  }
  
  String _convertSignsToText(List<String> signs) {
    // Implement ASL to English conversion
    // This would use your ASL translation logic
    return signs.join(' ');
  }
}
```

---

## Firebase Services

### Firebase Configuration

#### Android Setup

```dart
// android/app/google-services.json (download from Firebase Console)
// android/app/build.gradle
dependencies {
    implementation 'com.google.firebase:firebase-analytics:21.2.0'
    implementation 'com.google.firebase:firebase-crashlytics:18.2.2'
}

// android/app/src/main/AndroidManifest.xml
<application>
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
</application>
```

#### iOS Setup

```dart
// ios/Runner/GoogleService-Info.plist (download from Firebase Console)
// ios/Runner/Podfile
target 'Runner' do
  use_frameworks!
  use_modular_headers!
  
  pod 'Firebase/Crashlytics'
  pod 'Firebase/Analytics'
end

// ios/Runner/Info.plist
<key>NSUserTrackingUsageDescription</key>
<string>This app uses tracking for analytics to improve user experience.</string>
```

### Analytics Integration

```dart
class FirebaseAnalyticsService {
  static FirebaseAnalytics? _analytics;
  
  static void initialize() {
    if (_analytics == null) {
      _analytics = FirebaseAnalytics.instance;
    }
  }
  
  static void trackAslDetection({
    required String sign,
    required double confidence,
    required String mode,
  }) {
    _analytics?.logEvent(
      name: 'asl_detection',
      parameters: {
        'sign': sign,
        'confidence': confidence,
        'mode': mode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  static void trackObjectDetection({
    required String object,
    required double confidence,
    required String position,
  }) {
    _analytics?.logEvent(
      name: 'object_detection',
      parameters: {
        'object': object,
        'confidence': confidence,
        'position': position,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  static void trackUserEngagement({
    required String action,
    required String screen,
    Map<String, dynamic>? parameters,
  }) {
    _analytics?.logEvent(
      name: 'user_engagement',
      parameters: {
        'action': action,
        'screen': screen,
        ...?parameters,
      },
    );
  }
}
```

### Crashlytics Integration

```dart
class CrashlyticsService {
  static void initialize() {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  static void recordError(dynamic error, StackTrace stackTrace, {bool fatal = false}) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: fatal);
  }
  
  static void recordCustomError({
    required String message,
    required String type,
    Map<String, dynamic>? context,
  }) {
    FirebaseCrashlytics.instance.log('Custom Error: $message');
    FirebaseCrashlytics.instance.setCustomKey('error_type', type);
    
    if (context != null) {
      context.forEach((key, value) {
        FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      });
    }
  }
}
```

### Remote Config

```dart
class RemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  
  static Future<void> initialize() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    
    await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    await _remoteConfig!.setDefaults({
      'confidence_threshold': 0.85,
      'max_detection_distance': 10.0,
      'feature_flags': {
        'new_ui': false,
        'beta_features': false,
      },
    });
    
    await fetchConfig();
  }
  
  static Future<void> fetchConfig() async {
    try {
      await _remoteConfig!.fetchAndActivate();
    } catch (e) {
      // Use default values if fetch fails
    }
  }
  
  static double getConfidenceThreshold() {
    return _remoteConfig!.getDouble('confidence_threshold');
  }
  
  static bool isFeatureEnabled(String feature) {
    final flags = _remoteConfig!.getMap('feature_flags');
    return flags[feature] ?? false;
  }
}
```

---

## Rate Limiting and Error Handling

### Rate Limiting Implementation

```dart
class RateLimiter {
  final int maxRequests;
  final Duration timeWindow;
  final Queue<DateTime> _requests = Queue();
  
  RateLimiter({
    required this.maxRequests,
    required this.timeWindow,
  });
  
  Future<bool> canMakeRequest() async {
    final now = DateTime.now();
    _removeOldRequests(now);
    
    if (_requests.length >= maxRequests) {
      return false;
    }
    
    _requests.add(now);
    return true;
  }
  
  void _removeOldRequests(DateTime now) {
    while (_requests.isNotEmpty && 
           now.difference(_requests.first) > timeWindow) {
      _requests.removeFirst();
    }
  }
  
  Duration getTimeUntilNextRequest() {
    if (_requests.isEmpty) return Duration.zero;
    
    final oldestRequest = _requests.first;
    final now = DateTime.now();
    final elapsed = now.difference(oldestRequest);
    
    if (elapsed > timeWindow) return Duration.zero;
    
    return timeWindow - elapsed;
  }
}
```

### Exponential Backoff

```dart
class ExponentialBackoff {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 1);
  
  static Future<T> executeWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = maxRetries,
    Duration baseDelay = baseDelay,
  }) async {
    int retryCount = 0;
    
    while (retryCount <= maxRetries) {
      try {
        return await operation();
      } catch (e) {
        if (retryCount == maxRetries) {
          rethrow;
        }
        
        final delay = baseDelay * (2 ^ retryCount);
        await Future.delayed(delay);
        retryCount++;
      }
    }
    
    throw Exception('Max retries exceeded');
  }
}
```

### Comprehensive Error Handling

```dart
class ApiErrorHandler {
  static Exception handleApiError(int statusCode, String message) {
    switch (statusCode) {
      case 400:
        return BadRequestException(message);
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 429:
        return RateLimitException(message);
      case 500:
        return InternalServerErrorException(message);
      case 502:
      case 503:
      case 504:
        return ServiceUnavailableException(message);
      default:
        return ApiException('HTTP $statusCode: $message');
    }
  }
  
  static bool isRetryableError(int statusCode) {
    return [408, 429, 500, 502, 503, 504].contains(statusCode);
  }
}

abstract class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}

class BadRequestException extends ApiException {
  BadRequestException(String message) : super('Bad Request: $message');
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super('Unauthorized: $message');
}

class RateLimitException extends ApiException {
  RateLimitException(String message) : super('Rate Limited: $message');
}
```

---

## Security Best Practices

### API Key Management

```dart
class SecureApiKeyManager {
  static const String _keyAlias = 'signsync_api_keys';
  static const String _geminiKeyAlias = 'gemini_api_key';
  
  static Future<void> storeApiKey(String service, String key) async {
    final storage = FlutterSecureStorage();
    
    switch (service) {
      case 'gemini':
        await storage.write(key: _geminiKeyAlias, value: key);
        break;
      case 'translate':
        await storage.write(key: 'translate_api_key', value: key);
        break;
    }
  }
  
  static Future<String?> getApiKey(String service) async {
    final storage = FlutterSecureStorage();
    
    switch (service) {
      case 'gemini':
        return await storage.read(key: _geminiKeyAlias);
      case 'translate':
        return await storage.read(key: 'translate_api_key');
      default:
        return null;
    }
  }
  
  static Future<void> deleteApiKey(String service) async {
    final storage = FlutterSecureStorage();
    
    switch (service) {
      case 'gemini':
        await storage.delete(key: _geminiKeyAlias);
        break;
      case 'translate':
        await storage.delete(key: 'translate_api_key');
        break;
    }
  }
}
```

### Request Signing and Validation

```dart
class ApiRequestSigner {
  static String generateSignature({
    required String url,
    required Map<String, dynamic> body,
    required String apiSecret,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final sortedBody = _sortJsonKeys(body);
    final payload = '$url:$sortedBody:$timestamp:$apiSecret';
    
    return base64Encode(utf8.encode(payload));
  }
  
  static Map<String, dynamic> _sortJsonKeys(Map<String, dynamic> json) {
    final sorted = <String, dynamic>{};
    final keys = json.keys.toList()..sort();
    
    for (final key in keys) {
      sorted[key] = json[key];
    }
    
    return sorted;
  }
}
```

### Data Privacy and Encryption

```dart
class DataEncryption {
  static const String _algorithm = 'AES/GCM/NoPadding';
  static const int _keyLength = 32; // 256 bits
  
  static EncryptedData encrypt(String data, String key) {
    final keyBytes = utf8.encode(key.padRight(_keyLength, '0')).sublist(0, _keyLength);
    final iv = SecureRandom().bytes(12); // 96 bits for GCM
    
    final encrypter = Encrypter(AES(Key.fromSecureRandom(_keyLength)));
    final encrypted = encrypter.encrypt(data, iv: IV(iv));
    
    return EncryptedData(encrypted.base64, base64Encode(iv));
  }
  
  static String decrypt(EncryptedData encryptedData, String key) {
    final keyBytes = utf8.encode(key.padRight(_keyLength, '0')).sublist(0, _keyLength);
    final iv = base64Decode(encryptedData.iv);
    
    final encrypter = Encrypter(AES(Key.fromBase64(base64Encode(keyBytes))));
    final decrypted = encrypter.decrypt64(encryptedData.data, iv: IV(iv));
    
    return decrypted;
  }
}

class EncryptedData {
  final String data;
  final String iv;
  
  EncryptedData(this.data, this.iv);
}
```

### Request Validation

```dart
class RequestValidator {
  static bool isValidApiKey(String key) {
    // Basic validation for API key format
    if (key.isEmpty || key.length < 10) return false;
    
    // Check for suspicious patterns
    final suspiciousPatterns = ['admin', 'test', 'temp', 'demo'];
    final lowerKey = key.toLowerCase();
    
    return !suspiciousPatterns.any((pattern) => lowerKey.contains(pattern));
  }
  
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return ['https'].contains(uri.scheme) && 
             !uri.hasFragment &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  static bool isValidRequestBody(Map<String, dynamic> body) {
    // Check for size limits
    final jsonString = jsonEncode(body);
    if (jsonString.length > 1024 * 1024) { // 1MB limit
      return false;
    }
    
    // Check for forbidden fields
    final forbiddenFields = ['password', 'secret', 'token', 'key'];
    final lowerKeys = body.keys.map((k) => k.toLowerCase());
    
    return !forbiddenFields.any((field) => lowerKeys.contains(field));
  }
}
```

### Audit Logging

```dart
class AuditLogger {
  static void logApiRequest({
    required String service,
    required String endpoint,
    required String method,
    required int statusCode,
    required Duration responseTime,
    Map<String, dynamic>? parameters,
  }) {
    final log = {
      'timestamp': DateTime.now().toIso8601String(),
      'service': service,
      'endpoint': endpoint,
      'method': method,
      'status_code': statusCode,
      'response_time_ms': responseTime.inMilliseconds,
      'parameters': parameters,
      'user_agent': _getUserAgent(),
    };
    
    // Log to secure storage or send to audit service
    _storeAuditLog(log);
  }
  
  static void logSecurityEvent({
    required String event,
    required String severity,
    required String description,
    Map<String, dynamic>? context,
  }) {
    final log = {
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      'severity': severity,
      'description': description,
      'context': context,
    };
    
    // High severity events should be sent immediately
    if (severity == 'critical' || severity == 'high') {
      _sendSecurityAlert(log);
    }
    
    _storeSecurityLog(log);
  }
  
  static String _getUserAgent() {
    // Get app version, platform, and device info
    return 'SignSync/1.0.0 (${Platform.operatingSystem})';
  }
  
  static void _storeAuditLog(Map<String, dynamic> log) {
    // Store in local secure storage
    final storage = FlutterSecureStorage();
    final logId = 'audit_${DateTime.now().millisecondsSinceEpoch}';
    
    storage.write(
      key: logId,
      value: jsonEncode(log),
    );
  }
  
  static void _sendSecurityAlert(Map<String, dynamic> log) {
    // Send to security monitoring service
    // This could be Firebase Functions, AWS Lambda, or custom service
  }
}
```

This comprehensive API integration guide provides everything needed to properly integrate external services with SignSync while maintaining security, performance, and reliability standards.