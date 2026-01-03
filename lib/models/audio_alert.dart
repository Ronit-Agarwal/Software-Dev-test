import 'package:freezed_annotation/freezed_annotation.dart';

/// Priority levels for audio alerts
enum AlertPriority {
  low,
  medium,
  high,
  critical,
}

/// Represents an audio alert for object detection
@freezed
class AudioAlert with _$AudioAlert {
  const factory AudioAlert({
    required String id,
    required String text,
    required AlertPriority priority,
    required bool spatialAudio,
    required DateTime timestamp,
    String? objectLabel,
    double? objectPosition,
  }) = _AudioAlert;

  /// Create an audio alert from JSON
  factory AudioAlert.fromJson(Map<String, dynamic> json) =>
      _$AudioAlertFromJson(json);
}