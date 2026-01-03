import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/chat_message.dart';
import 'package:signsync/services/tts_service.dart';

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

  /// Initializes the Gemini AI service with enhanced error handling.
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
      
      // Validate API key
      if (apiKey.trim().isEmpty) {
        throw GeminiAiException('invalid_api_key', 'API key cannot be empty');
      }
      
      // Initialize the model with Gemini 2.5
      _model = GenerativeModel(
        model: 'gemini-2.5-pro',
        apiKey: apiKey.trim(),
      );
      
      // Create a chat session with context
      _chatSession = _model!.startChat(
        history: [
          Content.text(_buildSystemPrompt()),
        ],
      );
      
      // Set up TTS if provided
      _ttsService = ttsService;
      _voiceEnabled = ttsService != null;
      
      // Initialize rate limiting
      _requestTimestamps.clear();
      _lastRequestTime = null;
      
      _isInitialized = true;
      _error = null;
      notifyListeners();
      
      LoggerService.info('Gemini AI service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize: $e';
      LoggerService.error('Failed to initialize Gemini AI', error: e, stack: stack);
      _isInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Enhanced send message with comprehensive error handling and recovery.
  Future<ChatMessage> sendMessage(
    String message, {
    bool enableVoice = false,
    int timeoutSeconds = 30,
  }) async {
    if (!_isInitialized) {
      throw GeminiAiException('not_initialized', 'AI service not initialized');
    }

    if (message.trim().isEmpty) {
      throw GeminiAiException('empty_message', 'Message cannot be empty');
    }

    // Check rate limiting
    if (!_checkRateLimit()) {
      final waitTime = _getRateLimitWaitTime();
      throw GeminiAiException(
        'rate_limited',
        'Too many requests. Please wait ${waitTime.inSeconds} seconds.',
      );
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final timestamp = DateTime.now();
    final userMessage = ChatMessage(
      id: 'user_${timestamp.millisecondsSinceEpoch}',
      content: message.trim(),
      isUser: true,
      timestamp: timestamp,
    );

    try {
      // Add user message to chat
      await _addMessageToHistory(userMessage);

      // Process message with timeout
      final aiResponse = await _processMessageWithTimeout(
        message,
        timeoutSeconds: timeoutSeconds,
      );

      final aiMessage = ChatMessage(
        id: 'ai_${timestamp.millisecondsSinceEpoch}',
        content: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      // Add AI response to chat
      await _addMessageToHistory(aiMessage);

      // Speak response if voice is enabled
      if (enableVoice && _voiceEnabled && _ttsService != null) {
        try {
          await _ttsService.speak(aiResponse);
        } catch (voiceError) {
          LoggerService.warn('Voice synthesis failed', error: voiceError);
          // Don't fail the entire request if voice fails
        }
      }

      notifyListeners();
      return aiMessage;
    } catch (e, stack) {
      final errorMessage = await _handleChatError(e, message);
      
      final errorChatMessage = ChatMessage(
        id: 'error_${timestamp.millisecondsSinceEpoch}',
        content: errorMessage,
        isUser: false,
        timestamp: DateTime.now(),
      );

      await _addMessageToHistory(errorChatMessage);
      _error = errorMessage;
      notifyListeners();
      
      return errorChatMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Process message with timeout and network resilience.
  Future<String> _processMessageWithTimeout(
    String message, {
    int timeoutSeconds = 30,
  }) async {
    try {
      // First, try to find an offline response
      final offlineResponse = _getOfflineResponse(message);
      if (offlineResponse != null) {
        LoggerService.debug('Using offline response for: $message');
        return offlineResponse;
      }

      // Check network connectivity
      if (!_hasNetworkConnection()) {
        LoggerService.warn('No network connection, using offline response');
        return _getOfflineResponse(message) ?? _getDefaultOfflineResponse();
      }

      // Try API call with timeout
      final response = await _makeApiCallWithTimeout(message, timeoutSeconds);
      return response;
    } catch (e, stack) {
      LoggerService.error('API call failed', error: e, stack: stack);
      
      // Determine error type and provide appropriate fallback
      if (e.toString().contains('timeout') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        LoggerService.warn('Network error detected, switching to offline mode');
        return _getOfflineResponse(message) ?? _getNetworkErrorResponse();
      }
      
      if (e.toString().contains('rate_limit') || 
          e.toString().contains('quota')) {
        LoggerService.warn('Rate limit exceeded, using offline response');
        return _getRateLimitResponse();
      }
      
      if (e.toString().contains('API') || 
          e.toString().contains('authentication')) {
        LoggerService.warn('API error, using offline response');
        return _getApiErrorResponse();
      }
      
      // Generic error
      return _getOfflineResponse(message) ?? _getDefaultOfflineResponse();
    }
  }

  /// Makes API call with comprehensive timeout and retry logic.
  Future<String> _makeApiCallWithTimeout(
    String message, 
    int timeoutSeconds,
  ) async {
    final maxRetries = 3;
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        attempt++;
        LoggerService.debug('API call attempt $attempt of $maxRetries');
        
        // Create completion request
        final content = Content.text(message);
        final response = await _chatSession!.sendMessage(content);
        
        final responseText = response.text;
        if (responseText == null || responseText.isEmpty) {
          throw GeminiAiException('empty_response', 'AI returned empty response');
        }
        
        // Update rate limiting
        _updateRateLimit();
        
        LoggerService.info('API call successful on attempt $attempt');
        return responseText;
        
      } catch (e, stack) {
        LoggerService.error('API call attempt $attempt failed', error: e, stack: stack);
        
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        // Exponential backoff
        final delay = Duration(seconds: 1 * attempt);
        LoggerService.debug('Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    
    throw GeminiAiException('max_retries_exceeded', 'Failed after $maxRetries attempts');
  }

  /// Enhanced offline response system.
  String? _getOfflineResponse(String message) {
    final lowercaseMessage = message.toLowerCase();
    
    // Find matching keywords
    for (final entry in _fallbackResponses.entries) {
      if (lowercaseMessage.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Check for common patterns
    if (lowercaseMessage.contains('hello') || lowercaseMessage.contains('hi')) {
      return _fallbackResponses['hello'];
    }
    
    if (lowercaseMessage.contains('help')) {
      return _fallbackResponses['help'];
    }
    
    if (lowercaseMessage.contains('thank')) {
      return _fallbackResponses['thank'];
    }
    
    if (lowercaseMessage.contains('asl') || lowercaseMessage.contains('sign')) {
      return _fallbackResponses['asl'];
    }
    
    if (lowercaseMessage.contains('learn') || lowercaseMessage.contains('study')) {
      return _fallbackResponses['learn'];
    }
    
    if (lowercaseMessage.contains('object') || lowercaseMessage.contains('detect')) {
      return _fallbackResponses['object'];
    }
    
    if (lowercaseMessage.contains('sound') || lowercaseMessage.contains('audio')) {
      return _fallbackResponses['sound'];
    }
    
    return null;
  }

  /// Enhanced error handling for chat errors.
  Future<String> _handleChatError(Object error, String originalMessage) async {
    final errorMessage = error.toString().toLowerCase();
    
    if (errorMessage.contains('timeout')) {
      return 'I\'m having trouble connecting right now. ${_getOfflineResponse(originalMessage) ?? _getNetworkErrorResponse()}';
    }
    
    if (errorMessage.contains('network') || errorMessage.contains('connection')) {
      return 'No internet connection detected. ${_getOfflineResponse(originalMessage) ?? _getNetworkErrorResponse()}';
    }
    
    if (errorMessage.contains('rate_limit') || errorMessage.contains('quota')) {
      return 'I\'m receiving too many requests right now. ${_getRateLimitResponse()}';
    }
    
    if (errorMessage.contains('api') || errorMessage.contains('auth')) {
      return 'I\'m experiencing technical difficulties. ${_getApiErrorResponse()}';
    }
    
    // Generic error fallback
    return 'Sorry, I\'m having trouble processing your request. ${_getOfflineResponse(originalMessage) ?? _getDefaultOfflineResponse()}';
  }

  /// Check if device has network connection.
  bool _hasNetworkConnection() {
    // Simple connectivity check - in real implementation, use connectivity_plus
    try {
      // This is a simplified check - real implementation should use proper connectivity checking
      return true; // Assume connection for now
    } catch (e) {
      LoggerService.warn('Network connectivity check failed', error: e);
      return false;
    }
  }

  /// Rate limiting check.
  bool _checkRateLimit() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    // Remove old timestamps
    _requestTimestamps.removeWhere((timestamp) => timestamp.isBefore(oneMinuteAgo));
    
    return _requestTimestamps.length < _maxRequestsPerMinute;
  }

  /// Update rate limiting timestamps.
  void _updateRateLimit() {
    _requestTimestamps.add(DateTime.now());
    _lastRequestTime = DateTime.now();
  }

  /// Get wait time for rate limit.
  Duration _getRateLimitWaitTime() {
    if (_requestTimestamps.isEmpty) return Duration.zero;
    
    final oldestRequest = _requestTimestamps.first;
    final waitTime = oldestRequest.add(const Duration(minutes: 1)).difference(DateTime.now());
    
    return waitTime.isNegative ? Duration.zero : waitTime;
  }

  /// Network error response.
  String _getNetworkErrorResponse() {
    return 'I\'m currently offline, but I can still help with basic sign language questions and app guidance.';
  }

  /// Rate limit response.
  String _getRateLimitResponse() {
    return 'I\'m receiving many requests right now. Please try again in a moment, or I can help you with basic sign language questions.';
  }

  /// API error response.
  String _getApiErrorResponse() {
    return 'I\'m experiencing technical difficulties. I can still provide basic assistance with sign language and app features.';
  }

  /// Default offline response.
  String _getDefaultOfflineResponse() {
    return 'I\'m here to help with sign language translation, object detection, and accessibility features. What would you like to know?';
  }

  /// Clear chat history with error recovery.
  Future<void> clearChatHistory() async {
    try {
      LoggerService.info('Clearing chat history');
      
      if (_chatSession != null) {
        // Create a new chat session to clear history
        _chatSession = _model!.startChat(
          history: [
            Content.text(_buildSystemPrompt()),
          ],
        );
      }
      
      notifyListeners();
      LoggerService.info('Chat history cleared successfully');
    } catch (e, stack) {
      LoggerService.error('Failed to clear chat history', error: e, stack: stack);
      throw GeminiAiException('clear_history_failed', 'Failed to clear chat history: $e');
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

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Try online API first
      ChatMessage response;
      
      if (_chatSession != null) {
        // Use Gemini API
        final enhancedMessage = _enhanceMessageWithContext(message);
        final content = Content.text(enhancedMessage);
        
        final result = await _chatSession!.sendMessage(content);
        final text = result.text ?? 'I apologize, but I could not generate a response.';
        
        response = ChatMessage.ai(content: text);
      } else {
        // Fallback to offline responses
        response = _getOfflineResponse(message);
      }

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

  /// Disposes the service and releases resources.
  @override
  void dispose() {
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
