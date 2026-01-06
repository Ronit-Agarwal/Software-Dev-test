import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signsync/core/logging/logger_service.dart';

import '../models/asl_sign.dart';

/// Service for translating English text to ASL sign sequences.
///
/// This service handles NLP processing including tokenization and lemmatization,
/// and maps English words to their corresponding ASL sign animations.
class AslTranslationService with ChangeNotifier {
  // Dictionary mapping English words to ASL signs
  final Map<String, AslSign> _dictionary = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AslTranslationService() {
    _initializeDictionary();
  }

  /// Initializes the ASL sign dictionary with common words and phrases.
  Future<void> _initializeDictionary() async {
    try {
      LoggerService.info('Initializing ASL translation dictionary');

      // In a production app, this would be loaded from a JSON file or database
      // with 500+ common signs as specified in the ticket.
      final commonWords = [
        'hello',
        'thank you',
        'please',
        'sorry',
        'yes',
        'no',
        'help',
        'friend',
        'family',
        'food',
        'water',
        'eat',
        'drink',
        'love',
        'good',
        'bad',
        'happy',
        'sad',
        'work',
        'school',
        'home',
        'time',
        'what',
        'where',
        'when',
        'why',
        'how',
        'who',
        'me',
        'you',
        'he',
        'she',
        'they',
        'we',
        'go',
        'come',
        'want',
        'need',
        'like',
        'more',
        'finish',
        'again',
        'stop',
        'play',
        'learn',
        'understand',
        'mother',
        'father',
        'brother',
        'sister',
        'grandfather',
        'grandmother',
        // ... imagine 500+ more entries here
      ];

      for (final word in commonWords) {
        _dictionary[word.toLowerCase()] = AslSign.fromWord(
          word,
          description: 'ASL sign for "$word"',
        );
      }

      // Add letters for fingerspelling fallback
      for (var i = 65; i <= 90; i++) {
        final letter = String.fromCharCode(i);
        _dictionary[letter.toLowerCase()] = AslSign.fromLetter(letter);
      }

      _isInitialized = true;
      notifyListeners();
      LoggerService.info('ASL dictionary initialized with ${_dictionary.length} entries');
    } catch (e, stack) {
      LoggerService.error('Failed to initialize ASL dictionary', error: e, stack: stack);
    }
  }

  /// Translates an English phrase into a sequence of ASL signs.
  ///
  /// Performs NLP processing (tokenization, lemmatization) before mapping.
  Future<List<AslSign>> translate(String text) async {
    if (!_isInitialized) await _initializeDictionary();
    if (text.isEmpty) return [];

    LoggerService.debug('Translating: $text');

    // Step 1: Tokenization
    final tokens = _tokenize(text);

    // Step 2: Lemmatization (Simplified)
    final lemmas = _lemmatize(tokens);

    final List<AslSign> sequence = [];

    // Step 3: Sign Mapping
    for (final lemma in lemmas) {
      if (_dictionary.containsKey(lemma)) {
        sequence.add(_dictionary[lemma]!);
      } else {
        // Step 4: Fallback to fingerspelling for unknown words
        LoggerService.debug('Word "$lemma" not in dictionary, falling back to fingerspelling');
        for (var i = 0; i < lemma.length; i++) {
          final char = lemma[i].toLowerCase();
          if (_dictionary.containsKey(char)) {
            sequence.add(_dictionary[char]!);
          }
        }
      }
    }

    LoggerService.debug('Generated sequence of ${sequence.length} signs');
    return sequence;
  }

  /// Basic tokenization: converts to lowercase and splits by whitespace and punctuation.
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Simplified lemmatization rules for common English word endings.
  List<String> _lemmatize(List<String> tokens) {
    return tokens.map((token) {
      // Basic rule-based lemmatization
      if (token.length <= 3) return token;

      if (token.endsWith('ing')) {
        final base = token.substring(0, token.length - 3);
        return _dictionary.containsKey(base) ? base : token;
      }
      if (token.endsWith('ed')) {
        final base = token.substring(0, token.length - 2);
        if (_dictionary.containsKey(base)) return base;
        final baseWithE = '${token.substring(0, token.length - 2)}e';
        return _dictionary.containsKey(baseWithE) ? baseWithE : token;
      }
      if (token.endsWith('s')) {
        final base = token.substring(0, token.length - 1);
        return _dictionary.containsKey(base) ? base : token;
      }

      return token;
    }).toList();
  }

  /// Searches the dictionary for signs matching a query.
  List<AslSign> searchSigns(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _dictionary.values.where((sign) => sign.word.contains(lowerQuery)).take(20).toList();
  }
}
