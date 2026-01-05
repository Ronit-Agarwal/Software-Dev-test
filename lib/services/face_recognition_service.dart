import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service for face detection and recognition.
///
/// Handles face enrollment, real-time identification, and user database.
class FaceRecognitionService with ChangeNotifier {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  
  // Face database
  final Map<String, FaceProfile> _faceDatabase = {};
  final String _dbFileName = 'face_database.json';
  
  // Enrollment state
  bool _isEnrolling = false;
  String? _enrollingName;
  List<Float32List> _enrolledTemplates = [];
  static const int maxEnrollmentImages = 5;

  // Configuration
  static const int inputSize = 112; // Typical for MobileNetV2/FaceNet
  static const double recognitionThreshold = 0.75;
  bool _recognitionEnabled = true;

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  bool get isProcessing => _isProcessing;
  bool get isEnrolling => _isEnrolling;
  String? get enrollingName => _enrollingName;
  int get enrollmentProgress => _enrolledTemplates.length;
  List<FaceProfile> get profiles => _faceDatabase.values.toList();
  bool get recognitionEnabled => _recognitionEnabled;

  /// Initializes the face recognition service.
  Future<void> initialize({String modelPath = 'assets/models/face_recognition.tflite'}) async {
    try {
      LoggerService.info('Initializing Face Recognition service');
      
      // Load the model (placeholder as we don't have the actual file)
      // In a real app, we'd use: _interpreter = await Interpreter.fromAsset(modelPath);
      
      await _loadDatabase();
      _isModelLoaded = true;
      notifyListeners();
      LoggerService.info('Face Recognition service initialized (simulated)');
    } catch (e, stack) {
      LoggerService.error('Face Recognition initialization failed', error: e, stack: stack);
    }
  }

  /// Sets recognition enabled/disabled.
  void setRecognitionEnabled(bool enabled) {
    _recognitionEnabled = enabled;
    notifyListeners();
  }

  /// Starts the enrollment process for a new person.
  void startEnrollment(String name) {
    _isEnrolling = true;
    _enrollingName = name;
    _enrolledTemplates = [];
    notifyListeners();
  }

  /// Cancels the current enrollment.
  void cancelEnrollment() {
    _isEnrolling = false;
    _enrollingName = null;
    _enrolledTemplates.clear();
    notifyListeners();
  }

