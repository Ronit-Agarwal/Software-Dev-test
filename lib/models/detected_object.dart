import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Represents a detected object in the camera feed.
///
/// This model contains information about objects detected by the
/// ML model including their label, confidence, and bounding box.
@immutable
class DetectedObject with EquatableMixin {
  final String id;
  final String label;
  final String displayName;
  final double confidence;
  final Rect boundingBox;
  final double? distance; // Estimated distance in meters
  final double? depth; // Relative depth score [0, 1]
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const DetectedObject({
    required this.id,
    required this.label,
    required this.displayName,
    required this.confidence,
    required this.boundingBox,
    this.distance,
    this.depth,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a detected object with basic information.
  factory DetectedObject.basic({
    required String label,
    required double confidence,
    required Rect boundingBox,
    double? distance,
    double? depth,
    Map<String, dynamic> metadata = const {},
  }) {
    return DetectedObject(
      id: '${label}_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      displayName: _formatDisplayName(label),
      confidence: confidence,
      boundingBox: boundingBox,
      distance: distance,
      depth: depth,
      metadata: metadata,
    );
  }

  /// Formats a raw label into a human-readable display name.
  static String _formatDisplayName(String label) {
    return label
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  List<Object?> get props => [
        id,
        label,
        displayName,
        confidence,
        boundingBox,
        distance,
        depth,
        timestamp,
        metadata,
      ];

  DetectedObject copyWith({
    String? id,
    String? label,
    String? displayName,
    double? confidence,
    Rect? boundingBox,
    double? distance,
    double? depth,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return DetectedObject(
      id: id ?? this.id,
      label: label ?? this.label,
      displayName: displayName ?? this.displayName,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      distance: distance ?? this.distance,
      depth: depth ?? this.depth,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Returns the center point of the bounding box.
  Offset get center => Offset(
        boundingBox.left + boundingBox.width / 2,
        boundingBox.top + boundingBox.height / 2,
      );

  /// Returns true if the confidence is above the threshold (>= 0.7).
  bool get isHighConfidence => confidence >= 0.7;

  @override
  String toString() {
    return 'DetectedObject(label: $displayName, confidence: ${confidence.toStringAsFixed(2)}, box: $boundingBox)';
  }
}

/// Represents a frame from the camera with detected objects.
@immutable
class DetectionFrame with EquatableMixin {
  final String id;
  final List<DetectedObject> objects;
  final DateTime timestamp;
  final int frameIndex;
  final double inferenceTime;

  const DetectionFrame({
    required this.id,
    required this.objects,
    required this.timestamp,
    required this.frameIndex,
    this.inferenceTime = 0.0,
  });

  /// Returns the most confident object in the frame.
  DetectedObject? get mostConfident {
    if (objects.isEmpty) return null;
    return objects.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }

  /// Returns objects above a confidence threshold.
  List<DetectedObject> highConfidenceObjects({double threshold = 0.7}) {
    return objects.where((obj) => obj.confidence >= threshold).toList();
  }

  @override
  List<Object?> get props => [id, objects, timestamp, frameIndex, inferenceTime];

  @override
  String toString() {
    return 'DetectionFrame(frame: $frameIndex, objects: ${objects.length}, inferenceTime: ${inferenceTime.toStringAsFixed(1)}ms)';
  }
}

/// Represents the result of object detection inference.
class DetectionResult with EquatableMixin {
  final DetectionFrame? frame;
  final String? error;
  final bool isProcessing;

  const DetectionResult({
    this.frame,
    this.error,
    this.isProcessing = false,
  });

  /// Creates a result for ongoing processing.
  factory DetectionResult.processing() {
    return DetectionResult(isProcessing: true);
  }

  /// Creates a result for an error.
  factory DetectionResult.error(String error) {
    return DetectionResult(error: error);
  }

  /// Creates a successful detection result.
  factory DetectionResult.success(DetectionFrame frame) {
    return DetectionResult(frame: frame);
  }

  @override
  List<Object?> get props => [frame, error, isProcessing];
}

/// Categories of objects that can be detected.
///
/// These categories help organize detected objects and can be used
/// for filtering or customization.
enum ObjectCategory {
  person('Person', Icons.person),
  animal('Animal', Icons.pets),
  vehicle('Vehicle', Icons.directions_car),
  food('Food', Icons.restaurant),
  object('Object', Icons.category),
  scene('Scene', Icons.landscape),
  unknown('Unknown', Icons.help);

  final String displayName;
  final IconData icon;

  const ObjectCategory(this.displayName, this.icon);

  /// Determines the category from a label.
  static ObjectCategory fromLabel(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('person') || lowerLabel.contains('human')) {
      return ObjectCategory.person;
    }
    if (lowerLabel.contains('dog') ||
        lowerLabel.contains('cat') ||
        lowerLabel.contains('bird') ||
        lowerLabel.contains('animal')) {
      return ObjectCategory.animal;
    }
    if (lowerLabel.contains('car') ||
        lowerLabel.contains('bus') ||
        lowerLabel.contains('truck') ||
        lowerLabel.contains('vehicle')) {
      return ObjectCategory.vehicle;
    }
    if (lowerLabel.contains('food') ||
        lowerLabel.contains('fruit') ||
        lowerLabel.contains('vegetable')) {
      return ObjectCategory.food;
    }
    if (lowerLabel.contains('scene') || lowerLabel.contains('background')) {
      return ObjectCategory.scene;
    }
    return ObjectCategory.object;
  }
}
