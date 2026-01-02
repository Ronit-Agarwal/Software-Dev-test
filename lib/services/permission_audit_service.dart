import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/services/encryption_service.dart';

class PermissionAuditService {
  static const String _dbName = 'signsync_audit.db';
  static const int _dbVersion = 1;
  static const String _table = 'permission_audit';

  final EncryptionService _encryption;

  Database? _db;
  bool _isInitialized = false;

  PermissionAuditService({EncryptionService? encryption}) : _encryption = encryption ?? EncryptionService();

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _encryption.initialize();

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_${_table}_timestamp ON $_table(timestamp DESC)');
      },
    );

    _isInitialized = true;
  }

  Future<void> log({
    required String permission,
    required String action,
    required String status,
    Map<String, dynamic>? extra,
  }) async {
    await _ensureInitialized();

    final payload = {
      'permission': permission,
      'action': action,
      'status': status,
      'extra': extra,
    };

    final encrypted = _encryption.encryptString(jsonEncode(payload));
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db!.insert(_table, {'payload': encrypted, 'timestamp': now});
    } catch (e, stack) {
      LoggerService.warn('Failed to write permission audit log', error: e, stackTrace: stack);
    }
  }

  Future<List<Map<String, dynamic>>> getRecent({int limit = 100}) async {
    await _ensureInitialized();

    final rows = await _db!.query(
      _table,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return rows.map((row) {
      final decrypted = _encryption.decryptString(row['payload'] as String);
      final payload = jsonDecode(decrypted);
      return {
        'timestamp': DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int).toIso8601String(),
        'payload': payload,
      };
    }).toList();
  }

  Future<void> deleteAll() async {
    await _ensureInitialized();
    await _db!.delete(_table);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
  }
}
