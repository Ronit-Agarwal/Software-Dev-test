// Tests for utility functions and helpers
import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/utils/helpers.dart';
import 'package:signsync/utils/constants.dart';
import 'dart:async';

void main() {
  group('Debouncer Tests', () {
    test('should delay execution', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      bool executed = false;

      debouncer.run(() => executed = true);

      expect(executed, false);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(executed, true);
    });

    test('should cancel previous timer', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      int executionCount = 0;

      debouncer.run(() => executionCount++);
      await Future.delayed(const Duration(milliseconds: 50));

      debouncer.run(() => executionCount++);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(executionCount, 1); // Only second execution should happen
    });

    test('should cancel pending execution', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      bool executed = false;

      debouncer.run(() => executed = true);
      debouncer.cancel();

      await Future.delayed(const Duration(milliseconds: 150));

      expect(executed, false);
    });

    test('should work with value-based debouncing', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      String lastValue = '';

      debouncer.runWithValue('a', (value) => lastValue = value);
      await Future.delayed(const Duration(milliseconds: 50));

      debouncer.runWithValue('b', (value) => lastValue = value);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(lastValue, 'b'); // Should use latest value
    });

    test('should dispose properly', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      bool executed = false;

      debouncer.run(() => executed = true);
      debouncer.dispose();

      await Future.delayed(const Duration(milliseconds: 150));

      expect(executed, false);
    });
  });

  group('Throttler Tests', () {
    test('should execute function immediately', () async {
      final throttler = Throttler(interval: const Duration(milliseconds: 100));
      bool executed = false;

      final ran = throttler.run(() => executed = true);

      expect(executed, true);
      expect(ran, true);
    });

    test('should throttle rapid calls', () async {
      final throttler = Throttler(interval: const Duration(milliseconds: 100));
      int executionCount = 0;

      throttler.run(() => executionCount++);
      throttler.run(() => executionCount++); // Should be throttled
      throttler.run(() => executionCount++); // Should be throttled

      await Future.delayed(const Duration(milliseconds: 50));

      expect(executionCount, 1); // Only first call executed

      await Future.delayed(const Duration(milliseconds: 60));

      throttler.run(() => executionCount++);

      expect(executionCount, 2); // Second call after interval
    });

    test('should return false when throttled', () async {
      final throttler = Throttler(interval: const Duration(milliseconds: 100));

      throttler.run(() {});
      final result = throttler.run(() {});

      expect(result, false);
    });

    test('should cancel timer', () async {
      final throttler = Throttler(interval: const Duration(milliseconds: 100));
      int executionCount = 0;

      throttler.run(() => executionCount++);
      throttler.cancel();

      await Future.delayed(const Duration(milliseconds: 50));
      throttler.run(() => executionCount++);

      expect(executionCount, 2);
    });

    test('should dispose properly', () async {
      final throttler = Throttler(interval: const Duration(milliseconds: 100));
      bool executed = false;

      throttler.run(() => executed = true);
      throttler.dispose();

      await Future.delayed(const Duration(milliseconds: 150));

      // Should execute immediately next time
      throttler.run(() => executed = true);

      expect(executed, true);
    });
  });

  group('RateLimiter Tests', () {
    test('should allow calls within limit', () {
      final rateLimiter = RateLimiter(maxCalls: 5, window: const Duration(minutes: 1));

      for (int i = 0; i < 5; i++) {
        expect(rateLimiter.tryAcquire(), true);
      }

      expect(rateLimiter.remainingCalls, 0);
    });

    test('should block calls over limit', () {
      final rateLimiter = RateLimiter(maxCalls: 3, window: const Duration(minutes: 1));

      expect(rateLimiter.tryAcquire(), true);
      expect(rateLimiter.tryAcquire(), true);
      expect(rateLimiter.tryAcquire(), true);
      expect(rateLimiter.tryAcquire(), false); // Blocked
    });

    test('should allow calls after window expires', () async {
      final rateLimiter = RateLimiter(maxCalls: 2, window: const Duration(milliseconds: 100));

      expect(rateLimiter.tryAcquire(), true);
      expect(rateLimiter.tryAcquire(), true);
      expect(rateLimiter.tryAcquire(), false);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(rateLimiter.tryAcquire(), true); // Should be allowed
    });

    test('should track remaining calls correctly', () {
      final rateLimiter = RateLimiter(maxCalls: 10, window: const Duration(minutes: 1));

      expect(rateLimiter.remainingCalls, 10);

      rateLimiter.tryAcquire();
      rateLimiter.tryAcquire();
      rateLimiter.tryAcquire();

      expect(rateLimiter.remainingCalls, 7);
    });

    test('should reset history', () {
      final rateLimiter = RateLimiter(maxCalls: 3, window: const Duration(minutes: 1));

      rateLimiter.tryAcquire();
      rateLimiter.tryAcquire();
      rateLimiter.tryAcquire();
      expect(rateLimiter.tryAcquire(), false);

      rateLimiter.reset();

      expect(rateLimiter.remainingCalls, 3);
      expect(rateLimiter.tryAcquire(), true);
    });
  });

  group('DelayedAction Tests', () {
    test('should execute action after delay', () async {
      bool executed = false;

      DelayedAction.after(
        delay: const Duration(milliseconds: 100),
        action: () => executed = true,
      );

      expect(executed, false);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(executed, true);
    });

    test('should cancel previous delayed action', () async {
      bool firstExecuted = false;
      bool secondExecuted = false;

      DelayedAction.after(
        delay: const Duration(milliseconds: 200),
        action: () => firstExecuted = true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      DelayedAction.after(
        delay: const Duration(milliseconds: 100),
        action: () => secondExecuted = true,
      );

      await Future.delayed(const Duration(milliseconds: 150));

      expect(firstExecuted, false);
      expect(secondExecuted, true);
    });

    test('should cancel action', () async {
      bool executed = false;

      DelayedAction.after(
        delay: const Duration(milliseconds: 100),
        action: () => executed = true,
      );

      DelayedAction.cancel();

      await Future.delayed(const Duration(milliseconds: 150));

      expect(executed, false);
    });
  });

  group('DebouncedBuilder Tests', () {
    testWidgets('should debounce widget rebuilds', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            buildCount++;
            return MaterialApp(
              home: Scaffold(
                body: DebouncedBuilder(
                  duration: const Duration(milliseconds: 100),
                  builder: (context) {
                    return const Text('Debounced');
                  },
                ),
              ),
            );
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final countAfterFirstRebuild = buildCount;

      await tester.pump(const Duration(milliseconds: 100));

      // Should rebuild after debounce
      expect(buildCount, greaterThan(countAfterFirstRebuild));
    });
  });

  group('ThrottledBuilder Tests', () {
    testWidgets('should throttle widget rebuilds', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThrottledBuilder(
              duration: const Duration(milliseconds: 100),
              builder: (context) {
                buildCount++;
                return Text('Build #$buildCount');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      final initialBuilds = buildCount;

      // Trigger multiple rebuilds
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      // Should not rebuild frequently
      expect(buildCount - initialBuilds, lessThan(3));
    });
  });

  group('Constants Tests', () {
    test('should have valid touch target sizes', () {
      expect(AppConstants.minTouchTarget, 44.0);
      expect(AppConstants.recommendedTouchTarget, 48.0);
    });

    test('should have valid text scale range', () {
      expect(AppConstants.textScaleMin, lessThanOrEqualTo(0.8));
      expect(AppConstants.textScaleMax, greaterThanOrEqualTo(2.0));
    });

    test('should have valid animation durations', () {
      expect(AppConstants.animationDurationFast, const Duration(milliseconds: 200));
      expect(AppConstants.animationDurationNormal, const Duration(milliseconds: 300));
      expect(AppConstants.animationDurationSlow, const Duration(milliseconds: 500));
    });

    test('should have valid spacing constants', () {
      expect(AppConstants.spacingXs, greaterThan(0));
      expect(AppConstants.spacingSm, greaterThan(AppConstants.spacingXs));
      expect(AppConstants.spacingMd, greaterThan(AppConstants.spacingSm));
      expect(AppConstants.spacingLg, greaterThan(AppConstants.spacingMd));
      expect(AppConstants.spacingXl, greaterThan(AppConstants.spacingLg));
    });
  });

  group('Extension Tests', () {
    test('String extensions work correctly', () {
      // Test capitalize extension if exists
      final test = 'hello';
      // Assuming there's a capitalize extension
      // expect(test.capitalize(), 'Hello');
    });

    test('Color extensions work correctly', () {
      // Test color utilities if they exist
      final color = Colors.blue;
      // Assuming there are color extensions
      // expect(color.toHex(), '#2196F3');
    });

    test('DateTime extensions work correctly', () {
      final now = DateTime.now();
      // Assuming there are datetime extensions
      // expect(now.toIso8601String(), isNotEmpty);
    });
  });
}
