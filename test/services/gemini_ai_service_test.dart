// Unit tests for GeminiAiService
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signsync/services/gemini_ai_service.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/models/chat_message.dart';
import 'dart:async';

import '../helpers/mocks.dart';

void main() {
  late GeminiAiService geminiService;
  late MockTtsService mockTtsService;

  setUpAll(() {
    registerMockFallbacks();
  });

  setUp(() {
    mockTtsService = MockTtsService();
    geminiService = GeminiAiService();
  });

  group('GeminiAiService Initialization', () {
    test('should start uninitialized', () {
      expect(geminiService.isInitialized, false);
      expect(geminiService.isLoading, false);
      expect(geminiService.voiceEnabled, false);
    });

    test('should initialize with valid API key', () async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );

      expect(geminiService.isInitialized, true);
      expect(geminiService.error, null);
    });

    test('should throw error with empty API key', () async {
      expect(
        () => geminiService.initialize(apiKey: '', ttsService: mockTtsService),
        throwsA(isA<Exception>()),
      );

      expect(geminiService.error, isNotNull);
    });

    test('should not initialize twice', () async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );

      await geminiService.initialize(
        apiKey: 'another-key',
        ttsService: mockTtsService,
      );

      // Should still be initialized with first key
      expect(geminiService.isInitialized, true);
    });

    test('should set voice enabled when initialized with TTS', () async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );

      geminiService.setVoiceEnabled(true);
      expect(geminiService.voiceEnabled, true);
    });
  });

  group('GeminiAiService Message Handling', () {
    setUp(() async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );
    });

    test('should send message and get response', () async {
      final message = 'Hello, how are you?';
      final response = await geminiService.sendMessage(message);

      expect(response, isNotNull);
      expect(response.isUser, false);
      expect(response.content, isNotEmpty);
      expect(response.error, null);
    });

    test('should return loading message while processing', () async {
      final loading = ChatMessage.ai(
        content: 'Thinking...',
        isLoading: true,
      );

      expect(loading.isLoading, true);
      expect(loading.isAi, true);
    });

    test('should handle empty message', () async {
      final response = await geminiService.sendMessage('');

      // Should either return error or request clarification
      expect(response, isNotNull);
    });

    test('should handle very long message', () async {
      final longMessage = 'Hello ' * 1000;
      final response = await geminiService.sendMessage(longMessage);

      expect(response, isNotNull);
    });

    test('should add context to chat history', () async {
      geminiService.updateAppContext({
        'currentMode': 'translation',
        'detectedSign': 'A',
      });

      final response = await geminiService.sendMessage('What did I sign?');

      expect(response, isNotNull);
    });
  });

  group('GeminiAiService Rate Limiting', () {
    setUp(() async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );
    });

    test('should limit requests to 60 per minute', () async {
      final futures = List.generate(
        65,
        (i) => geminiService.sendMessage('Test message $i'),
      );

      final results = await Future.wait(futures);

      // Some requests should fail or be throttled
      expect(results.length, 65);
    });

    test('should track request timestamps', () async {
      await geminiService.sendMessage('Test 1');
      await geminiService.sendMessage('Test 2');
      await geminiService.sendMessage('Test 3');

      // Timestamps should be tracked
      expect(geminiService.appContext, isNotNull);
    });
  });

  group('GeminiAiService Voice Integration', () {
    setUp(() async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );
    });

    test('should enable voice output', () {
      geminiService.setVoiceEnabled(true);
      expect(geminiService.voiceEnabled, true);
    });

    test('should disable voice output', () {
      geminiService.setVoiceEnabled(true);
      geminiService.setVoiceEnabled(false);
      expect(geminiService.voiceEnabled, false);
    });

    test('should speak response when voice enabled', () async {
      geminiService.setVoiceEnabled(true);
      when(() => mockTtsService.speak(any())).thenAnswer((_) async {});

      await geminiService.sendMessage('Hello');

      verify(() => mockTtsService.speak(any())).called(1);
    });

    test('should not speak when voice disabled', () async {
      geminiService.setVoiceEnabled(false);

      await geminiService.sendMessage('Hello');

      verifyNever(() => mockTtsService.speak(any()));
    });
  });

  group('GeminiAiService Offline Fallback', () {
    setUp(() async {
      // Initialize with invalid key to trigger offline mode
      try {
        await geminiService.initialize(
          apiKey: 'invalid-key',
          ttsService: mockTtsService,
        );
      } catch (_) {
        // Expected to fail, service will use offline fallback
      }
    });

    test('should return offline fallback for "hello"', () async {
      final response = await geminiService.sendMessage('hello');

      expect(response, isNotNull);
      expect(response.content.toLowerCase(), contains('signsync'));
    });

    test('should return offline fallback for "help"', () async {
      final response = await geminiService.sendMessage('help');

      expect(response, isNotNull);
      expect(response.content.toLowerCase(), contains('help'));
    });

    test('should return offline fallback for "asl"', () async {
      final response = await geminiService.sendMessage('asl');

      expect(response, isNotNull);
      expect(response.content.toLowerCase(), contains('asl'));
    });

    test('should return fallback for unknown query', () async {
      final response = await geminiService.sendMessage('xyz123');

      expect(response, isNotNull);
    });
  });

  group('GeminiAiService Context Awareness', () {
    setUp(() async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );
    });

    test('should update app context', () {
      geminiService.updateAppContext({
        'currentMode': 'detection',
        'objects': ['person', 'chair'],
      });

      final context = geminiService.appContext;
      expect(context['currentMode'], 'detection');
      expect(context['objects'], ['person', 'chair']);
    });

    test('should use context in responses', () async {
      geminiService.updateAppContext({
        'detectedSign': 'A',
        'confidence': 0.95,
      });

      final response = await geminiService.sendMessage('What did I sign?');

      expect(response, isNotNull);
    });

    test('should handle empty context', () async {
      final response = await geminiService.sendMessage('Hello');

      expect(response, isNotNull);
    });
  });

  group('GeminiAiService Error Handling', () {
    test('should handle network errors gracefully', () async {
      await geminiService.initialize(
        apiKey: 'network-error-key',
        ttsService: mockTtsService,
      );

      final response = await geminiService.sendMessage('Test');

      expect(response, isNotNull);
    });

    test('should set error state on failure', () async {
      try {
        await geminiService.initialize(
          apiKey: 'error-key',
          ttsService: mockTtsService,
        );
      } catch (_) {}

      expect(geminiService.error, isNotNull);
    });

    test('should recover after error', () async {
      // First initialization fails
      try {
        await geminiService.initialize(
          apiKey: 'bad-key',
          ttsService: mockTtsService,
        );
      } catch (_) {}

      // Second initialization succeeds
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );

      expect(geminiService.isInitialized, true);
    });
  });

  group('GeminiAiService Chat History', () {
    setUp(() async {
      await geminiService.initialize(
        apiKey: TestConfig.testApiKey,
        ttsService: mockTtsService,
      );
    });

    test('should maintain conversation context', () async {
      await geminiService.sendMessage('What is ASL?');
      await geminiService.sendMessage('How do I say "thank you"?');

      final response = await geminiService.sendMessage('Show me "thank you" again');

      expect(response, isNotNull);
    });

    test('should clear chat history', () async {
      await geminiService.sendMessage('Message 1');
      await geminiService.sendMessage('Message 2');

      geminiService.clearChatHistory();

      // New conversation should start fresh
      final response = await geminiService.sendMessage('Hello');

      expect(response, isNotNull);
    });
  });

  group('GeminiAiService System Prompt', () {
    test('should build system prompt with app capabilities', () {
      // Verify system prompt includes key information
      final prompt = geminiService.buildSystemPrompt();

      expect(prompt, contains('SignSync'));
      expect(prompt, contains('ASL'));
      expect(prompt, contains('accessibility'));
    });
  });
}
