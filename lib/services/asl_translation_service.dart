import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/asl_translation.dart';
import 'package:signsync/services/nlp_service.dart';

class AslTranslationService with ChangeNotifier {
  final NlpService _nlp;

  bool _isInitialized = false;
  String? _error;

  Map<String, AslDictionaryEntry> _dictionary = {};

  AslTranslationService({NlpService? nlp}) : _nlp = nlp ?? const NlpService();

  bool get isInitialized => _isInitialized;
  String? get error => _error;
  int get dictionarySize => _dictionary.length;

  Future<void> initialize({String assetPath = 'assets/data/asl_dictionary.json'}) async {
    if (_isInitialized) return;

    try {
      final raw = await rootBundle.loadString(assetPath);
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final entries = (jsonMap['entries'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      _dictionary = entries.map((k, v) {
        return MapEntry(k.toString().toLowerCase(), AslDictionaryEntry.fromJson(v as Map<String, dynamic>));
      });

      _isInitialized = true;
      _error = null;
      notifyListeners();
      LoggerService.info('ASL dictionary loaded: ${_dictionary.length} entries');
    } catch (e, stack) {
      _error = 'Failed to load ASL dictionary: $e';
      _isInitialized = true;
      LoggerService.error('ASL dictionary load failed', error: e, stackTrace: stack);
      notifyListeners();
    }
  }

  Future<AslTranslationResult> translate(String input) async {
    if (!_isInitialized) {
      await initialize();
    }

    final tokens = _nlp.tokenize(input);
    final glosses = <String>[];
    final unknown = <String>[];

    // Greedy phrase match up to 4-grams.
    int i = 0;
    while (i < tokens.length) {
      String? matchedKey;
      AslDictionaryEntry? matchedEntry;

      for (int n = 4; n >= 1; n--) {
        if (i + n > tokens.length) continue;
        final phrase = tokens.sublist(i, i + n).join(' ');
        final entry = _dictionary[phrase];
        if (entry != null) {
          matchedKey = phrase;
          matchedEntry = entry;
          break;
        }
      }

      if (matchedEntry != null) {
        glosses.add(matchedEntry.gloss);
        i += matchedKey!.split(' ').length;
        continue;
      }

      final token = tokens[i];
      final lemma = _nlp.lemmatize(token);
      final entry = _dictionary[token] ?? _dictionary[lemma];

      if (entry != null) {
        glosses.add(entry.gloss);
      } else {
        unknown.add(token);
        glosses.add(token.toUpperCase());
      }

      i++;
    }

    return AslTranslationResult(
      input: input,
      tokens: tokens,
      glosses: glosses,
      unknownTokens: unknown,
    );
  }
}
