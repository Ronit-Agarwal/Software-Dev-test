import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/detected_object.dart';

/// Service for text-to-speech audio alerts for object detection.
///
/// Integrates with native platform TTS (iOS Speech, Android TextToSpeech)
/// to provide real-time spatial audio feedback for detected objects.
class TtsService with ChangeNotifier {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _error;
  String? _currentLanguage;

  // Queue management for alerts
  final Queue<AudioAlert> _alertQueue = Queue<AudioAlert>();
  Timer? _queueProcessingTimer;

  // Alert caching to prevent duplicates
  final Map<String, DateTime> _lastSpokenCache = {};
  static const Duration _duplicateCooldown = Duration(seconds: 5);

  // Audio configuration
  double _volume = 0.8;
  double _speechRate = 0.9;
  double _pitch = 1.0;
  bool _spatialAudioEnabled = true;

  // Alert priority system
  final Map<String, AlertPriority> _objectPriorities = {
    // High priority - important for accessibility
    'person': AlertPriority.critical,
    'car': AlertPriority.high,
    'truck': AlertPriority.high,
    'bus': AlertPriority.high,
    'motorcycle': AlertPriority.high,
    'bicycle': AlertPriority.high,
    'traffic light': AlertPriority.high,
    'stop sign': AlertPriority.high,

    // Medium priority - obstacles and navigation
    'chair': AlertPriority.medium,
    'couch': AlertPriority.medium,
    'table': AlertPriority.medium,
    'bench': AlertPriority.medium,
    'door': AlertPriority.medium,
    'stair': AlertPriority.medium,

    // Low priority - general objects
    'bottle': AlertPriority.low,
    'cup': AlertPriority.low,
    'book': AlertPriority.low,
    'laptop': AlertPriority.low,
    'cell phone': AlertPriority.low,
    'clock': AlertPriority.low,
    'tv': AlertPriority.low,
  };

  // Spatial audio zones
  static const double _leftZoneThreshold = 0.35;
  static const double _rightZoneThreshold = 0.65;

  // Performance monitoring
  final List<double> _speechDurations = [];
  int _totalAlertsPlayed = 0;
  int _duplicateAlertsFiltered = 0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String? get error => _error;
  double get volume => _volume;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  bool get spatialAudioEnabled => _spatialAudioEnabled;
  int get queuedAlerts => _alertQueue.length;
  int get totalAlertsPlayed => _totalAlertsPlayed;
  int get duplicateAlertsFiltered => _duplicateAlertsFiltered;
  double get averageSpeechDuration => _speechDurations.isNotEmpty
      ? _speechDurations.reduce((a, b) => a + b) / _speechDurations.length
      : 0.0;

