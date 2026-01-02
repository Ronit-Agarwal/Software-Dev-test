import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/chat_message.dart';

/// Service for storing and managing chat history with encryption.
///
/// Uses SQLite database with AES encryption for secure local storage
/// of AI conversation history.
class ChatHistoryService with ChangeNotifier {
  Database? _database;
  bool _isInitialized = false;
  String? _encryptionKey;
  final encrypt.Encrypter? _encrypter;
  
  static const String _dbName = 'chat_history.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'conversations';
  
  // Cache for quick access
  final List<ChatMessage> _messageCache = [];
  int _cacheSize = 50;

  ChatHistoryService({String? encryptionKey}) 
      : _encryptionKey = encryptionKey ?? _generateDefaultKey(),
        _encrypter = null {
    _initializeEncrypter();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  List<ChatMessage> get messages => List.unmodifiable(_messageCache);

  /// Initializes the database.
  Future<void> initialize() async {
    if (_isInitialized) {
      LoggerService.warn('Chat history service already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing chat history service');
      
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      
      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      // Load messages into cache
      await _loadCache();
      
      _isInitialized = true;
      notifyListeners();
      
      LoggerService.info('Chat history service initialized successfully');
    } catch (e, stack) {
      LoggerService.error('Failed to initialize chat history', error: e, stack: stack);
      rethrow;
    }
  }

  /// Creates the database schema.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_error INTEGER DEFAULT 0,
        encrypted INTEGER DEFAULT 1
      )
    ''');
    
    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_timestamp ON $_tableName(timestamp DESC)
    ''');
  }

  /// Handles database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Future migrations go here
    }
  }

  /// Initializes the encryption engine.
  void _initializeEncrypter() {
    if (_encryptionKey == null) return;
    
    try {
      // Derive a proper key from the string
      final keyBytes = utf8.encode(_encryptionKey!.padRight(32, '0').substring(0, 32));
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      _encrypter = encrypt.Encrypter(encrypt.AES(key));
      LoggerService.info('Encryption engine initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize encryption', error: e);
    }
  }

  /// Generates a default encryption key.
  static String _generateDefaultKey() {
    final bytes = utf8.encode('signsync-default-key-2024');
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Encrypts a string value.
  String? _encrypt(String? value) {
    if (value == null || _encrypter == null) return value;
    
    try {
      final iv = encrypt.IV.fromLength(16);
      final encrypted = _encrypter!.encrypt(value, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      LoggerService.error('Encryption failed', error: e);
      return value;
    }
  }

  /// Decrypts a string value.
  String? _decrypt(String? value) {
    if (value == null || _encrypter == null) return value;
    
    try {
      final parts = value.split(':');
      if (parts.length != 2) return value;
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      LoggerService.error('Decryption failed', error: e);
      return value;
    }
  }

  /// Loads messages into cache.
  Future<void> _loadCache() async {
    if (_database == null) return;
    
    final messages = await getMessages(limit: _cacheSize);
    _messageCache.clear();
    _messageCache.addAll(messages);
  }

  /// Adds a message to the history.
  Future<void> addMessage(ChatMessage message) async {
    if (_database == null) {
      LoggerService.warn('Database not initialized');
      return;
    }

    try {
      final encryptedContent = _encrypt(message.content);
      
      await _database!.insert(
        _tableName,
        {
          'message_id': message.id,
          'role': message.isUser ? 'user' : 'ai',
          'content': encryptedContent,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'is_error': message.isError ? 1 : 0,
          'encrypted': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Update cache
      _messageCache.add(message);
      if (_messageCache.length > _cacheSize) {
        _messageCache.removeAt(0);
      }
      
      notifyListeners();
      LoggerService.debug('Added message to history: ${message.id}');
    } catch (e, stack) {
      LoggerService.error('Failed to add message to history', error: e, stack: stack);
      rethrow;
    }
  }

  /// Adds multiple messages to the history.
  Future<void> addMessages(List<ChatMessage> messages) async {
    if (_database == null) return;
    
    final batch = _database!.batch();
    
    for (final message in messages) {
      final encryptedContent = _encrypt(message.content);
      
      batch.insert(
        _tableName,
        {
          'message_id': message.id,
          'role': message.isUser ? 'user' : 'ai',
          'content': encryptedContent,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'is_error': message.isError ? 1 : 0,
          'encrypted': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    
    // Update cache
    _messageCache.addAll(messages);
    if (_messageCache.length > _cacheSize) {
      _messageCache.removeRange(0, _messageCache.length - _cacheSize);
    }
    
    notifyListeners();
    LoggerService.info('Added ${messages.length} messages to history');
  }

  /// Gets messages from the history.
  Future<List<ChatMessage>> getMessages({
    int limit = 100,
    int offset = 0,
    bool? isUser,
    DateTime? since,
  }) async {
    if (_database == null) return [];
    
    try {
      String query = 'SELECT * FROM $_tableName';
      final List<dynamic> args = [];
      final List<String> conditions = [];
      
      if (isUser != null) {
        conditions.add('role = ?');
        args.add(isUser ? 'user' : 'ai');
      }
      
      if (since != null) {
        conditions.add('timestamp >= ?');
        args.add(since.millisecondsSinceEpoch);
      }
      
      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }
      
      query += ' ORDER BY timestamp DESC LIMIT ? OFFSET ?';
      args.addAll([limit, offset]);
      
      final results = await _database!.rawQuery(query, args);
      
      return results.map((row) {
        final decryptedContent = _decrypt(row['content'] as String?);
        
        return ChatMessage(
          id: row['message_id'] as String,
          content: decryptedContent ?? '',
          isUser: row['role'] == 'user',
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
          isError: (row['is_error'] as int) == 1,
        );
      }).toList();
    } catch (e, stack) {
      LoggerService.error('Failed to get messages from history', error: e, stack: stack);
      return [];
    }
  }

  /// Gets the most recent messages.
  Future<List<ChatMessage>> getRecentMessages(int count) async {
    return getMessages(limit: count);
  }

  /// Searches messages by content.
  Future<List<ChatMessage>> searchMessages(String query) async {
    if (_database == null) return [];
    
    try {
      final results = await _database!.query(
        _tableName,
        where: 'content LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'timestamp DESC',
      );
      
      return results.map((row) {
        final decryptedContent = _decrypt(row['content'] as String?);
        
        return ChatMessage(
          id: row['message_id'] as String,
          content: decryptedContent ?? '',
          isUser: row['role'] == 'user',
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
          isError: (row['is_error'] as int) == 1,
        );
      }).toList();
    } catch (e, stack) {
      LoggerService.error('Failed to search messages', error: e, stack: stack);
      return [];
    }
  }

  /// Deletes a specific message.
  Future<void> deleteMessage(String messageId) async {
    if (_database == null) return;
    
    await _database!.delete(
      _tableName,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    
    _messageCache.removeWhere((m) => m.id == messageId);
    notifyListeners();
    
    LoggerService.debug('Deleted message: $messageId');
  }

  /// Clears all message history.
  Future<void> clearAll() async {
    if (_database == null) return;
    
    await _database!.delete(_tableName);
    
    _messageCache.clear();
    notifyListeners();
    
    LoggerService.info('Cleared all message history');
  }

  /// Clears messages older than a certain date.
  Future<void> clearBeforeDate(DateTime date) async {
    if (_database == null) return;
    
    await _database!.delete(
      _tableName,
      where: 'timestamp < ?',
      whereArgs: [date.millisecondsSinceEpoch],
    );
    
    await _loadCache();
    
    LoggerService.info('Cleared messages before $date');
  }

  /// Gets the total count of messages.
  Future<int> getMessageCount() async {
    if (_database == null) return 0;
    
    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Exports messages as JSON.
  Future<String> exportToJson() async {
    final messages = await getMessages(limit: 1000);
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'messageCount': messages.length,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    
    return jsonEncode(exportData);
  }

  /// Imports messages from JSON.
  Future<void> importFromJson(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final messagesList = data['messages'] as List;
      
      final messages = messagesList.map((json) {
        return ChatMessage.fromJson(json as Map<String, dynamic>);
      }).toList();
      
      await addMessages(messages);
      
      LoggerService.info('Imported ${messages.length} messages from JSON');
    } catch (e, stack) {
      LoggerService.error('Failed to import messages from JSON', error: e, stack: stack);
      rethrow;
    }
  }

  /// Gets storage statistics.
  Future<Map<String, dynamic>> getStorageStats() async {
    if (_database == null) return {};
    
    final messageCount = await getMessageCount();
    
    // Get first and last message timestamps
    final firstResult = await _database!.rawQuery(
      'SELECT timestamp FROM $_tableName ORDER BY timestamp ASC LIMIT 1',
    );
    final lastResult = await _database!.rawQuery(
      'SELECT timestamp FROM $_tableName ORDER BY timestamp DESC LIMIT 1',
    );
    
    DateTime? firstMessage;
    DateTime? lastMessage;
    
    if (firstResult.isNotEmpty) {
      firstMessage = DateTime.fromMillisecondsSinceEpoch(firstResult.first['timestamp'] as int);
    }
    
    if (lastResult.isNotEmpty) {
      lastMessage = DateTime.fromMillisecondsSinceEpoch(lastResult.first['timestamp'] as int);
    }
    
    return {
      'totalMessages': messageCount,
      'cachedMessages': _messageCache.length,
      'firstMessageDate': firstMessage?.toIso8601String(),
      'lastMessageDate': lastMessage?.toIso8601String(),
      'encryptionEnabled': _encrypter != null,
    };
  }

  /// Disposes the service and closes the database.
  @override
  void dispose() async {
    await _database?.close();
    _isInitialized = false;
    super.dispose();
  }
}

/// Model for a stored chat message with database fields.
class StoredChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isError;

  const StoredChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isError = false,
  });

  /// Converts from a ChatMessage.
  factory StoredChatMessage.fromChatMessage(ChatMessage message) {
    return StoredChatMessage(
      id: message.id,
      role: message.isUser ? 'user' : 'ai',
      content: message.content,
      timestamp: message.timestamp,
      isError: message.isError,
    );
  }

  /// Converts to a ChatMessage.
  ChatMessage toChatMessage() {
    return ChatMessage(
      id: id,
      content: content,
      isUser: role == 'user',
      timestamp: timestamp,
      isError: isError,
    );
  }
}
