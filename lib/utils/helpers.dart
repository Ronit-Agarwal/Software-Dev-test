import 'dart:async';
import 'package:flutter/material.dart';

/// Debouncer for delaying execution of a function.
///
/// This is useful for search inputs, filtering, and other operations
/// that shouldn't run on every single change.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Runs the given function after the delay.
  ///
  /// If [debounce] is called again before the delay expires,
  /// the previous timer is cancelled and a new one starts.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Runs the given function with the latest value after the delay.
  ///
  /// This is useful for value-based debouncing.
  void runWithValue<T>(T value, void Function(T value) action) {
    _timer?.cancel();
    _timer = Timer(delay, () => action(value));
  }

  /// Cancels the current timer if one is active.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer.
  void dispose() {
    cancel();
  }
}

/// Throttler for limiting function execution rate.
///
/// This ensures a function is only called at most once per interval,
/// useful for scroll events, resize events, etc.
class Throttler {
  final Duration interval;
  Timer? _timer;
  DateTime? _lastRun;

  Throttler({this.interval = const Duration(milliseconds: 500)});

  /// Runs the function if the throttle interval has passed.
  bool run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
      return true;
    }
    return false;
  }

  /// Cancels the current throttle timer.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the throttler.
  void dispose() {
    cancel();
  }
}

/// Rate limiter for controlling function execution frequency.
///
/// This is similar to a throttler but resets after each successful call,
/// useful for API rate limiting.
class RateLimiter {
  final int maxCalls;
  final Duration window;
  final List<DateTime> _timestamps = [];

  RateLimiter({required this.maxCalls, required this.window});

  /// Returns true if the action can be executed.
  bool tryAcquire() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > window);
    
    if (_timestamps.length < maxCalls) {
      _timestamps.add(now);
      return true;
    }
    return false;
  }

  /// Returns the number of remaining calls in the current window.
  int get remainingCalls {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > window);
    return maxCalls - _timestamps.length;
  }

  /// Clears the rate limiter history.
  void reset() {
    _timestamps.clear();
  }
}

/// Helper class for performing delayed operations.
class DelayedAction {
  static Timer? _timer;

  /// Performs an action after the specified delay.
  static Future<void> after({
    required Duration delay,
    required VoidCallback action,
  }) async {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending delayed action.
  static void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Extension to add debouncing to [TextField] controllers.
extension DebounceTextEditingController on TextEditingController {
  /// Creates a debounced stream of text changes.
  Stream<String> get debouncedTextChanges {
    return Stream<String>.fromIterable(text.split(''));
  }
}

/// A widget that debounces its child builds.
class DebouncedBuilder extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context) builder;

  const DebouncedBuilder({
    super.key,
    this.duration = const Duration(milliseconds: 300),
    required this.builder,
  });

  @override
  State<DebouncedBuilder> createState() => _DebouncedBuilderState();
}

class _DebouncedBuilderState extends State<DebouncedBuilder> {
  Timer? _timer;

  @override
  void didUpdateWidget(DebouncedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    _timer ??= Timer(widget.duration, () {
      if (mounted) setState(() {});
    });
    return widget.builder(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A widget that throttles its child builds.
class ThrottledBuilder extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context) builder;

  const ThrottledBuilder({
    super.key,
    this.duration = const Duration(milliseconds: 500),
    required this.builder,
  });

  @override
  State<ThrottledBuilder> createState() => _ThrottledBuilderState();
}

class _ThrottledBuilderState extends State<ThrottledBuilder> {
  Timer? _timer;
  bool _shouldRebuild = false;

  @override
  void didUpdateWidget(ThrottledBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_timer == null && _shouldRebuild) {
      _shouldRebuild = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_timer != null) {
      _shouldRebuild = true;
      _timer ??= Timer(widget.duration, () {
        if (mounted) {
          setState(() {
            _timer = null;
          });
        }
      });
    }
    return widget.builder(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