  /// Processes a frame for identification or enrollment.
  Future<FaceResult?> processFrame(CameraImage image, {Rect? faceRect, List<Rect>? allFaces}) async {
    if (!_isModelLoaded || !_recognitionEnabled) return null;
    if (_isProcessing) return null;

    // Check for multiple faces - handle the first one with highest confidence
    if (allFaces != null && allFaces.length > 1) {
      LoggerService.info('Multiple faces detected (${allFaces.length}), processing first face');
    }

    // Check lighting conditions using Y-plane brightness
    if (faceRect != null) {
      final brightness = _calculateBrightness(image, faceRect);
      if (brightness < 50.0) {
        LoggerService.warn('Poor lighting conditions detected for face recognition (brightness: $brightness)');
        // Could return null or use a lower confidence threshold
      }
    }

    _isProcessing = true;
    try {
      // 1. Preprocess and extract face embedding
      // In a real app: 
      // final faceImage = _cropFace(image, faceRect);
      // final embedding = _extractEmbedding(faceImage);
      
      // Simulated embedding (for demonstration)
      final embedding = Float32List(128); 
      
      if (_isEnrolling) {
        return await _handleEnrollment(embedding);
      } else {
        return _identifyFace(embedding);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Calculates brightness from camera frame for face region.
  double _calculateBrightness(CameraImage image, Rect faceRect) {
    try {
      final yPlane = image.planes[0].bytes;
      final stride = image.planes[0].bytesPerRow;
      
      // Sample pixels in the face region
      var totalBrightness = 0;
      var sampleCount = 0;
      
      final startX = (faceRect.left * image.width).toInt().clamp(0, image.width - 1);
      final startY = (faceRect.top * image.height).toInt().clamp(0, image.height - 1);
      final endX = (faceRect.right * image.width).toInt().clamp(0, image.width - 1);
      final endY = (faceRect.bottom * image.height).toInt().clamp(0, image.height - 1);
      
      for (var y = startY; y < endY; y += 10) {
        for (var x = startX; x < endX; x += 10) {
          final idx = y * stride + x;
          if (idx < yPlane.length) {
            totalBrightness += yPlane[idx];
            sampleCount++;
          }
        }
      }
      
      return sampleCount > 0 ? totalBrightness / sampleCount : 0.0;
    } catch (e) {
      LoggerService.warn('Failed to calculate brightness: $e');
      return 0.0;
    }
  }

  /// Handles adding an embedding to the current enrollment.
  Future<FaceResult?> _handleEnrollment(Float32List embedding) async {
    _enrolledTemplates.add(embedding);
    notifyListeners();

    if (_enrolledTemplates.length >= maxEnrollmentImages) {
      // Enrollment complete - average the templates for a more robust profile
      final averageTemplate = _calculateAverageTemplate(_enrolledTemplates);
      final profile = FaceProfile(
        id: Guid.newGuid(),
        name: _enrollingName!,
        template: averageTemplate,
        label: 'friend', // Default label
        isPrivate: false,
      );
      
      _faceDatabase[profile.id] = profile;
      await _saveDatabase();
      
      final result = FaceResult(
        profile: profile,
        confidence: 1.0,
        isNewEnrollment: true,
      );
      
      _isEnrolling = false;
      _enrollingName = null;
      _enrolledTemplates.clear();
      notifyListeners();
      return result;
    }
    return null;
  }

  /// Identifies a face by comparing its embedding with the database.
  FaceResult? _identifyFace(Float32List embedding) {
    FaceProfile? bestMatch;
    double maxSimilarity = -1.0;

    for (final profile in _faceDatabase.values) {
      if (profile.isPrivate) continue;

      final similarity = _cosineSimilarity(embedding, profile.template);
      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        bestMatch = profile;
      }
    }

    if (maxSimilarity >= recognitionThreshold && bestMatch != null) {
      return FaceResult(
        profile: bestMatch,
        confidence: maxSimilarity,
      );
    }

    return null;
  }

  /// Calculates cosine similarity between two vectors.
  double _cosineSimilarity(Float32List a, Float32List b) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Averages multiple templates for enrollment.
  Float32List _calculateAverageTemplate(List<Float32List> templates) {
    if (templates.isEmpty) return Float32List(0);
    final length = templates[0].length;
    final average = Float32List(length);
    for (int i = 0; i < length; i++) {
      double sum = 0;
      for (final t in templates) {
        sum += t[i];
      }
      average[i] = sum / templates.length;
    }
    return average;
  }

  /// Loads the face database from local storage.
  Future<void> _loadDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_dbFileName');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        for (final item in jsonList) {
          final profile = FaceProfile.fromJson(item);
          _faceDatabase[profile.id] = profile;
        }
      }
    } catch (e) {
      LoggerService.error('Failed to load face database', error: e);
    }
  }

  /// Saves the face database to local storage.
  Future<void> _saveDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_dbFileName');
      final jsonList = _faceDatabase.values.map((p) => p.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      LoggerService.error('Failed to save face database', error: e);
    }
  }

  /// Updates a profile's label or privacy status.
  Future<void> updateProfile(String id, {String? label, bool? isPrivate}) async {
    if (_faceDatabase.containsKey(id)) {
      final profile = _faceDatabase[id]!;
      _faceDatabase[id] = FaceProfile(
        id: profile.id,
        name: profile.name,
        template: profile.template,
        label: label ?? profile.label,
        isPrivate: isPrivate ?? profile.isPrivate,
      );
      await _saveDatabase();
      notifyListeners();
    }
  }

  /// Deletes a profile from the database.
  Future<void> deleteProfile(String id) async {
    if (_faceDatabase.containsKey(id)) {
      _faceDatabase.remove(id);
      await _saveDatabase();
      notifyListeners();
    }
  }

  /// Unloads the model.
  Future<void> unloadModel() async {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}

/// Profile information for an enrolled face.
class FaceProfile {
  final String id;
  final String name;
  final Float32List template;
  final String label; // family, friend, coworker
  final bool isPrivate;

  FaceProfile({
    required this.id,
    required this.name,
    required this.template,
    required this.label,
    required this.isPrivate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'template': template.toList(),
    'label': label,
    'isPrivate': isPrivate,
  };

  factory FaceProfile.fromJson(Map<String, dynamic> json) => FaceProfile(
    id: json['id'],
    name: json['name'],
    template: Float32List.fromList(List<double>.from(json['template'])),
    label: json['label'],
    isPrivate: json['isPrivate'],
  );
}

/// Result of a face recognition inference.
class FaceResult {
  final FaceProfile profile;
  final double confidence;
  final bool isNewEnrollment;

  FaceResult({
    required this.profile,
    required this.confidence,
    this.isNewEnrollment = false,
  });

  @override
  String toString() => 'FaceResult(name: ${profile.name}, conf: $confidence)';
}

/// Helper for generating GUIDs.
class Guid {
  static String newGuid() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return sha1.convert(bytes).toString();
  }
}
