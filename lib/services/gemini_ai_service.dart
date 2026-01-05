import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/chat_message.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/utils/retry_helper.dart';

/// AI Assistant Service using Google Gemini 2.5 API.
///
/// Provides context-aware chat capabilities, voice input/output,
/// and integration with app state for accessibility assistance.
class GeminiAiService with ChangeNotifier {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Rate limiting
  final int _maxRequestsPerMinute = 60;
  final List<DateTime> _requestTimestamps = [];
  DateTime? _lastRequestTime;

  // Voice integration
  TtsService? _ttsService;
  bool _voiceEnabled = false;

  // App state context
  Map<String, dynamic> _appContext = {};

  // Network monitoring
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Retry logic
  final RetryHelper _retryHelper = RetryHelpers.network(
    maxRetries: 3,
    timeout: const Duration(seconds: 30),
  );

  // Offline fallback responses
  static const Map<String, String> _fallbackResponses = {
    'hello': "Hello! I'm SignSync AI. I'm here to help you with sign language questions and accessibility features. How can I assist you today?",
    'hi': "Hi there! I'm your SignSync AI assistant. Feel free to ask me anything about sign language or the app's features!",
    'help': "I can help you with:\n\n• ASL sign meanings and descriptions\n• Learning resources for sign language\n• Using the SignSync app features\n• Accessibility tips and guidance\n• Questions about detected objects or signs",
    'thank': "You're welcome! Is there anything else I can help you with regarding sign language or accessibility?",
    'asl': "ASL (American Sign Language) is a complete, natural language used by the Deaf community in the United States and parts of Canada. It uses hand shapes, facial expressions, and body movements to convey meaning.",
    'sign': "Sign language is a visual means of communicating using gestures, facial expressions, and body language. ASL has its own grammar and syntax, separate from English.",
    'learn': "To learn ASL effectively:\n\n1. Start with the alphabet and fingerspelling\n2. Learn basic greetings and common phrases\n3. Practice regularly with videos or native signers\n4. Take formal classes if possible\n5. Join Deaf community events\n6. Use apps like SignSync for daily practice",
    'object': "The object detection feature can identify objects around you using the camera. It can detect items like chairs, tables, doors, vehicles, and more. You can enable audio alerts to hear when objects are detected.",
    'sound': "The sound alert feature listens for important sounds like alarms, doorbells, or other significant audio events. It can provide visual and haptic alerts when sounds are detected.",
  };

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get voiceEnabled => _voiceEnabled;
  Map<String, dynamic> get appContext => Map.unmodifiable(_appContext);
  bool get isOnline => _isOnline;

  /// Initializes the Gemini AI service.
  Future<void> initialize({
    required String apiKey,
    TtsService? ttsService,
  }) async {
    if (_isInitialized) {
      LoggerService.warn('Gemini AI service already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing Gemini AI service');

      // Initialize the model with Gemini 2.5
      _model = GenerativeModel(
        model: 'gemini-2.5-pro',
        apiKey: apiKey,
      );

      // Create a chat session with context
      _chatSession = _model!.startChat(
        history: [
          Content.text(_buildSystemPrompt()),
        ],
      );

      // Set up TTS if provided
      _ttsService = ttsService;

      // Monitor network connectivity
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      final connectivity = await _connectivity.checkConnectivity();
      _isOnline = connectivity != ConnectivityResult.none;

      _isInitialized = true;
      _error = null;
      notifyListeners();

      LoggerService.info('Gemini AI service initialized successfully (online: $_isOnline)');
    } catch (e, stack) {
      _error = 'Failed to initialize: $e';
      LoggerService.error('Failed to initialize Gemini AI', error: e, stack: stack);
      notifyListeners();
      rethrow;
    }
  }

