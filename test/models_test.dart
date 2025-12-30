import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/models/noise_event.dart';

void main() {
  group('AslSign Model Tests', () {
    test('creates a letter sign correctly', () {
      final sign = AslSign.fromLetter('A', confidence: 0.95);

      expect(sign.letter, 'A');
      expect(sign.word, 'A');
      expect(sign.confidence, 0.95);
      expect(sign.category, 'letter');
    });

    test('creates a word sign correctly', () {
      final sign = AslSign.fromWord('hello', confidence: 0.85);

      expect(sign.letter, '');
      expect(sign.word, 'hello');
      expect(sign.confidence, 0.85);
      expect(sign.category, 'word');
    });

    test('equality works correctly', () {
      final sign1 = AslSign.fromLetter('A');
      final sign2 = AslSign.fromLetter('A');
      final sign3 = AslSign.fromLetter('B');

      expect(sign1, sign1.copyWith());
      expect(sign1, isNot(sign2));
      expect(sign1, isNot(sign3));
    });
  });

  group('DetectedObject Model Tests', () {
    test('creates object with correct properties', () {
      final object = DetectedObject.basic(
        label: 'person',
        confidence: 0.92,
        boundingBox: const Rect.fromLTWH(0, 0, 100, 200),
      );

      expect(object.label, 'person');
      expect(object.displayName, 'Person');
      expect(object.confidence, 0.92);
      expect(object.isHighConfidence, true);
    });

    test('correctly identifies high confidence', () {
      final highConf = DetectedObject.basic(
        label: 'cup',
        confidence: 0.85,
        boundingBox: Rect.zero,
      );
      final lowConf = DetectedObject.basic(
        label: 'cup',
        confidence: 0.5,
        boundingBox: Rect.zero,
      );

      expect(highConf.isHighConfidence, true);
      expect(lowConf.isHighConfidence, false);
    });
  });

  group('NoiseEvent Model Tests', () {
    test('creates noise event correctly', () {
      final event = NoiseEvent.fromAudio(
        type: NoiseType.doorbell,
        intensity: 0.8,
      );

      expect(event.type, NoiseType.doorbell);
      expect(event.intensity, 0.8);
      expect(event.shouldAlert, true);
    });

    test('calculates severity correctly', () {
      final critical = NoiseEvent.fromAudio(
        type: NoiseType.alarm,
        intensity: 0.95,
      );
      final low = NoiseEvent.fromAudio(
        type: NoiseType.knock,
        intensity: 0.3,
      );

      expect(critical.severity, AlertSeverity.critical);
      expect(low.severity, AlertSeverity.low);
    });
  });

  group('AppMode Tests', () {
    test('returns correct route paths', () {
      expect(AppMode.translation.routePath, '/translation');
      expect(AppMode.detection.routePath, '/detection');
      expect(AppMode.sound.routePath, '/sound');
      expect(AppMode.chat.routePath, '/chat');
    });

    test('returns correct navigation indices', () {
      expect(AppMode.translation.navigationIndex, 0);
      expect(AppMode.detection.navigationIndex, 1);
      expect(AppMode.sound.navigationIndex, 2);
      expect(AppMode.chat.navigationIndex, 3);
    });

    test('cycles through modes correctly', () {
      expect(AppMode.translation.next, AppMode.detection);
      expect(AppMode.detection.next, AppMode.sound);
      expect(AppMode.sound.next, AppMode.chat);
      expect(AppMode.chat.next, AppMode.translation);

      expect(AppMode.translation.previous, AppMode.chat);
      expect(AppMode.detection.previous, AppMode.translation);
    });

    test('creates mode from navigation index', () {
      expect(AppMode.fromNavigationIndex(0), AppMode.translation);
      expect(AppMode.fromNavigationIndex(2), AppMode.sound);
    });
  });
}
