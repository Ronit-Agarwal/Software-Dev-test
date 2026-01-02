import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a chat message in the AI chat feature.
@immutable
class ChatMessage with EquatableMixin {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final String? error;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.error,
  });

  /// Returns true if this is an error message.
  bool get isError => error != null;

  /// Returns true if this is an AI message.
  bool get isAi => !isUser;

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isLoading': isLoading,
      'error': error,
    };
  }

  /// Creates a ChatMessage from JSON.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLoading: json['isLoading'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  /// Creates a user message.
  factory ChatMessage.user({
    required String content,
  }) {
    return ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an AI message.
  factory ChatMessage.ai({
    required String content,
    bool isLoading = false,
  }) {
    return ChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: isLoading,
    );
  }

  /// Creates an error message.
  factory ChatMessage.error(String error) {
    return ChatMessage(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      content: error,
      isUser: false,
      timestamp: DateTime.now(),
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        isUser,
        timestamp,
        isLoading,
        error,
      ];

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
    String? error,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Represents a chat conversation.
@immutable
class ChatConversation with EquatableMixin {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    this.lastMessageAt,
  });

  /// Returns the last message in the conversation.
  ChatMessage? get lastMessage {
    if (messages.isEmpty) return null;
    return messages.last;
  }

  /// Returns true if the conversation is empty.
  bool get isEmpty => messages.isEmpty;

  /// Returns the number of messages in the conversation.
  int get messageCount => messages.length;

  @override
  List<Object?> get props => [id, title, messages, createdAt, lastMessageAt];

  ChatConversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? lastMessageAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  /// Creates a new conversation with an added message.
  ChatConversation addMessage(ChatMessage message) {
    return copyWith(
      messages: [...messages, message],
      lastMessageAt: message.timestamp,
    );
  }

  /// Creates a conversation with a cleared message history.
  ChatConversation clearMessages() {
    return copyWith(
      messages: [],
      lastMessageAt: null,
    );
  }
}

/// Configuration for the AI chat service.
class ChatConfig with EquatableMixin {
  final String systemPrompt;
  final int maxTokens;
  final double temperature;
  final String model;

  const ChatConfig({
    this.systemPrompt = _defaultSystemPrompt,
    this.maxTokens = 1000,
    this.temperature = 0.7,
    this.model = 'gpt-3.5-turbo',
  });

  static const _defaultSystemPrompt = '''
You are SignSync AI, an assistant for the SignSync app that helps users
with sign language translation, ASL learning, and accessibility questions.
Be helpful, patient, and clear in your responses.
''';

  @override
  List<Object?> get props => [systemPrompt, maxTokens, temperature, model];

  ChatConfig copyWith({
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
    String? model,
  }) {
    return ChatConfig(
      systemPrompt: systemPrompt ?? this.systemPrompt,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      model: model ?? this.model,
    );
  }
}