  /// Builds the system prompt for context awareness.
  String _buildSystemPrompt() {
    return '''You are SignSync AI, a helpful assistant for a mobile accessibility app that helps users with sign language translation, object detection, and sound alerts.

Key capabilities of the app:
1. ASL Translation: Translates ASL signs (static and dynamic) to text using ML models
2. Object Detection: Identifies objects in real-time using YOLOv11, provides spatial audio alerts
3. Sound Alerts: Detects important sounds like alarms, doorbells, sirens
4. AI Assistant: Provides context-aware help for accessibility needs

Your role:
- Help users understand sign language (ASL)
- Explain app features and how to use them
- Provide accessibility tips and guidance
- Answer questions about detected objects or signs
- Offer support for learning sign language
- Keep responses concise and accessible (simple language, clear explanations)

App Context:
${_contextToString()}

Always provide helpful, encouraging responses that are accessible to users with varying needs. Use simple language and avoid jargon when possible.''';
  }

  /// Converts app context to string for the prompt.
  String _contextToString() {
    final buffer = StringBuffer();
    
    if (_appContext['detectedObject'] != null) {
      buffer.writeln('- Recently detected object: ${_appContext['detectedObject']}');
    }
    
    if (_appContext['detectedSign'] != null) {
      buffer.writeln('- Recently detected sign: ${_appContext['detectedSign']}');
    }
    
    if (_appContext['currentMode'] != null) {
      buffer.writeln('- Current app mode: ${_appContext['currentMode']}');
    }
    
    if (_appContext['performanceStats'] != null) {
      final stats = _appContext['performanceStats'] as Map;
      buffer.writeln('- App performance: ${stats['fps']?.toStringAsFixed(1) ?? 'N/A'} FPS, ${stats['latency']?.toStringAsFixed(0) ?? 'N/A'}ms latency');
    }
    
    return buffer.toString().trim();
  }

  /// Sends a message to the AI and returns the response.
  Future<ChatMessage> sendMessage(String message) async {
    if (!_isInitialized) {
      throw StateError('Gemini AI service not initialized');
    }

    // Check rate limit
    if (!_checkRateLimit()) {
      _error = 'Rate limit exceeded. Please wait.';
      notifyListeners();
      return ChatMessage.error('Please wait before sending another message.');
    }

    // If offline, use offline responses immediately
    if (!_isOnline) {
      LoggerService.info('Offline mode, using fallback response');
      return _getOfflineResponse(message);
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Use retry helper for API call
      final response = await _retryHelper.execute(
        () async {
          if (_chatSession == null) {
            throw StateError('Chat session not initialized');
          }

          final enhancedMessage = _enhanceMessageWithContext(message);
          final content = Content.text(enhancedMessage);

          final result = await _chatSession!.sendMessage(content);
          final text = result.text ?? 'I apologize, but I could not generate a response.';

          return ChatMessage.ai(content: text);
        },
        onError: (error, attempt) {
          LoggerService.warn('AI message attempt $attempt failed: $error');
        },
        shouldRetry: (error) {
          // Retry on network errors and timeouts
          return RetryHelpers.isRetryableError(error);
        },
        onRetry: (attempt, delay) {
          LoggerService.info('Retrying AI message (attempt $attempt, delay: ${delay.inMilliseconds}ms)');
        },
        onMaxRetriesReached: (error) {
          LoggerService.error('Max retries reached for AI message, falling back to offline response: $error');
        },
      );

      _isLoading = false;
      _lastRequestTime = DateTime.now();
      notifyListeners();

      // Speak response if voice is enabled
      if (_voiceEnabled && _ttsService != null && response.isAi) {
        await _ttsService!.speak(response.content);
      }

      return response;
    } catch (e, stack) {
      _error = 'Failed to send message: $e';
      _isLoading = false;
      notifyListeners();

      LoggerService.error('Failed to send message to AI', error: e, stack: stack);

      // Fall back to offline response
      return _getOfflineResponse(message);
    }
  }

  /// Enhances the user message with current app context.
  String _enhanceMessageWithContext(String message) {
    if (_appContext.isEmpty) return message;
    
    final context = _contextToString();
    if (context.isEmpty) return message;
    
    return '$message\n\n[Current Context: $context]';
  }

  /// Gets an offline fallback response.
  ChatMessage _getOfflineResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Check for matching keywords
    for (final entry in _fallbackResponses.entries) {
      if (lowerMessage.contains(entry.key)) {
        return ChatMessage.ai(content: entry.value);
      }
    }
    
