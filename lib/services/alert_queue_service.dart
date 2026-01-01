import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/alert_item.dart';
import 'package:signsync/services/tts_service.dart';

class AlertQueueService with ChangeNotifier {
  final TtsService _tts;

  bool _enabled = true;
  bool _spatialCuesEnabled = true;

  final List<AlertItem> _queue = [];
  final Map<String, DateTime> _recentlySpoken = {};

  Duration _maxDedupeRetention = const Duration(minutes: 2);

  AlertQueueService({required TtsService tts}) : _tts = tts;

  bool get enabled => _enabled;
  bool get spatialCuesEnabled => _spatialCuesEnabled;
  int get queued => _queue.length;

  void updateSettings({
    bool? enabled,
    bool? spatialCuesEnabled,
    Duration? maxDedupeRetention,
  }) {
    _enabled = enabled ?? _enabled;
    _spatialCuesEnabled = spatialCuesEnabled ?? _spatialCuesEnabled;
    _maxDedupeRetention = maxDedupeRetention ?? _maxDedupeRetention;
    notifyListeners();
  }

  Future<void> enqueue(AlertItem item) async {
    if (!_enabled) return;

    _cleanupDedupeCache();

    final lastSpoken = _recentlySpoken[item.cacheKey];
    if (lastSpoken != null && DateTime.now().difference(lastSpoken) < item.dedupeWindow) {
      return;
    }

    _queue.add(item);
    _queue.sort((a, b) {
      final p = b.priority.weight.compareTo(a.priority.weight);
      if (p != 0) return p;
      return a.timestamp.compareTo(b.timestamp);
    });

    notifyListeners();
    await _drain();
  }

  Future<void> _drain() async {
    if (!_enabled) return;
    if (_tts.isSpeaking) return;

    while (_queue.isNotEmpty && _enabled) {
      if (_tts.isSpeaking) break;

      final next = _queue.removeAt(0);
      notifyListeners();

      final lastSpoken = _recentlySpoken[next.cacheKey];
      if (lastSpoken != null && DateTime.now().difference(lastSpoken) < next.dedupeWindow) {
        continue;
      }

      _recentlySpoken[next.cacheKey] = DateTime.now();
      LoggerService.debug('Speaking alert: ${next.text}');
      await _tts.speak(next.text, volume: next.volume);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      _cleanupDedupeCache();
    }
  }

  void _cleanupDedupeCache() {
    final cutoff = DateTime.now().subtract(_maxDedupeRetention);
    _recentlySpoken.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  Future<void> clear() async {
    _queue.clear();
    notifyListeners();
    await _tts.stop();
  }
}
