import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:signsync/core/logging/logger_service.dart';

@immutable
class AslSignDictionaryEntry {
  final int index;
  final String label;
  final String word;
  final String category;
  final String description;
  final List<String> synonyms;
  final String? phonetic;

  const AslSignDictionaryEntry({
    required this.index,
    required this.label,
    required this.word,
    required this.category,
    required this.description,
    required this.synonyms,
    required this.phonetic,
  });

  factory AslSignDictionaryEntry.fromJson(Map<String, dynamic> json) {
    return AslSignDictionaryEntry(
      index: (json['index'] as num).toInt(),
      label: (json['label'] as String?)?.trim() ?? '',
      word: (json['word'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? 'unknown',
      description: (json['description'] as String?)?.trim() ?? '',
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      phonetic: (json['phonetic'] as String?)?.trim(),
    );
  }

  String get normalizedKey => _normalize(word.isNotEmpty ? word : label);

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

/// Loads and provides access to the ASL sign dictionary.
///
/// The dictionary is a JSON asset mapping the model's class index to an ASL
/// label/word plus optional metadata (synonyms, phonetic hint, etc.).
class AslSignDictionaryService {
  final String assetPath;

  Map<int, AslSignDictionaryEntry> _byIndex = <int, AslSignDictionaryEntry>{};
  Map<String, AslSignDictionaryEntry> _byKey = <String, AslSignDictionaryEntry>{};
  bool _isLoaded = false;
  Future<void>? _loadFuture;

  AslSignDictionaryService({
    this.assetPath = 'assets/models/asl_sign_dictionary.json',
  });

  bool get isLoaded => _isLoaded;

  Future<void> ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = (decoded['classes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AslSignDictionaryEntry.fromJson)
          .toList();

      _byIndex = {for (final e in list) e.index: e};
      _byKey = {
        for (final e in list)
          if (e.normalizedKey.isNotEmpty) e.normalizedKey: e,
      };

      _isLoaded = true;
      LoggerService.info('ASL sign dictionary loaded', extra: {
        'entries': list.length,
        'asset': assetPath,
      });
    } catch (e, stack) {
      _isLoaded = false;
      LoggerService.error('Failed to load ASL sign dictionary', error: e, stack: stack);
      rethrow;
    }
  }

  AslSignDictionaryEntry? byIndex(int index) => _byIndex[index];

  /// Fuzzy match a label/word against dictionary entries.
  ///
  /// This is a lightweight safeguard for cases where the model label naming
  /// differs slightly from the dictionary, or when we want to map predictions
  /// to the closest canonical sign term.
  AslSignDictionaryEntry? fuzzyMatch(String label, {int maxDistance = 2}) {
    if (_byKey.isEmpty) return null;

    final normalized = AslSignDictionaryEntry._normalize(label);
    if (normalized.isEmpty) return null;

    final exact = _byKey[normalized];
    if (exact != null) return exact;

    AslSignDictionaryEntry? best;
    int bestDistance = 1 << 30;

    for (final entry in _byKey.values) {
      final distance = _levenshtein(normalized, entry.normalizedKey);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry;
      }
    }

    return bestDistance <= maxDistance ? best : null;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final v0 = List<int>.generate(b.length + 1, (i) => i);
    final v1 = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[b.length];
  }
}
