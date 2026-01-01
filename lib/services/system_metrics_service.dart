import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:signsync/core/logging/logger_service.dart';

/// Provides lightweight device and runtime metrics for the dashboard.
class SystemMetricsService with ChangeNotifier {
  final Battery _battery;

  Timer? _timer;

  int? _batteryLevel;
  BatteryState? _batteryState;
  int _memoryBytes = 0;

  SystemMetricsService({Battery? battery}) : _battery = battery ?? Battery();

  int? get batteryLevel => _batteryLevel;
  BatteryState? get batteryState => _batteryState;

  int get memoryBytes => _memoryBytes;

  Future<void> initialize() async {
    await _refresh();
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;

      // Not available on all platforms but supported on Android/iOS with Dart VM.
      _memoryBytes = ProcessInfo.currentRss;

      notifyListeners();
    } catch (e, stack) {
      LoggerService.debug('System metrics refresh failed: $e', error: e, stackTrace: stack);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
