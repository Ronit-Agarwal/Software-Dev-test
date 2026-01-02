import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/services/secure_storage_service.dart';

class EncryptionService {
  static const String _masterKeyStorageKey = 'signsync_master_key_v1';

  final SecureStorageService _secureStorage;

  encrypt.Encrypter? _encrypter;
  encrypt.Key? _key;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  EncryptionService({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final existing = await _secureStorage.read(key: _masterKeyStorageKey);
      final keyBytes = existing != null ? base64Decode(existing) : _generateKeyBytes();

      if (existing == null) {
        await _secureStorage.write(key: _masterKeyStorageKey, value: base64Encode(keyBytes));
      }

      _key = encrypt.Key(Uint8List.fromList(keyBytes));
      _encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
      _isInitialized = true;
    } catch (e, stack) {
      LoggerService.error('Failed to initialize EncryptionService', error: e, stackTrace: stack);
      rethrow;
    }
  }

  String encryptString(String plaintext) {
    _ensureInitializedSync();

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String decryptString(String ciphertext) {
    _ensureInitializedSync();

    final parts = ciphertext.split(':');
    if (parts.length != 2) return ciphertext;

    try {
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (_) {
      return ciphertext;
    }
  }

  Uint8List encryptBytes(Uint8List bytes) {
    final payload = base64Encode(bytes);
    return Uint8List.fromList(utf8.encode(encryptString(payload)));
  }

  Uint8List decryptBytes(Uint8List bytes) {
    final payload = utf8.decode(bytes, allowMalformed: true);
    final decrypted = decryptString(payload);
    try {
      return base64Decode(decrypted);
    } catch (_) {
      return bytes;
    }
  }

  Future<void> rotateKey() async {
    final keyBytes = _generateKeyBytes();
    await _secureStorage.write(key: _masterKeyStorageKey, value: base64Encode(keyBytes));
    _key = encrypt.Key(Uint8List.fromList(keyBytes));
    _encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
  }

  Future<void> wipeKey() async {
    await _secureStorage.delete(key: _masterKeyStorageKey);
    _key = null;
    _encrypter = null;
    _isInitialized = false;
  }

  void _ensureInitializedSync() {
    if (!_isInitialized || _encrypter == null) {
      throw StateError('EncryptionService not initialized');
    }
  }

  Uint8List _generateKeyBytes() {
    final rand = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return bytes;
  }

  @visibleForTesting
  SecureStorageService get secureStorageForTest => _secureStorage;
}
