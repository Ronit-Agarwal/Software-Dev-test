import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Represents a sound event detected by the audio service.
///
/// This model contains information about sounds that are detected
/// by the app, including their type, intensity, and timestamp.
@immutable
class NoiseEvent with EquatableMixin {
  final String id;
  final NoiseType type;
  final String displayName;
  final double intensity;
  final DateTime timestamp;
  final Duration duration;
  final bool isAlertEnabled;
  final Map<String, dynamic> metadata;

  const NoiseEvent({
    required this.id,
    required this.type,
    required this.displayName,
    required this.intensity,
    required this.timestamp,
    this.duration = Duration.zero,
    this.isAlertEnabled = true,
    this.metadata = const {},
  });

  /// Creates a noise event from audio input.
  factory NoiseEvent.fromAudio({
    required NoiseType type,
    required double intensity,
    Duration duration = Duration.zero,
  }) {
    return NoiseEvent(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      displayName: type.displayName,
      intensity: intensity,
      timestamp: DateTime.now(),
      duration: duration,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        displayName,
        intensity,
        timestamp,
        duration,
        isAlertEnabled,
        metadata,
      ];

  NoiseEvent copyWith({
    String? id,
    NoiseType? type,
    String? displayName,
    double? intensity,
    DateTime? timestamp,
    Duration? duration,
    bool? isAlertEnabled,
    Map<String, dynamic>? metadata,
  }) {
    return NoiseEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      intensity: intensity ?? this.intensity,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      isAlertEnabled: isAlertEnabled ?? this.isAlertEnabled,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Returns the severity level based on intensity.
  AlertSeverity get severity {
    if (intensity >= 0.9) return AlertSeverity.critical;
    if (intensity >= 0.7) return AlertSeverity.high;
    if (intensity >= 0.5) return AlertSeverity.medium;
    return AlertSeverity.low;
  }

  /// Returns true if the intensity is above the alert threshold.
  bool get shouldAlert => intensity >= 0.6 && isAlertEnabled;

  @override
  String toString() {
    return 'NoiseEvent(type: $displayName, intensity: ${intensity.toStringAsFixed(2)}, severity: $severity)';
  }
}

/// Types of sounds that can be detected and alerted.
enum NoiseType {
  doorbell('Doorbell', Icons.notifications),
  knock('Knocking', Icons.doorbell),
  alarm('Alarm', Icons.alarm),
  siren('Siren', Icons.speaker),
  phoneRing('Phone Ring', Icons.phone),
  babyCrying('Baby Crying', Icons.child_care),
  glassBreak('Glass Break', Icons.window),
  smokeDetector('Smoke Detector', Icons.warning),
  dogBark('Dog Barking', Icons.pets),
  custom('Custom', Icons.music_note);

  final String displayName;
  final IconData icon;

  const NoiseType(this.displayName, this.icon);
}

/// Severity levels for alerts.
enum AlertSeverity {
  low('Low', Colors.blue),
  medium('Medium', Colors.orange),
  high('High', Colors.redAccent),
  critical('Critical', Colors.red);

  final String displayName;
  final Color color;

  const AlertSeverity(this.displayName, this.color);
}

/// Represents a log of noise events for a session.
@immutable
class NoiseSession with EquatableMixin {
  final String id;
  final List<NoiseEvent> events;
  final DateTime startTime;
  final DateTime? endTime;
  final int alertCount;

  const NoiseSession({
    required this.id,
    required this.events,
    required this.startTime,
    this.endTime,
  }) : alertCount = events.where((e) => e.shouldAlert).length;

  /// Returns the duration of this session.
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Returns true if this session has any alerts.
  bool get hasAlerts => alertCount > 0;

  /// Returns the most frequent noise type in this session.
  NoiseType? get mostFrequentType {
    if (events.isEmpty) return null;
    final typeCount = <NoiseType, int>{};
    for (final event in events) {
      typeCount[event.type] = (typeCount[event.type] ?? 0) + 1;
    }
    return typeCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  @override
  List<Object?> get props => [id, events, startTime, endTime, alertCount];
}

/// Represents the result of sound analysis.
class SoundAnalysisResult with EquatableMixin {
  final List<NoiseEvent> detectedEvents;
  final String? error;
  final bool isProcessing;
  final DateTime timestamp;

  const SoundAnalysisResult({
    this.detectedEvents = const [],
    this.error,
    this.isProcessing = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a result for ongoing processing.
  factory SoundAnalysisResult.processing() {
    return SoundAnalysisResult(isProcessing: true);
  }

  /// Creates a result for an error.
  factory SoundAnalysisResult.error(String error) {
    return SoundAnalysisResult(error: error);
  }

  /// Creates a successful analysis result.
  factory SoundAnalysisResult.success(List<NoiseEvent> events) {
    return SoundAnalysisResult(detectedEvents: events);
  }

  @override
  List<Object?> get props => [detectedEvents, error, isProcessing, timestamp];

  SoundAnalysisResult copyWith({
    List<NoiseEvent>? detectedEvents,
    String? error,
    bool? isProcessing,
    DateTime? timestamp,
  }) {
    return SoundAnalysisResult(
      detectedEvents: detectedEvents ?? this.detectedEvents,
      error: error ?? this.error,
      isProcessing: isProcessing ?? this.isProcessing,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
