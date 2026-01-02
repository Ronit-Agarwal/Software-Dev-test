import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signsync/core/logging/logger_service.dart';

class SecureStorageService {
  static final Map<String, String> _inMemoryFallback = <String, String>{};

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      LoggerService.warn('SecureStorage write failed, falling back to memory', extra: {'key': key});
      _inMemoryFallback[key] = value;
    }
  }

  Future<String?> read({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      return value ?? _inMemoryFallback[key];
    } catch (e) {
      return _inMemoryFallback[key];
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      _inMemoryFallback.remove(key);
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      _inMemoryFallback.clear();
    }
  }

  Future<void> writeJson({required String key, required Map<String, dynamic> json}) async {
    await write(key: key, value: jsonEncode(json));
  }

  Future<Map<String, dynamic>?> readJson({required String key}) async {
    final value = await read(key: key);
    if (value == null || value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static Map<String, String> get inMemoryDebugStore => _inMemoryFallback;
}
