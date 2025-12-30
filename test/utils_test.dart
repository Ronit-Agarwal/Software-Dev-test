import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/utils/extensions.dart';
import 'package:signsync/utils/helpers.dart';

void main() {
  group('String Extensions Tests', () {
    test('isNullOrEmpty returns true for null', () {
      expect(null.isNullOrEmpty, true);
    });

    test('isNullOrEmpty returns true for empty string', () {
      expect(''.isNullOrEmpty, true);
    });

    test('isNullOrEmpty returns false for non-empty string', () {
      expect('hello'.isNullOrEmpty, false);
    });

    test('capitalize works correctly', () {
      expect('hello'.capitalize(), 'Hello');
      expect('HELLO'.capitalize(), 'Hello');
      expect(''.capitalize(), '');
    });

    test('orDefault returns value for non-null', () {
      expect('hello'.orDefault('world'), 'hello');
    });

    test('orDefault returns default for null', () {
      expect(null.orDefault('world'), 'world');
    });
  });

  group('List Extensions Tests', () {
    test('getOrNull returns null for out of bounds', () {
      final list = [1, 2, 3];
      expect(list.getOrNull(5), null);
      expect(list.getOrNull(-1), null);
    });

    test('getOrNull returns element for valid index', () {
      final list = [1, 2, 3];
      expect(list.getOrNull(0), 1);
      expect(list.getOrNull(2), 3);
    });

    test('chunk creates correct chunks', () {
      final list = [1, 2, 3, 4, 5];
      final chunks = list.chunk(2);

      expect(chunks.length, 3);
      expect(chunks[0], [1, 2]);
      expect(chunks[1], [3, 4]);
      expect(chunks[2], [5]);
    });
  });

  group('Num Extensions Tests', () {
    test('clamp works correctly', () {
      expect(5.clamp(1, 10), 5);
      expect(0.clamp(1, 10), 1);
      expect(15.clamp(1, 10), 10);
    });

    test('inRange works correctly', () {
      expect(5.inRange(1, 10), true);
      expect(0.inRange(1, 10), false);
      expect(15.inRange(1, 10), false);
    });

    test('duration extensions work correctly', () {
      expect(100.ms, const Duration(milliseconds: 100));
      expect(5.sec, const Duration(seconds: 5));
      expect(2.min, const Duration(minutes: 2));
    });
  });

  group('Debouncer Tests', () {
    test('debounces function calls', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      int count = 0;

      debouncer.run(() => count++);
      debouncer.run(() => count++);
      debouncer.run(() => count++);

      expect(count, 0);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 1);

      debouncer.dispose();
    });
  });

  group('Throttler Tests', () {
    test('throttles function calls', () async {
      final throttler = Throttler(interval: const Duration(milliseconds: 100));
      int count = 0;

      throttler.run(() => count++);
      throttler.run(() => count++);
      throttler.run(() => count++);

      expect(count, 1);

      await Future.delayed(const Duration(milliseconds: 150));
      throttler.run(() => count++);
      expect(count, 2);

      throttler.dispose();
    });
  });

  group('Color Extensions Tests', () {
    test('contrastingText returns black for light colors', () {
      expect(const Color(0xFFFFFFFF).contrastingText, Colors.black);
    });

    test('contrastingText returns white for dark colors', () {
      expect(const Color(0xFF000000).contrastingText, Colors.white);
    });
  });

  group('AppConstants Tests', () {
    test('has correct app name', () {
      expect(AppConstants.appName, 'SignSync');
    });

    test('has correct version', () {
      expect(AppConstants.appVersion, '1.0.0');
    });

    test('has correct inference threshold', () {
      expect(AppConstants.inferenceConfidenceThreshold, 0.6);
    });

    test('has correct spacing values', () {
      expect(AppConstants.spacingXs, 8.0);
      expect(AppConstants.spacingMd, 16.0);
      expect(AppConstants.spacingLg, 24.0);
    });

    test('has correct radius values', () {
      expect(AppConstants.radiusSm, 4.0);
      expect(AppConstants.radiusMd, 8.0);
      expect(AppConstants.radiusLg, 12.0);
    });

    test('has correct touch target sizes', () {
      expect(AppConstants.minTouchTarget, 44.0);
      expect(AppConstants.recommendedTouchTarget, 48.0);
    });
  });
}
