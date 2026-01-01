import 'package:equatable/equatable.dart';

enum AlertPriority {
  low(0),
  normal(1),
  high(2),
  critical(3);

  final int weight;

  const AlertPriority(this.weight);
}

class AlertItem with EquatableMixin {
  final String id;
  final String text;
  final AlertPriority priority;
  final DateTime timestamp;

  /// Used to suppress duplicates (e.g. "person|left|5ft").
  final String cacheKey;

  /// Minimum amount of time before the same [cacheKey] can be spoken again.
  final Duration dedupeWindow;

  /// Optional volume override (0..1).
  final double? volume;

  const AlertItem({
    required this.id,
    required this.text,
    required this.priority,
    required this.cacheKey,
    required this.dedupeWindow,
    this.volume,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [id, text, priority, timestamp, cacheKey, dedupeWindow, volume];
}