    // Default fallback
    return ChatMessage.ai(
      content: "I'm currently offline, but I can still help! You can ask me about:\n\n• ASL sign meanings\n• App features (ASL translation, object detection, sound alerts)\n• Learning sign language\n• Accessibility tips\n\nFor more detailed questions, please connect to the internet and try again.",
    );
  }

  /// Checks if the request rate is within limits.
  bool _checkRateLimit() {
    final now = DateTime.now();
    
    // Remove timestamps older than 1 minute
    _requestTimestamps.removeWhere((ts) => now.difference(ts).inMinutes > 0);
    
    // Check if we've exceeded the limit
    if (_requestTimestamps.length >= _maxRequestsPerMinute) {
      return false;
    }
    
    // Add current timestamp
    _requestTimestamps.add(now);
    return true;
  }

  /// Updates the app context for contextual responses.
  void updateContext(Map<String, dynamic> updates) {
    _appContext.addAll(updates);
    LoggerService.debug('Updated AI context: $updates');
    
    // Rebuild chat session with new context if initialized
    if (_isInitialized && _model != null) {
      _chatSession = _model!.startChat(
        history: [
          Content.text(_buildSystemPrompt()),
        ],
      );
    }
  }

  /// Clears the app context.
  void clearContext() {
    _appContext.clear();
    LoggerService.debug('Cleared AI context');
    
    // Rebuild chat session without context
    if (_isInitialized && _model != null) {
      _chatSession = _model!.startChat(
        history: [
          Content.text(_buildSystemPrompt()),
        ],
      );
    }
  }

  /// Enables or disables voice output for AI responses.
  Future<void> setVoiceEnabled(bool enabled) async {
    _voiceEnabled = enabled;
    notifyListeners();
    LoggerService.info('AI voice output ${enabled ? "enabled" : "disabled"}');
  }

  /// Clears the conversation history.
  void clearHistory() {
    if (_model != null) {
      _chatSession = _model!.startChat(
        history: [
          Content.text(_buildSystemPrompt()),
        ],
      );
    }
    LoggerService.info('AI conversation history cleared');
  }

  /// Gets a suggested response based on the current context.
  List<String> getSuggestedResponses() {
    final suggestions = <String>[];
    
    if (_appContext['detectedObject'] != null) {
      final obj = _appContext['detectedObject'] as String;
      suggestions.add('Tell me more about $obj');
      suggestions.add('Is $obj dangerous?');
    }
    
    if (_appContext['detectedSign'] != null) {
      final sign = _appContext['detectedSign'] as String;
      suggestions.add('Explain the sign for $sign');
      suggestions.add('Show me variations of $sign');
    }
    
    // Always add these
    suggestions.addAll([
      'How do I use object detection?',
      'Teach me a common sign',
      'Tips for beginners',
    ]);
    
    // Limit to 4 suggestions
    return suggestions.take(4).toList();
  }

  /// Processes voice input and returns the transcript.
  Future<String?> processVoiceInput(String transcript) async {
    LoggerService.info('Processing voice input: $transcript');
    return transcript;
  }

  /// Handles network connectivity changes.
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    if (wasOnline && !_isOnline) {
      LoggerService.warn('Network lost, switching to offline mode');
      _error = 'Network connection lost. Using offline mode.';
      notifyListeners();
    } else if (!wasOnline && _isOnline) {
      LoggerService.info('Network restored, switching to online mode');
      _error = null;
      notifyListeners();
    }
  }

  /// Checks if currently online.
  Future<bool> checkConnectivity() async {
    final connectivity = await _connectivity.checkConnectivity();
    _isOnline = connectivity != ConnectivityResult.none;
    return _isOnline;
  }

  /// Disposes the service and releases resources.
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _retryHelper.dispose();
    _chatSession = null;
    _model = null;
    _isInitialized = false;
    super.dispose();
  }
}

/// Configuration for AI chat behavior.
class ChatConfig {
  final int maxHistoryLength;
  final Duration responseTimeout;
  final bool enableMemory;
  final bool enablePersonality;

  const ChatConfig({
    this.maxHistoryLength = 20,
    this.responseTimeout = const Duration(seconds: 30),
    this.enableMemory = true,
    this.enablePersonality = true,
  });

  /// Default configuration.
  static const ChatConfig defaultConfig = ChatConfig();
}
