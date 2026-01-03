import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:signsync/core/logging/logger_service.dart';

/// Core storage service for secure local data management.
///
/// Implements AES-256 encryption for all sensitive data stored in SQLite.
/// Used for caching detections, translations, and user preferences.
class StorageService with ChangeNotifier {
  Database? _database;
  bool _isInitialized = false;
  final String _encryptionKey;
  encrypt.Encrypter? _encrypter;

  static const String _dbName = 'signsync_storage.db';
  static const int _dbVersion = 1;

  // Tables
  static const String tableCache = 'result_cache';
  static const String tablePreferences = 'user_preferences';
  static const String tableAuditLog = 'audit_logs';

  StorageService({String? encryptionKey})
      : _encryptionKey = encryptionKey ?? _generateDefaultKey() {
    _initializeEncrypter();
  }

  bool get isInitialized => _isInitialized;

  /// Initializes the storage service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
      );

      _isInitialized = true;
      notifyListeners();
      LoggerService.info('Storage service initialized');
    } catch (e, stack) {
      LoggerService.error('Failed to initialize storage service', error: e, stack: stack);
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Result Cache Table (Detections, Translations)
    await db.execute('''
      CREATE TABLE $tableCache (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        encrypted INTEGER DEFAULT 1
      )
    ''');

    // Preferences Table
    await db.execute('''
      CREATE TABLE $tablePreferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        encrypted INTEGER DEFAULT 1
      )
    ''');

    // Audit Log Table
    await db.execute('''
      CREATE TABLE $tableAuditLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT NOT NULL,
        details TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_cache_type ON $tableCache(type)');
    await db.execute('CREATE INDEX idx_cache_timestamp ON $tableCache(timestamp)');
  }

  void _initializeEncrypter() {
    final keyBytes = utf8.encode(_encryptionKey.padRight(32, '0').substring(0, 32));
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  static String _generateDefaultKey() {
    // In a real app, this should be stored in Secure Storage / Keychain
    final bytes = utf8.encode('signsync-secure-storage-key-2024');
    return sha256.convert(bytes).toString();
  }

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

  // --- Result Cache Methods ---

  Future<void> cacheResult(String id, String type, Map<String, dynamic> data) async {
    if (!_isInitialized) await initialize();
    
    final jsonData = jsonEncode(data);
    final encryptedData = _encrypt(jsonData);

    await _database!.insert(
      tableCache,
      {
        'id': id,
        'type': type,
        'data': encryptedData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'encrypted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedResult(String id) async {
    if (!_isInitialized) await initialize();

    final results = await _database!.query(
      tableCache,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final encryptedData = results.first['data'] as String;
    final jsonData = _decrypt(encryptedData);
    
    if (jsonData == null) return null;
    return jsonDecode(jsonData) as Map<String, dynamic>;
  }

  // --- Preference Methods ---

  Future<void> setPreference(String key, dynamic value) async {
    if (!_isInitialized) await initialize();

    final stringValue = value.toString();
    final encryptedValue = _encrypt(stringValue);

    await _database!.insert(
      tablePreferences,
      {
        'key': key,
        'value': encryptedValue,
        'encrypted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getPreference(String key) async {
    if (!_isInitialized) await initialize();

    final results = await _database!.query(
      tablePreferences,
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final encryptedValue = results.first['value'] as String;
    return _decrypt(encryptedValue);
  }

  // --- Audit Logging ---

  Future<void> logEvent(String event, {String? details}) async {
    if (!_isInitialized) await initialize();

    await _database!.insert(
      tableAuditLog,
      {
        'event': event,
        'details': details,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    LoggerService.info('Audit Log: $event ${details ?? ''}');
  }

  // --- Data Management ---

  Future<void> wipeAllData() async {
    if (!_isInitialized) await initialize();

    await _database!.transaction((txn) async {
      await txn.delete(tableCache);
      await txn.delete(tablePreferences);
      await txn.delete(tableAuditLog);
    });

    LoggerService.warn('All local data has been wiped');
    notifyListeners();
  }

  Future<String> exportAllData() async {
    if (!_isInitialized) await initialize();

    final cache = await _database!.query(tableCache);
    final prefs = await _database!.query(tablePreferences);
    
    final export = {
      'version': _dbVersion,
      'exportTimestamp': DateTime.now().toIso8601String(),
      'results': cache.map((row) => {
        'id': row['id'],
        'type': row['type'],
        'data': _decrypt(row['data'] as String),
        'timestamp': row['timestamp'],
      }).toList(),
      'preferences': prefs.map((row) => {
        'key': row['key'],
        'value': _decrypt(row['value'] as String),
      }).toList(),
    };

    return jsonEncode(export);
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}
