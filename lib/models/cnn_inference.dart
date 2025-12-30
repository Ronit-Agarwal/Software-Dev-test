import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:signsync/models/asl_sign.dart';

@immutable
class CnnPrediction with EquatableMixin {
  final int index;
  final String label;
  final double confidence;

  const CnnPrediction({
    required this.index,
    required this.label,
    required this.confidence,
  });

  @override
  List<Object?> get props => [index, label, confidence];
}

@immutable
class CnnLatencyMetrics with EquatableMixin {
  final int preprocessMs;
  final int inferenceMs;
  final int totalMs;

  const CnnLatencyMetrics({
    required this.preprocessMs,
    required this.inferenceMs,
    required this.totalMs,
  });

  @override
  List<Object?> get props => [preprocessMs, inferenceMs, totalMs];
}

@immutable
class AslCnnResult with EquatableMixin {
  final AslSign sign;
  final List<CnnPrediction> topK;
  final CnnLatencyMetrics latency;
  final String? phoneticHint;

  const AslCnnResult({
    required this.sign,
    required this.topK,
    required this.latency,
    this.phoneticHint,
  });

  @override
  List<Object?> get props => [sign, topK, latency, phoneticHint];
}
