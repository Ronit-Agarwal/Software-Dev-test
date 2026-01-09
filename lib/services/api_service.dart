import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/chat_message.dart';

/// Service for API calls and remote communication.
///
/// This service provides a base for making HTTP requests to
/// backend APIs, including retry logic and error handling.
class ApiService with ChangeNotifier {
  final _baseUrl = '';
  final _timeout = Duration(seconds: 30);
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;

  /// Initializes the API service.
  Future<void> initialize({String? baseUrl}) async {
    if (_isInitialized) return;

    LoggerService.info('Initializing API service');
    _isInitialized = true;
  }

  /// Makes a GET request to the specified endpoint.
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    final uri = Uri.parse(_baseUrl + endpoint).replace(
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );

    LoggerService.debug('GET request to: $uri');

    try {
      // Simulated GET request - in production, use http package
      await Future.delayed(const Duration(milliseconds: 100));
      
      return ApiResponse.success(
        statusCode: 200,
        data: {'message': 'Success'},
      );
    } catch (e, stack) {
      LoggerService.error('GET request failed', error: e, stack: stack);
      throw ApiException.fromError(e);
    }
  }

  /// Makes a POST request to the specified endpoint.
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    LoggerService.debug('POST request to: $_baseUrl$endpoint');

    try {
      // Simulated POST request - in production, use http package
      await Future.delayed(const Duration(milliseconds: 100));
      
      return ApiResponse.success(
        statusCode: 200,
        data: body,
      );
    } catch (e, stack) {
      LoggerService.error('POST request failed', error: e, stack: stack);
      throw ApiException.fromError(e);
    }
  }

  /// Makes a request with retry logic.
  Future<ApiResponse> requestWithRetry(
    Future<ApiResponse> Function() request, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          LoggerService.error('Max retries reached for request');
          rethrow;
        }

        LoggerService.warn('Request failed, retrying in ${delay.inMilliseconds}ms (attempt $attempts)');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  /// Cancels all pending requests.
  void cancelRequests() {
    LoggerService.debug('Cancelling all pending requests');
    // In a real implementation, this would cancel pending HTTP requests
  }
}

/// Represents an API response.
class ApiResponse with EquatableMixin {
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? error;
  final Map<String, String>? headers;
  final DateTime timestamp;

  const ApiResponse({
    required this.statusCode,
    this.data,
    this.error,
    this.headers,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a success response.
  factory ApiResponse.success({
    required int statusCode,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) {
    return ApiResponse(
      statusCode: statusCode,
      data: data,
      headers: headers,
    );
  }

  /// Creates an error response.
  factory ApiResponse.error({
    required int statusCode,
    required String error,
    Map<String, dynamic>? data,
  }) {
    return ApiResponse(
      statusCode: statusCode,
      error: error,
      data: data,
    );
  }

  /// Returns true if the request was successful (2xx status).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Returns true if the request was a client error (4xx).
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Returns true if the request was a server error (5xx).
  bool get isServerError => statusCode >= 500;

  @override
  List<Object?> get props => [statusCode, data, error, headers, timestamp];
}

/// Custom exception for API-related errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
  });

  /// Creates an exception from an error object.
  factory ApiException.fromError(Object error) {
    return ApiException(message: error.toString());
  }

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}

/// Service for chat API operations.
class ChatApiService {
  final ApiService _apiService;

  ChatApiService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  /// Sends a message to the AI chat service.
  Future<ChatMessage> sendMessage({
    required String message,
    required List<ChatMessage> conversationHistory,
    ChatConfig? config,
  }) async {
    LoggerService.info('Sending chat message');

    try {
      // In a real implementation, this would call an actual API
      await Future.delayed(const Duration(milliseconds: 500));

      // Simulate AI response
      final response = _generateResponse(message);

      return ChatMessage.ai(content: response);
    } catch (e, stack) {
      LoggerService.error('Failed to send chat message', error: e, stack: stack);
      return ChatMessage.error('Failed to get response: $e');
    }
  }

  /// Generates a simulated AI response.
  String _generateResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('hello') || message.contains('hi')) {
      return "Hello! I'm SignSync AI. I'm here to help you with sign language questions. How can I assist you today?";
    }

    if (message.contains('help')) {
      return "I can help you with:\n\n• ASL sign meanings and descriptions\n• Learning resources for sign language\n• General questions about the SignSync app\n• Tips for effective communication";
    }

    if (message.contains('thank')) {
      return "You're welcome! If you have any more questions about sign language or need help with the app, feel free to ask.";
    }

    return "That's an interesting question! While I don't have access to a real AI backend yet, in a production environment, I would provide you with detailed information about sign language. Is there something specific about ASL you'd like to learn more about?";
  }
}
