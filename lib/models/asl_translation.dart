import 'package:equatable/equatable.dart';

class AslDictionaryEntry with EquatableMixin {
  final String gloss;
  final String lemma;

  const AslDictionaryEntry({
    required this.gloss,
    required this.lemma,
  });

  factory AslDictionaryEntry.fromJson(Map<String, dynamic> json) {
    return AslDictionaryEntry(
      gloss: (json['gloss'] as String?) ?? 'UNKNOWN',
      lemma: (json['lemma'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => [gloss, lemma];
}

class AslTranslationResult with EquatableMixin {
  final String input;
  final List<String> tokens;
  final List<String> glosses;
  final List<String> unknownTokens;

  const AslTranslationResult({
    required this.input,
    required this.tokens,
    required this.glosses,
    required this.unknownTokens,
  });

  @override
  List<Object?> get props => [input, tokens, glosses, unknownTokens];
}
