import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/services/encryption_service.dart';

enum CachedResultType {
  detection,
  translation,
}

class ResultCacheService with ChangeNotifier {
  static const String _dbName = 'signsync_result_cache.db';
  static const int _dbVersion = 1;

  static const String _table = 'result_cache';

  final EncryptionService _encryption;

  Database? _db;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  ResultCacheService({EncryptionService? encryption}) : _encryption = encryption ?? EncryptionService();

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
            cache_key TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            last_seen INTEGER NOT NULL,
            hits INTEGER NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_${_table}_type_last_seen ON $_table(type, last_seen DESC)');
      },
    );

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> cacheDetectionFrame(DetectionFrame frame) async {
    await _ensureInitialized();
    final key = _hashDetectionFrame(frame);

    await _upsert(
      key: key,
      type: CachedResultType.detection,
      payload: {
        'id': frame.id,
        'timestamp': frame.timestamp.toIso8601String(),
        'frameIndex': frame.frameIndex,
        'inferenceTime': frame.inferenceTime,
        'objects': frame.objects
            .map(
              (o) => {
                'label': o.label,
                'confidence': o.confidence,
                'distance': o.distance,
                'depth': o.depth,
                'box': {
                  'left': o.boundingBox.left,
                  'top': o.boundingBox.top,
                  'width': o.boundingBox.width,
                  'height': o.boundingBox.height,
                },
              },
            )
            .toList(),
      },
    );
  }

  Future<void> cacheTranslationSign(AslSign sign) async {
    await _ensureInitialized();
    final key = sha256.convert(utf8.encode('translation:${sign.word}:${sign.letter}:${sign.category}')).toString();

    await _upsert(
      key: key,
      type: CachedResultType.translation,
      payload: sign.toJson(),
    );
  }

  Future<List<CachedResult>> getRecent({
    required CachedResultType type,
    int limit = 50,
  }) async {
    await _ensureInitialized();

    final rows = await _db!.query(
      _table,
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'last_seen DESC',
      limit: limit,
    );

    return rows.map((row) {
      final decrypted = _encryption.decryptString(row['payload'] as String);
      final jsonPayload = jsonDecode(decrypted) as Map<String, dynamic>;
      return CachedResult(
        key: row['cache_key'] as String,
        type: type,
        payload: jsonPayload,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(row['last_seen'] as int),
        hits: row['hits'] as int,
      );
    }).toList();
  }

  Future<int> count({CachedResultType? type}) async {
    await _ensureInitialized();

    final where = type != null ? 'type = ?' : null;
    final whereArgs = type != null ? [type.name] : null;

    final rows = await _db!.query(
      _table,
      columns: ['COUNT(*) as c'],
      where: where,
      whereArgs: whereArgs,
    );

    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> deleteAll() async {
    await _ensureInitialized();
    await _db!.delete(_table);
    notifyListeners();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }

  Future<void> _upsert({
    required String key,
    required CachedResultType type,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final encrypted = _encryption.encryptString(jsonEncode(payload));

    final existing = await _db!.query(
      _table,
      columns: ['cache_key', 'hits'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (existing.isEmpty) {
      await _db!.insert(
        _table,
        {
          'cache_key': key,
          'type': type.name,
          'payload': encrypted,
          'created_at': now,
          'last_seen': now,
          'hits': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      final hits = (existing.first['hits'] as int?) ?? 0;
      await _db!.update(
        _table,
        {
          'payload': encrypted,
          'last_seen': now,
          'hits': hits + 1,
        },
        where: 'cache_key = ?',
        whereArgs: [key],
      );
    }
  }

  String _hashDetectionFrame(DetectionFrame frame) {
    final summary = frame.objects
        .map((o) => _hashableObject(o))
        .toList()
      ..sort();

    return sha256.convert(utf8.encode('detection:${summary.join('|')}')).toString();
  }

  String _hashableObject(DetectedObject o) {
    final left = (o.boundingBox.left / 8).round();
    final top = (o.boundingBox.top / 8).round();
    final width = (o.boundingBox.width / 8).round();
    final height = (o.boundingBox.height / 8).round();
    final conf = (o.confidence * 100).round();
    return '${o.label}:$conf:$left,$top,$width,$height';
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      await initialize();
    } catch (e, stack) {
      LoggerService.error('Failed to initialize ResultCacheService', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

class CachedResult {
  final String key;
  final CachedResultType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime lastSeen;
  final int hits;

  const CachedResult({
    required this.key,
    required this.type,
    required this.payload,
    required this.createdAt,
    required this.lastSeen,
    required this.hits,
  });
}
