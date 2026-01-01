import 'package:flutter/foundation.dart';
import 'package:signsync/models/alert_item.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/services/alert_queue_service.dart';

enum SpatialDirection { left, ahead, right }

class ObjectAudioAlertService with ChangeNotifier {
  final AlertQueueService _alerts;

  bool _enabled = true;
  int _maxAlertsPerFrame = 1;
  double _maxDistanceMeters = 6.0;

  ObjectAudioAlertService({required AlertQueueService alerts}) : _alerts = alerts;

  bool get enabled => _enabled;

  void updateSettings({
    bool? enabled,
    int? maxAlertsPerFrame,
    double? maxDistanceMeters,
  }) {
    _enabled = enabled ?? _enabled;
    _maxAlertsPerFrame = maxAlertsPerFrame ?? _maxAlertsPerFrame;
    _maxDistanceMeters = maxDistanceMeters ?? _maxDistanceMeters;
    notifyListeners();
  }

  Future<void> handleDetectionFrame(DetectionFrame frame) async {
    if (!_enabled) return;

    final objects = frame.highConfidenceObjects(threshold: 0.6);
    if (objects.isEmpty) return;

    final prioritized = List<DetectedObject>.from(objects)
      ..removeWhere((o) => o.distance != null && o.distance! > _maxDistanceMeters)
      ..sort((a, b) => _priorityScore(b).compareTo(_priorityScore(a)));

    final toSpeak = prioritized.take(_maxAlertsPerFrame).toList();
    for (final obj in toSpeak) {
      final message = _formatObjectAlert(obj);
      if (message == null) continue;

      await _alerts.enqueue(
        AlertItem(
          id: 'obj_${obj.id}',
          text: message.text,
          priority: message.priority,
          cacheKey: message.cacheKey,
          dedupeWindow: message.dedupeWindow,
        ),
      );
    }
  }

  double _priorityScore(DetectedObject obj) {
    final base = _basePriority(obj.label);
    final distanceMeters = obj.distance ?? 10.0;
    final distanceFactor = (1.0 / (distanceMeters + 0.5)).clamp(0.0, 1.0);
    return base + (distanceFactor * 2.0) + obj.confidence;
  }

  double _basePriority(String label) {
    switch (label.toLowerCase()) {
      case 'person':
        return 5.0;
      case 'car':
      case 'bus':
      case 'truck':
      case 'motorcycle':
      case 'bicycle':
        return 4.0;
      case 'traffic light':
      case 'stop sign':
        return 3.5;
      case 'chair':
      case 'couch':
      case 'dining table':
      case 'bench':
        return 3.0;
      case 'dog':
        return 2.5;
      default:
        return 2.0;
    }
  }

  ({String text, AlertPriority priority, String cacheKey, Duration dedupeWindow})? _formatObjectAlert(
    DetectedObject obj,
  ) {
    final direction = _directionFromObject(obj);
    final distanceFeet = obj.distance != null ? (obj.distance! * 3.28084) : null;
    final roundedFeet = distanceFeet != null ? distanceFeet.round() : null;

    final label = obj.displayName;

    final directionText = switch (direction) {
      SpatialDirection.left => 'left',
      SpatialDirection.right => 'right',
      SpatialDirection.ahead => 'ahead',
    };

    final distanceText = roundedFeet != null ? '$roundedFeet feet' : 'nearby';

    final includeDirection = _alerts.spatialCuesEnabled;

    final text = includeDirection ? '$label $distanceText $directionText' : '$label $distanceText';
    final cacheKey = includeDirection
        ? '${obj.label.toLowerCase()}|$directionText|${roundedFeet ?? 'x'}'
        : '${obj.label.toLowerCase()}|${roundedFeet ?? 'x'}';

    final priority = _alertPriorityForObject(obj);

    return (
      text: text,
      priority: priority,
      cacheKey: cacheKey,
      dedupeWindow: const Duration(seconds: 3),
    );
  }

  AlertPriority _alertPriorityForObject(DetectedObject obj) {
    final label = obj.label.toLowerCase();
    if (label == 'person') return AlertPriority.high;
    if (label == 'car' || label == 'bus' || label == 'truck' || label == 'motorcycle') {
      return AlertPriority.high;
    }
    if ((obj.distance ?? 10.0) <= 2.0) return AlertPriority.high;
    return AlertPriority.normal;
  }

  SpatialDirection _directionFromObject(DetectedObject obj) {
    final w = (obj.metadata['imageWidth'] as num?)?.toDouble();
    if (w == null || w <= 0) {
      return SpatialDirection.ahead;
    }

    final x = obj.center.dx;
    if (x < w * 0.33) return SpatialDirection.left;
    if (x > w * 0.66) return SpatialDirection.right;
    return SpatialDirection.ahead;
  }
}