  /// Enhanced TTS initialization with comprehensive platform detection and fallbacks.
  Future<void> initialize() async {
    if (_isInitialized) {
      LoggerService.warn('TTS service already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing TTS service');
      _error = null;

      _flutterTts = FlutterTts();

      // Set up TTS event handlers
      _setupTtsEventHandlers();

      // Wait for TTS engine initialization
      await Future.delayed(const Duration(milliseconds: 500));

      // Check TTS availability
      final isAvailable = await _flutterTts!.isLanguageAvailable('en-US');
      if (!isAvailable) {
        // Try alternative language
        final isAlternativeAvailable = await _flutterTts!.isLanguageAvailable('en-GB');
        if (!isAlternativeAvailable) {
          throw TtsException('tts_unavailable', 'Text-to-speech engine not available on this device');
        }
        _currentLanguage = 'en-GB';
      } else {
        _currentLanguage = 'en-US';
      }

      // Set language
      await _flutterTts!.setLanguage(_currentLanguage!);

      // Configure audio settings
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);

      // Start queue processing
      _startQueueProcessing();

      _isInitialized = true;
      notifyListeners();

      LoggerService.info('TTS service initialized successfully');
    } catch (e, stack) {
      _error = 'TTS initialization failed: $e';
      LoggerService.error('TTS service initialization failed', error: e, stack: stack);
      _isInitialized = false;
      notifyListeners();
      
      // Don't throw - allow app to function without TTS
      LoggerService.warn('Continuing without TTS support');
    }
  }

  /// Enhanced speak method with comprehensive error handling and fallbacks.
  Future<void> speak(
    String text, {
    AlertPriority priority = AlertPriority.low,
    bool spatialAudio = true,
    String? objectLabel,
    double? objectPosition,
  }) async {
    if (!_isInitialized || _flutterTts == null) {
      LoggerService.warn('TTS not initialized, cannot speak: $text');
      return;
    }

    if (text.trim().isEmpty) {
      LoggerService.warn('Empty text provided to TTS');
      return;
    }

    // Check for duplicate alerts
    final alertKey = '${objectLabel ?? 'text'}_${text.hashCode}';
    final now = DateTime.now();
    final lastSpoken = _lastSpokenCache[alertKey];
    
    if (lastSpoken != null && 
        now.difference(lastSpoken) < _duplicateCooldown) {
      _duplicateAlertsFiltered++;
      LoggerService.debug('Duplicate alert filtered: $text');
      return;
    }

    // Add to queue for processing
    final alert = AudioAlert(
      id: 'alert_${now.millisecondsSinceEpoch}',
      text: text.trim(),
      priority: priority,
      spatialAudio: spatialAudio,
      objectLabel: objectLabel,
      objectPosition: objectPosition,
      timestamp: now,
    );

    _alertQueue.add(alert);
    _lastSpokenCache[alertKey] = now;

    // Clean up old cache entries
    _cleanupCache();

    // Process queue if not already processing
    if (!_isSpeaking) {
      _processQueue();
    }

    notifyListeners();
  }

  /// Enhanced queue processing with priority handling.
  Future<void> _processQueue() async {
    if (_isSpeaking || _alertQueue.isEmpty) {
      return;
    }

    _isSpeaking = true;
    notifyListeners();

    try {
      while (_alertQueue.isNotEmpty) {
        // Get highest priority alert
        final alert = _alertQueue.removeFirst();
        
        // Apply spatial audio if enabled
        final processedText = _spatialAudioEnabled && alert.spatialAudio
            ? _applySpatialAudio(alert.text, alert.objectPosition)
            : alert.text;

        LoggerService.debug('Speaking alert: ${alert.text}');

        // Speak the alert
        final stopwatch = Stopwatch()..start();
        await _flutterTts!.speak(processedText);
        
        // Wait for speech to complete or timeout
        final maxDuration = Duration(milliseconds: (alert.text.length * 50).clamp(1000, 5000));
        await Future.delayed(maxDuration);
        
        stopwatch.stop();
        _speechDurations.add(stopwatch.elapsedMilliseconds.toDouble());
        
        // Keep only last 50 measurements
        if (_speechDurations.length > 50) {
          _speechDurations.removeAt(0);
        }

        _totalAlertsPlayed++;

        // Small delay between alerts to prevent overlapping
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e, stack) {
      LoggerService.error('TTS queue processing failed', error: e, stack: stack);
      _error = 'TTS playback failed: $e';
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Enhanced spatial audio application with better positioning.
  String _applySpatialAudio(String text, double? position) {
    if (!_spatialAudioEnabled || position == null) {
      return text;
    }

    // Determine position
    String positionText;
    if (position < _leftZoneThreshold) {
      positionText = 'on your left';
    } else if (position > _rightZoneThreshold) {
      positionText = 'on your right';
    } else {
      positionText = 'ahead';
    }

    return '$positionText, $text';
  }

  /// Set up TTS event handlers with error recovery.
  void _setupTtsEventHandlers() {
    _flutterTts!.setStartHandler(() {
      LoggerService.debug('TTS speech started');
      _isSpeaking = true;
      notifyListeners();
    });

    _flutterTts!.setCompletionHandler(() {
      LoggerService.debug('TTS speech completed');
      _isSpeaking = false;
      notifyListeners();
      
      // Continue processing queue
      _processQueue();
    });

    _flutterTts!.setErrorHandler((message) {
      LoggerService.error('TTS error: $message');
      _isSpeaking = false;
      _error = 'TTS error: $message';
      notifyListeners();
    });

    _flutterTts!.setCancelHandler(() {
      LoggerService.debug('TTS speech cancelled');
      _isSpeaking = false;
      notifyListeners();
    });
  }

  /// Enhanced stop method with immediate queue clearing.
  Future<void> stop() async {
    try {
      LoggerService.info('Stopping TTS service');
      
      // Stop current speech
      await _flutterTts?.stop();
      
      // Clear queue
      _alertQueue.clear();
      
      _isSpeaking = false;
      notifyListeners();
      
      LoggerService.info('TTS service stopped');
    } catch (e, stack) {
      LoggerService.error('Failed to stop TTS service', error: e, stack: stack);
      _error = 'Failed to stop TTS: $e';
      notifyListeners();
    }
  }

  /// Enhanced volume control with validation.
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    
    try {
      _volume = clampedVolume;
      if (_flutterTts != null && _isInitialized) {
        await _flutterTts!.setVolume(_volume);
      }
      LoggerService.debug('TTS volume set to: $_volume');
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error('Failed to set TTS volume', error: e, stack: stack);
    }
  }

  /// Enhanced speech rate control with validation.
  Future<void> setSpeechRate(double rate) async {
    final clampedRate = rate.clamp(0.1, 2.0);
    
    try {
      _speechRate = clampedRate;
      if (_flutterTts != null && _isInitialized) {
        await _flutterTts!.setSpeechRate(_speechRate);
      }
      LoggerService.debug('TTS speech rate set to: $_speechRate');
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error('Failed to set TTS speech rate', error: e, stack: stack);
    }
  }

  /// Enhanced pitch control with validation.
  Future<void> setPitch(double pitch) async {
    final clampedPitch = pitch.clamp(0.5, 2.0);
    
    try {
      _pitch = clampedPitch;
      if (_flutterTts != null && _isInitialized) {
        await _flutterTts!.setPitch(_pitch);
      }
      LoggerService.debug('TTS pitch set to: $_pitch');
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error('Failed to set TTS pitch', error: e, stack: stack);
    }
  }

  /// Clean up old cache entries to prevent memory leaks.
  void _cleanupCache() {
    final now = DateTime.now();
    _lastSpokenCache.removeWhere((key, timestamp) => 
        now.difference(timestamp) > const Duration(minutes: 10));
  }

  /// Start queue processing timer.
  void _startQueueProcessing() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!_isSpeaking && _alertQueue.isNotEmpty) {
          _processQueue();
        }
      },
    );
  }

  /// Get performance statistics for monitoring.
  Map<String, dynamic> getPerformanceStats() {
    return {
      'isInitialized': _isInitialized,
      'isSpeaking': _isSpeaking,
      'queuedAlerts': _alertQueue.length,
      'totalAlertsPlayed': _totalAlertsPlayed,
      'duplicateAlertsFiltered': _duplicateAlertsFiltered,
      'averageSpeechDuration': averageSpeechDuration,
      'volume': _volume,
      'speechRate': _speechRate,
      'pitch': _pitch,
      'spatialAudioEnabled': _spatialAudioEnabled,
      'currentLanguage': _currentLanguage,
    };
  }

  /// Health check for TTS service.
  Future<bool> performHealthCheck() async {
    try {
      if (!_isInitialized || _flutterTts == null) {
        return false;
      }

      // Test basic functionality
      await _flutterTts!.isLanguageAvailable('en-US');
      return true;
    } catch (e) {
      LoggerService.error('TTS health check failed', error: e);
      return false;
    }
  }

  /// Cleanup resources.
  Future<void> dispose() async {
    LoggerService.info('Disposing TTS service');
    
    _queueProcessingTimer?.cancel();
    await stop();
    _flutterTts = null;
    _isInitialized = false;
    _alertQueue.clear();
    _lastSpokenCache.clear();
    
    notifyListeners();
  }
}

      // Set default language
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSharedInstance(true);

      // Configure audio session
      await _flutterTts!.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );

      // Apply current settings
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);

      // Set completion handler
      await _flutterTts!.setCompletionHandler(() {
        _onSpeechComplete();
      });

      await _flutterTts!.setErrorHandler((message) {
        _error = 'TTS error: $message';
        LoggerService.error('TTS error: $message');
        _onSpeechComplete();
      });

      // Start queue processing
      _startQueueProcessing();

      _isInitialized = true;
      _currentLanguage = 'en-US';
      notifyListeners();
      LoggerService.info('TTS service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize TTS: $e';
      LoggerService.error('TTS initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Speaks the given text.
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      throw TtsException('TTS service not initialized');
    }

    if (text.isEmpty) {
      LoggerService.warn('Empty text provided to speak');
      return;
    }

    try {
      LoggerService.debug('Speaking: $text');
      _isSpeaking = true;
      notifyListeners();

      final stopwatch = Stopwatch()..start();
      await _flutterTts!.speak(text);
      stopwatch.stop();

      _speechDurations.add(stopwatch.elapsedMilliseconds.toDouble());
      if (_speechDurations.length > 20) {
        _speechDurations.removeAt(0);
      }

      _totalAlertsPlayed++;
    } catch (e, stack) {
      _error = 'Failed to speak: $e';
      LoggerService.error('Failed to speak', error: e, stack: stack);
      _isSpeaking = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Stops current speech and clears the queue.
  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
      _alertQueue.clear();
      _isSpeaking = false;
      notifyListeners();
      LoggerService.info('TTS stopped');
    } catch (e, stack) {
      LoggerService.error('Failed to stop TTS', error: e, stack: stack);
    }
  }

  /// Pauses current speech.
  Future<void> pause() async {
    try {
      await _flutterTts?.pause();
      _isSpeaking = false;
      notifyListeners();
      LoggerService.info('TTS paused');
    } catch (e, stack) {
      LoggerService.error('Failed to pause TTS', error: e, stack: stack);
    }
  }

  /// Resumes paused speech.
  Future<void> resume() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts?.setSharedInstance(true);
      _isSpeaking = true;
      notifyListeners();
      LoggerService.info('TTS resumed');
    } catch (e, stack) {
      LoggerService.error('Failed to resume TTS', error: e, stack: stack);
    }
  }

  /// Sets the speech volume [0.0, 1.0].
  Future<void> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError('Volume must be between 0.0 and 1.0');
    }

    try {
      _volume = volume.clamp(0.0, 1.0);
      await _flutterTts?.setVolume(_volume);
      notifyListeners();
      LoggerService.debug('TTS volume set to $_volume');
    } catch (e, stack) {
      LoggerService.error('Failed to set volume', error: e, stack: stack);
    }
  }

  /// Sets the speech rate [0.0, 1.0] where 1.0 is normal.
  Future<void> setSpeechRate(double rate) async {
    if (rate < 0.0 || rate > 1.0) {
      throw ArgumentError('Speech rate must be between 0.0 and 1.0');
    }

    try {
      _speechRate = rate.clamp(0.0, 1.0);
      await _flutterTts?.setSpeechRate(_speechRate);
      notifyListeners();
      LoggerService.debug('TTS speech rate set to $_speechRate');
    } catch (e, stack) {
      LoggerService.error('Failed to set speech rate', error: e, stack: stack);
    }
  }

  /// Sets the speech pitch [0.5, 2.0].
  Future<void> setPitch(double pitch) async {
    if (pitch < 0.5 || pitch > 2.0) {
      throw ArgumentError('Pitch must be between 0.5 and 2.0');
    }

    try {
      _pitch = pitch.clamp(0.5, 2.0);
      await _flutterTts?.setPitch(_pitch);
      notifyListeners();
      LoggerService.debug('TTS pitch set to $_pitch');
    } catch (e, stack) {
      LoggerService.error('Failed to set pitch', error: e, stack: stack);
    }
  }

  /// Sets the TTS language based on Locale.
  Future<void> setLocale(Locale locale) async {
    final languageCode = '${locale.languageCode}-${locale.countryCode ?? locale.languageCode.toUpperCase()}';
    try {
      await setLanguage(languageCode);
    } catch (e) {
      // Fallback to language code only
      await setLanguage(locale.languageCode);
    }
  }

  /// Sets the TTS language.
  Future<void> setLanguage(String languageCode) async {
    try {
      final languages = await getLanguages();
      if (!languages.contains(languageCode)) {
        throw TtsException('Language $languageCode not available');
      }

      await _flutterTts?.setLanguage(languageCode);
      _currentLanguage = languageCode;
      notifyListeners();
      LoggerService.info('TTS language set to $languageCode');
    } catch (e, stack) {
      _error = 'Failed to set language: $e';
      LoggerService.error('Failed to set language', error: e, stack: stack);
      rethrow;
    }
  }

  /// Gets available languages.
  Future<List<String>> getLanguages() async {
    if (!_isInitialized) return [];

    try {
      final languages = await _flutterTts!.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e, stack) {
      LoggerService.error('Failed to get languages', error: e, stack: stack);
      return [];
    }
  }

  /// Toggles spatial audio support.
  void setSpatialAudioEnabled(bool enabled) {
    _spatialAudioEnabled = enabled;
    notifyListeners();
    LoggerService.info('Spatial audio ${enabled ? "enabled" : "disabled"}');
  }

  /// Generates an audio alert for detected objects.
  ///
  /// Automatically filters duplicates, applies priority,
  /// and adds spatial audio information if enabled.
  Future<void> generateAlert(DetectedObject object) async {
    if (!_isInitialized) {
      LoggerService.warn('TTS not initialized, skipping alert');
      return;
    }

    // Check for duplicate alerts
    if (_isDuplicate(object)) {
      _duplicateAlertsFiltered++;
      LoggerService.debug('Duplicate alert filtered: ${object.label}');
      return;
    }

    // Generate spatial direction
    final direction = _spatialAudioEnabled
        ? _calculateSpatialDirection(object)
        : SpatialDirection.center;

    // Generate alert message
    final message = _generateAlertMessage(object, direction);

    // Create alert with priority
    final priority = _getPriority(object.label);
    final alert = AudioAlert(
      object: object,
      message: message,
      priority: priority,
      direction: direction,
      timestamp: DateTime.now(),
    );

    // Add to queue (will be processed in priority order)
    _addToQueue(alert);

    // Cache this object
    _cacheObject(object);
  }

  /// Generates alerts for multiple detected objects.
  ///
  /// Sorts by priority and generates spatial-aware alerts.
  Future<void> generateAlerts(List<DetectedObject> objects) async {
    if (objects.isEmpty) return;

    // Sort objects by priority and confidence
    final sortedObjects = objects
        .where((obj) => obj.confidence >= 0.70) // Only high confidence
        .toList()
      ..sort((a, b) {
        final priorityA = _getPriority(a.label);
        final priorityB = _getPriority(b.label);
        if (priorityA != priorityB) {
          return priorityB.index.compareTo(priorityA.index);
        }
        return b.confidence.compareTo(a.confidence);
      });

    // Generate alerts for top priority objects (max 3 per frame)
    for (final object in sortedObjects.take(3)) {
      await generateAlert(object);
    }
  }

  /// Calculates spatial direction based on object position in frame.
  SpatialDirection _calculateSpatialDirection(DetectedObject object) {
    final centerX = object.boundingBox.left + object.boundingBox.width / 2;
    final relativeX = centerX / 640.0; // Assuming 640 width

    if (relativeX < _leftZoneThreshold) {
      return SpatialDirection.left;
    } else if (relativeX > _rightZoneThreshold) {
      return SpatialDirection.right;
    } else {
      return SpatialDirection.center;
    }
  }

  /// Generates the alert message for an object.
  String _generateAlertMessage(DetectedObject object, SpatialDirection direction) {
    final distanceText = _formatDistance(object.distance);
    final directionText = direction != SpatialDirection.center
        ? ' ${direction.displayName}'
        : '';

    return '${object.displayName}$directionText, $distanceText';
  }

  /// Formats distance for speech.
  String _formatDistance(double? distance) {
    if (distance == null) return 'ahead';

    final feet = (distance * 3.28084).round(); // Convert meters to feet

    if (feet < 1) {
      return 'very close';
    } else if (feet < 3) {
      return 'a few feet ahead';
    } else if (feet < 10) {
      return '$feet feet ahead';
    } else {
      return 'about ${feet ~/ 10}0 feet ahead';
    }
  }

  /// Gets the alert priority for an object label.
  AlertPriority _getPriority(String label) {
    return _objectPriorities[label.toLowerCase()] ?? AlertPriority.low;
  }

  /// Checks if this object was recently announced.
  bool _isDuplicate(DetectedObject object) {
    final cacheKey = _generateCacheKey(object);
    final lastSpoken = _lastSpokenCache[cacheKey];

    if (lastSpoken == null) return false;

    final timeSinceLastSpoken = DateTime.now().difference(lastSpoken);
    return timeSinceLastSpoken < _duplicateCooldown;
  }

  /// Generates a cache key for an object.
  String _generateCacheKey(DetectedObject object) {
    return '${object.label}_${object.distance?.toStringAsFixed(1) ?? "unknown"}';
  }

  /// Caches an object as spoken.
  void _cacheObject(DetectedObject object) {
    final cacheKey = _generateCacheKey(object);
    _lastSpokenCache[cacheKey] = DateTime.now();

    // Clean old cache entries
    _cleanOldCacheEntries();
  }

  /// Removes old cache entries to prevent memory bloat.
  void _cleanOldCacheEntries() {
    final now = DateTime.now();
    _lastSpokenCache.removeWhere((key, value) {
      return now.difference(value) > _duplicateCooldown * 2;
    });
  }

  /// Adds an alert to the queue in priority order.
  void _addToQueue(AudioAlert alert) {
    // Insert in priority order
    final list = _alertQueue.toList();
    list.add(alert);
    list.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    _alertQueue.clear();
    _alertQueue.addAll(list);

    notifyListeners();
    LoggerService.debug('Alert added to queue: ${alert.message} (priority: ${alert.priority})');
  }

  /// Starts the queue processing timer.
  void _startQueueProcessing() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _processQueue();
    });
  }

  /// Processes the alert queue.
  Future<void> _processQueue() async {
    if (_alertQueue.isEmpty || _isSpeaking) {
      return;
    }

    final alert = _alertQueue.removeFirst();
    notifyListeners();

    try {
      await speak(alert.message);
    } catch (e) {
      LoggerService.error('Failed to process alert', error: e);
    }
  }

  /// Called when speech completes.
  void _onSpeechComplete() {
    _isSpeaking = false;
    notifyListeners();
    LoggerService.debug('Speech completed');

    // Process next alert after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      _processQueue();
    });
  }

  /// Clears the alert cache.
  void clearCache() {
    _lastSpokenCache.clear();
    LoggerService.info('TTS alert cache cleared');
  }

  /// Gets statistics about TTS usage.
  Map<String, dynamic> get statistics => {
        'totalAlerts': _totalAlertsPlayed,
        'duplicatesFiltered': _duplicateAlertsFiltered,
        'averageSpeechDuration': averageSpeechDuration,
        'queuedAlerts': queuedAlerts,
        'isSpeaking': isSpeaking,
        'volume': _volume,
        'speechRate': _speechRate,
        'spatialAudioEnabled': _spatialAudioEnabled,
        'language': _currentLanguage,
      };

  /// Cleans up resources.
  @override
  Future<void> dispose() async {
    LoggerService.info('Disposing TTS service');

    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = null;

    await stop();
    await _flutterTts?.stop();
    await _flutterTts?.setSharedInstance(false);

    _alertQueue.clear();
    _lastSpokenCache.clear();
    _speechDurations.clear();
    _isInitialized = false;

    super.dispose();
  }
}

/// Represents an audio alert for a detected object.
class AudioAlert {
  final DetectedObject object;
  final String message;
  final AlertPriority priority;
  final SpatialDirection direction;
  final DateTime timestamp;

  const AudioAlert({
    required this.object,
    required this.message,
    required this.priority,
    required this.direction,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AudioAlert(message: $message, priority: $priority, direction: $direction)';
  }
}

/// Priority levels for audio alerts.
enum AlertPriority {
  critical, // Immediate danger or high importance
  high,     // Important but not critical
  medium,   // Moderate importance
  low,      // Low priority
}

/// Spatial direction for audio alerts.
enum SpatialDirection {
  left('to your left'),
  center('ahead'),
  right('to your right');

  final String displayName;

  const SpatialDirection(this.displayName);
}

/// Exception for TTS-related errors.
class TtsException implements Exception {
  final String message;

  const TtsException(this.message);

  @override
  String toString() => 'TtsException: $message';
}
