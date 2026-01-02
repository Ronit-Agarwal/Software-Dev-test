import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Represents an American Sign Language (ASL) gesture/sign.
///
/// This model contains all information about a recognized ASL sign
/// including its textual representation, confidence score, and metadata.
@immutable
class AslSign with EquatableMixin {
  final String id;
  final String letter;
  final String word;
  final String description;
  final double confidence;
  final Duration? duration;
  final String? imageUrl;
  final List<String> synonyms;
  final String category;
  final DateTime timestamp;

  const AslSign({
    required this.id,
    required this.letter,
    required this.word,
    required this.description,
    required this.confidence,
    this.duration,
    this.imageUrl,
    this.synonyms = const [],
    this.category = 'unknown',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a sign from letter only (for single letter signs).
  factory AslSign.fromLetter(String letter, {double confidence = 1.0}) {
    return AslSign(
      id: 'letter_$letter',
      letter: letter,
      word: letter,
      description: 'ASL sign for letter $letter',
      confidence: confidence,
      category: 'letter',
    );
  }

  /// Creates a sign from a word (for word-based signs).
  factory AslSign.fromWord(
    String word, {
    double confidence = 1.0,
    String description = '',
  }) {
    return AslSign(
      id: 'word_${word.toLowerCase().replaceAll(' ', '_')}',
      letter: '',
      word: word.toLowerCase(),
      description: description.isNotEmpty
          ? description
          : 'ASL sign for "$word"',
      confidence: confidence,
      category: 'word',
    );
  }

  /// Gets the localized word for the sign.
  String getLocalizedWord(Locale locale) {
    // This is a placeholder for language-specific sign mappings.
    // In a real app, this would use a translation table or API.
    if (locale.languageCode == 'es') {
      if (word.toLowerCase() == 'hello') return 'hola';
      if (word.toLowerCase() == 'thank you') return 'gracias';
    } else if (locale.languageCode == 'fr') {
      if (word.toLowerCase() == 'hello') return 'bonjour';
      if (word.toLowerCase() == 'thank you') return 'merci';
    }
    return word;
  }

  @override
  List<Object?> get props => [
        id,
        letter,
        word,
        description,
        confidence,
        duration,
        imageUrl,
        synonyms,
        category,
        timestamp,
      ];

  AslSign copyWith({
    String? id,
    String? letter,
    String? word,
    String? description,
    double? confidence,
    Duration? duration,
    String? imageUrl,
    List<String>? synonyms,
    String? category,
    DateTime? timestamp,
  }) {
    return AslSign(
      id: id ?? this.id,
      letter: letter ?? this.letter,
      word: word ?? this.word,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      duration: duration ?? this.duration,
      imageUrl: imageUrl ?? this.imageUrl,
      synonyms: synonyms ?? this.synonyms,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'AslSign(letter: $letter, word: $word, confidence: ${confidence.toStringAsFixed(2)})';
  }
}

/// Represents a sequence of signs that form a sentence or phrase.
///
/// This is used to combine multiple recognized signs into coherent output.
@immutable
class SignSequence with EquatableMixin {
  final String id;
  final List<AslSign> signs;
  final String text;
  final DateTime startTime;
  final DateTime? endTime;
  final double averageConfidence;

  const SignSequence({
    required this.id,
    required this.signs,
    required this.text,
    required this.startTime,
    this.endTime,
    DateTime? timestamp,
  }) : averageConfidence = signs.isEmpty
      ? 0.0
      : signs.map((s) => s.confidence).reduce((a, b) => a + b) / signs.length;

  /// Returns true if this sequence is empty.
  bool get isEmpty => signs.isEmpty;

  /// Returns the number of signs in this sequence.
  int get length => signs.length;

  @override
  List<Object?> get props => [id, signs, text, startTime, endTime, averageConfidence];

  @override
  String toString() {
    return 'SignSequence(text: "$text", signs: ${signs.length}, avgConfidence: ${averageConfidence.toStringAsFixed(2)})';
  }
}

/// Represents the result of sign translation.
class TranslationResult with EquatableMixin {
  final SignSequence? sequence;
  final String partialText;
  final String? error;
  final bool isProcessing;
  final DateTime timestamp;

  const TranslationResult({
    this.sequence,
    this.partialText = '',
    this.error,
    this.isProcessing = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a result for ongoing processing.
  factory TranslationResult.processing({String partialText = ''}) {
    return TranslationResult(
      partialText: partialText,
      isProcessing: true,
    );
  }

  /// Creates a result for an error.
  factory TranslationResult.error(String error) {
    return TranslationResult(error: error);
  }

  /// Creates a successful translation result.
  factory TranslationResult.success(SignSequence sequence) {
    return TranslationResult(sequence: sequence);
  }

  @override
  List<Object?> get props => [sequence, partialText, error, isProcessing, timestamp];

  TranslationResult copyWith({
    SignSequence? sequence,
    String? partialText,
    String? error,
    bool? isProcessing,
    DateTime? timestamp,
  }) {
    return TranslationResult(
      sequence: sequence ?? this.sequence,
      partialText: partialText ?? this.partialText,
      error: error ?? this.error,
      isProcessing: isProcessing ?? this.isProcessing,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
