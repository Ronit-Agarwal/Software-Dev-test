import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/services/chat_history_service.dart';
import 'package:signsync/services/permission_audit_service.dart';
import 'package:signsync/services/result_cache_service.dart';
import 'package:signsync/services/secure_storage_service.dart';

class DataManagementService {
  final ChatHistoryService _chatHistory;
  final ResultCacheService _resultCache;
  final PermissionAuditService _permissionAudit;
  final SecureStorageService _secureStorage;

  DataManagementService({
    ChatHistoryService? chatHistory,
    ResultCacheService? resultCache,
    PermissionAuditService? permissionAudit,
    SecureStorageService? secureStorage,
  })  : _chatHistory = chatHistory ?? ChatHistoryService(),
        _resultCache = resultCache ?? ResultCacheService(),
        _permissionAudit = permissionAudit ?? PermissionAuditService(),
        _secureStorage = secureStorage ?? SecureStorageService();

  Future<String> exportAllData() async {
    try {
      final export = <String, dynamic>{
        'exportedAt': DateTime.now().toIso8601String(),
      };

      await _chatHistory.initialize();
      export['chatHistory'] = jsonDecode(await _chatHistory.exportToJson());

      await _resultCache.initialize();
      export['resultCache'] = {
        'detections': (await _resultCache.getRecent(type: CachedResultType.detection, limit: 200))
            .map((r) => _cachedResultToJson(r))
            .toList(),
        'translations': (await _resultCache.getRecent(type: CachedResultType.translation, limit: 200))
            .map((r) => _cachedResultToJson(r))
            .toList(),
      };

      await _permissionAudit.initialize();
      export['permissionAuditLog'] = await _permissionAudit.getRecent(limit: 200);

      final prefs = await SharedPreferences.getInstance();
      export['preferences'] = prefs.getKeys().fold<Map<String, Object?>>({}, (map, key) {
        map[key] = prefs.get(key);
        return map;
      });

      return jsonEncode(export);
    } catch (e, stack) {
      LoggerService.error('Failed to export app data', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> wipeAllLocalData() async {
    try {
      try {
        await _chatHistory.initialize();
        await _chatHistory.clearAll();
      } catch (_) {}

      try {
        await _resultCache.initialize();
        await _resultCache.deleteAll();
      } catch (_) {}

      try {
        await _permissionAudit.initialize();
        await _permissionAudit.deleteAll();
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}

      try {
        await _secureStorage.deleteAll();
      } catch (_) {}

      LoggerService.info('All local data wiped');
    } catch (e, stack) {
      LoggerService.error('Failed to wipe all local data', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Map<String, dynamic> _cachedResultToJson(CachedResult r) {
    return {
      'key': r.key,
      'type': r.type.name,
      'payload': r.payload,
      'createdAt': r.createdAt.toIso8601String(),
      'lastSeen': r.lastSeen.toIso8601String(),
      'hits': r.hits,
    };
  }
}
