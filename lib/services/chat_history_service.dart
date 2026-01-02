import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/chat_message.dart';
import 'package:signsync/services/encryption_service.dart';

class ChatHistoryService with ChangeNotifier {
  static const String _dbName = 'chat_history.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'conversations';

  final EncryptionService _encryption;

  Database? _database;
  bool _isInitialized = false;

  final List<ChatMessage> _messageCache = [];
  int _cacheSize = 50;

  ChatHistoryService({EncryptionService? encryption}) : _encryption = encryption ?? EncryptionService();

  bool get isInitialized => _isInitialized;
  List<ChatMessage> get messages => List.unmodifiable(_messageCache);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _encryption.initialize();

      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, _dbName);

      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
      );

      _isInitialized = true;
      await _loadCache();
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error('Failed to initialize chat history', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_error INTEGER DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_${_tableName}_timestamp ON $_tableName(timestamp DESC)');
  }

  Future<void> _loadCache() async {
    if (_database == null) return;
    final messages = await getMessages(limit: _cacheSize);
    _messageCache
      ..clear()
      ..addAll(messages);
  }

  Future<void> addMessage(ChatMessage message) async {
    await _ensureInitialized();

    final encryptedContent = _encryption.encryptString(message.content);

    await _database!.insert(
      _tableName,
      {
        'message_id': message.id,
        'role': message.isUser ? 'user' : 'ai',
        'content': encryptedContent,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
        'is_error': message.isError ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _messageCache.add(message);
    if (_messageCache.length > _cacheSize) {
      _messageCache.removeAt(0);
    }

    notifyListeners();
  }

  Future<void> addMessages(List<ChatMessage> messages) async {
    await _ensureInitialized();

    final batch = _database!.batch();
    for (final message in messages) {
      batch.insert(
        _tableName,
        {
          'message_id': message.id,
          'role': message.isUser ? 'user' : 'ai',
          'content': _encryption.encryptString(message.content),
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'is_error': message.isError ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    _messageCache.addAll(messages);
    if (_messageCache.length > _cacheSize) {
      _messageCache.removeRange(0, _messageCache.length - _cacheSize);
    }

    notifyListeners();
  }

  Future<List<ChatMessage>> getMessages({
    int limit = 100,
    int offset = 0,
    bool? isUser,
    DateTime? since,
  }) async {
    await _ensureInitialized();

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (isUser != null) {
      whereParts.add('role = ?');
      whereArgs.add(isUser ? 'user' : 'ai');
    }

    if (since != null) {
      whereParts.add('timestamp >= ?');
      whereArgs.add(since.millisecondsSinceEpoch);
    }

    final rows = await _database!.query(
      _tableName,
      where: whereParts.isNotEmpty ? whereParts.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((row) {
      final decrypted = _encryption.decryptString(row['content'] as String);
      return ChatMessage(
        id: row['message_id'] as String,
        content: decrypted,
        isUser: (row['role'] as String) == 'user',
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        isError: (row['is_error'] as int) == 1,
      );
    }).toList();
  }

  Future<List<ChatMessage>> getRecentMessages(int count) => getMessages(limit: count);

  Future<void> deleteMessage(String messageId) async {
    await _ensureInitialized();

    await _database!.delete(
      _tableName,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );

    _messageCache.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _ensureInitialized();

    await _database!.delete(_tableName);
    _messageCache.clear();
    notifyListeners();
  }

  Future<int> getMessageCount() async {
    await _ensureInitialized();
    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String> exportToJson() async {
    final messages = await getMessages(limit: 2000);
    return jsonEncode({
      'exportDate': DateTime.now().toIso8601String(),
      'messageCount': messages.length,
      'messages': messages.map((m) => m.toJson()).toList(),
    });
  }

  Future<void> importFromJson(String jsonData) async {
    final decoded = jsonDecode(jsonData) as Map<String, dynamic>;
    final list = (decoded['messages'] as List?) ?? const [];
    final messages = list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    await addMessages(messages);
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
  }

  @override
  void dispose() {
    if (_database != null) {
      unawaited(_database!.close());
    }
    _database = null;
    _isInitialized = false;
    super.dispose();
  }
}
