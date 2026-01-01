import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/models/noise_event.dart';
import 'package:signsync/services/tts_service.dart';

/// Generates spoken alerts for object detection and sound events.
///
/// This service provides:
/// - Alert prioritization (safety-critical events first)
/// - De-duplication / caching (avoid repeating the same alert)
/// - Cooldown rate limiting
class AudioAlertService with ChangeNotifier {
  final TtsService _tts;
  final AppConfig _config;

  final Map<String, DateTime> _recentUtterances = <String, DateTime>{};
  DateTime? _lastSpokenAt;

  /// Creates an [AudioAlertService].
  AudioAlertService({
    required TtsService tts,
    required AppConfig config,
  })  : _tts = tts,
        _config = config {
    _config.addListener(_onConfigChanged);
    unawaited(_syncTtsSettings());
  }

  bool get isTtsEnabled => _config.ttsEnabled;

  Future<void> _onConfigChanged() async {
    await _syncTtsSettings();
  }

  Future<void> _syncTtsSettings() async {
    if (!_config.ttsEnabled) return;

    final language = _config.languageCode == 'en' ? 'en-US' : '${_config.languageCode}-US';
    await _tts.applySettings(
      language: language,
      volume: _config.ttsVolume,
      rate: _config.ttsRate,
      pitch: _config.ttsPitch,
    );
  }

  /// Creates and speaks a high-signal alert message from a detection frame.
  Future<void> handleDetectionFrame(
    DetectionFrame frame, {
    required Size frameSize,
  }) async {
    if (!_config.ttsEnabled || !_config.objectAudioAlertsEnabled) return;

    final now = DateTime.now();
    if (_lastSpokenAt != null && now.difference(_lastSpokenAt!) < _config.objectAudioAlertsCooldown) {
      return;
    }

    final candidates = frame.objects
        .where((o) => o.confidence >= _config.objectMinConfidence)
        .toList();

    if (candidates.isEmpty) return;

    candidates.sort((a, b) => _scoreObject(b).compareTo(_scoreObject(a)));
    final top = candidates.first;

    final message = describeObject(top, frameSize: frameSize);
    final key = _utteranceKeyForObject(top, frameSize: frameSize);

    final lastSpoken = _recentUtterances[key];
    if (lastSpoken != null && now.difference(lastSpoken) < const Duration(seconds: 10)) {
      return;
    }

    _recentUtterances[key] = now;
    _lastSpokenAt = now;

    LoggerService.debug('Speaking object alert: $message');
    await _tts.speak(message, interrupt: false);
  }

  /// Speaks a sound alert, applying cooldown and de-duplication.
  Future<void> handleSoundEvent(NoiseEvent event) async {
    if (!_config.ttsEnabled || !_config.soundVoiceAlertsEnabled) return;

    if (!event.shouldAlert) return;

    final now = DateTime.now();
    if (_lastSpokenAt != null && now.difference(_lastSpokenAt!) < const Duration(seconds: 2)) {
      return;
    }

    final key = 'sound:${event.type.name}:${event.severity.name}';
    final lastSpoken = _recentUtterances[key];
    if (lastSpoken != null && now.difference(lastSpoken) < const Duration(seconds: 8)) {
      return;
    }

    _recentUtterances[key] = now;
    _lastSpokenAt = now;

    await _tts.speak('${event.type.displayName} detected', interrupt: false);
  }

  /// Generates an English spoken description for a [DetectedObject].
  String describeObject(
    DetectedObject object, {
    required Size frameSize,
  }) {
    final direction = _directionForObject(object, frameSize: frameSize);
    final feet = object.distance != null ? (object.distance! * 3.28084) : null;

    final distanceText = feet != null
        ? '${feet.round()} feet'
        : 'nearby';

    if (!_config.ttsSpatialCues) {
      return '${object.displayName} $distanceText';
    }

    switch (direction) {
      case _SpatialDirection.left:
        return '${object.displayName} $distanceText to your left';
      case _SpatialDirection.right:
        return '${object.displayName} $distanceText to your right';
      case _SpatialDirection.center:
        return '${object.displayName} $distanceText ahead';
    }
  }

  int _scoreObject(DetectedObject object) {
    final label = object.label.toLowerCase();
    final base = switch (label) {
      'person' => 100,
      'car' || 'truck' || 'bus' || 'motorcycle' || 'bicycle' => 90,
      'traffic light' || 'stop sign' => 80,
      'chair' || 'bench' || 'couch' || 'bed' || 'toilet' => 70,
      'cell phone' || 'laptop' => 40,
      _ => 10,
    };

    final distanceBoost = object.distance == null
        ? 0
        : (math.max(0.0, 4.0 - object.distance!) * 10).round();

    return base + distanceBoost + (object.confidence * 10).round();
  }

  String _utteranceKeyForObject(
    DetectedObject object, {
    required Size frameSize,
  }) {
    final direction = _directionForObject(object, frameSize: frameSize).name;
    final feet = object.distance != null ? (object.distance! * 3.28084) : null;
    final roundedFeet = feet == null ? 'na' : (feet / 2).round() * 2;

    return 'obj:${object.label.toLowerCase()}:$direction:$roundedFeet';
  }

  _SpatialDirection _directionForObject(
    DetectedObject object, {
    required Size frameSize,
  }) {
    final x = object.center.dx;
    final third = frameSize.width / 3;

    if (x < third) return _SpatialDirection.left;
    if (x > third * 2) return _SpatialDirection.right;
    return _SpatialDirection.center;
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigChanged);
    super.dispose();
  }
}

enum _SpatialDirection { left, center, right }
