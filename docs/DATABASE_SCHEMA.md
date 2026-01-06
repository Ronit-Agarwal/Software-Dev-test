# Database Schema Documentation

Complete documentation for SQLite database schema used in SignSync for local data storage and caching.

## Table of Contents

- [Database Overview](#database-overview)
- [User Data Schema](#user-data-schema)
- [Face Recognition Schema](#face-recognition-schema)
- [Chat History Schema](#chat-history-schema)
- [Cached Detections Schema](#cached-detections-schema)
- [Settings and Preferences](#settings-and-preferences)
- [Performance and Optimization](#performance-and-optimization)

---

## Database Overview

### Database Configuration

**Database Name**: `signsync.db`
**Version**: 1
**Location**: 
- **Android**: `/data/data/com.signsync.app/databases/signsync.db`
- **iOS**: Application Documents directory
- **Web**: IndexedDB (via sqflite_web)

**Storage Requirements**:
- **Initial Setup**: ~50KB
- **With Chat History**: ~5-10MB
- **With Face Data**: +500KB per face
- **With Detection Cache**: ~2-5MB

### Connection Management

```dart
class DatabaseService {
  static Database? _database;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'signsync.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
}
```

### Migration Strategy

Database schema changes are handled through migrations:

```dart
static Future<void> _onCreate(Database db, int version) async {
  // Create all tables
  await db.execute(_createUserTable);
  await db.execute(_createChatHistoryTable);
  await db.execute(_createFaceDataTable);
  await db.execute(_createDetectionCacheTable);
  await db.execute(_createSettingsTable);
}

static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // Handle schema migrations
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE chat_history ADD COLUMN language TEXT');
  }
}
```

---

## User Data Schema

### Users Table

Stores basic user profile information and preferences.

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    email TEXT,
    display_name TEXT,
    preferred_language TEXT DEFAULT 'en',
    accessibility_settings TEXT, -- JSON string
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active DATETIME,
    is_anonymous BOOLEAN DEFAULT 0,
    profile_image_path TEXT,
    asl_experience_level TEXT DEFAULT 'beginner' -- beginner, intermediate, advanced
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `user_id` | TEXT | Unique user identifier (UUID) |
| `email` | TEXT | User email address (nullable) |
| `display_name` | TEXT | User's preferred display name |
| `preferred_language` | TEXT | App language preference (ISO code) |
| `accessibility_settings` | TEXT | JSON string with accessibility preferences |
| `created_at` | DATETIME | Account creation timestamp |
| `updated_at` | DATETIME | Last profile update timestamp |
| `last_active` | DATETIME | Last app usage timestamp |
| `is_anonymous` | BOOLEAN | Whether user is anonymous |
| `profile_image_path` | TEXT | Local path to profile image |
| `asl_experience_level` | TEXT | User's ASL skill level |

**Sample Data**:
```sql
INSERT INTO users (user_id, email, display_name, preferred_language, accessibility_settings) 
VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'user@example.com',
    'John Doe',
    'en',
    '{"high_contrast": true, "text_size": "large", "voice_enabled": true}'
);
```

### User Preferences Table

Stores detailed user preferences and app configuration.

```sql
CREATE TABLE user_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL, -- JSON string for complex values
    category TEXT NOT NULL, -- camera, ml, audio, ui, accessibility
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `user_id` | TEXT | Reference to users table |
| `key` | TEXT | Preference key (e.g., 'camera_resolution') |
| `value` | TEXT | Preference value (JSON for complex data) |
| `category` | TEXT | Preference category |
| `created_at` | DATETIME | Creation timestamp |
| `updated_at` | DATETIME | Last update timestamp |

**Sample Preferences**:
```sql
INSERT INTO user_preferences (user_id, key, value, category) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'camera_resolution', '"high"', 'camera'),
('550e8400-e29b-41d4-a716-446655440000', 'confidence_threshold', '0.85', 'ml'),
('550e8400-e29b-41d4-a716-446655440000', 'spatial_audio_enabled', 'true', 'audio'),
('550e8400-e29b-41d4-a716-446655440000', 'theme_mode', '"dark"', 'ui');
```

---

## Face Recognition Schema

### Face Enrollments Table

Stores enrolled faces for recognition purposes.

```sql
CREATE TABLE face_enrollments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    person_id TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    enrollment_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_recognized DATETIME,
    recognition_count INTEGER DEFAULT 0,
    confidence_threshold REAL DEFAULT 0.8,
    is_active BOOLEAN DEFAULT 1,
    metadata TEXT, -- JSON string with additional info
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `person_id` | TEXT | Unique person identifier |
| `user_id` | TEXT | Owner of this face enrollment |
| `display_name` | TEXT | Human-readable name |
| `enrollment_date` | DATETIME | When face was enrolled |
| `last_recognized` | DATETIME | Last time this face was recognized |
| `recognition_count` | INTEGER | Number of times recognized |
| `confidence_threshold` | REAL | Minimum confidence for recognition |
| `is_active` | BOOLEAN | Whether enrollment is active |
| `metadata` | TEXT | Additional enrollment metadata (JSON) |

### Face Features Table

Stores the actual face feature vectors for recognition.

```sql
CREATE TABLE face_features (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    person_id TEXT NOT NULL,
    feature_vector TEXT NOT NULL, -- JSON array of feature values
    image_width INTEGER,
    image_height INTEGER,
    enrollment_quality REAL, -- Quality score of enrollment
    feature_version TEXT DEFAULT '1.0',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES face_enrollments (person_id) ON DELETE CASCADE
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `person_id` | TEXT | Reference to face_enrollments |
| `feature_vector` | TEXT | JSON array of 128-dim or 256-dim features |
| `image_width` | INTEGER | Width of enrollment image |
| `image_height` | INTEGER | Height of enrollment image |
| `enrollment_quality` | REAL | Quality score (0.0 to 1.0) |
| `feature_version` | TEXT | Version of feature extraction model |
| `created_at` | DATETIME | When features were created |

**Sample Data**:
```sql
INSERT INTO face_enrollments (person_id, user_id, display_name, metadata) 
VALUES (
    'face_001',
    '550e8400-e29b-41d4-a716-446655440000',
    'Jane Smith',
    '{"enrollment_method": "manual", "sample_count": 5, "lighting_conditions": "good"}'
);

INSERT INTO face_features (person_id, feature_vector, enrollment_quality) 
VALUES (
    'face_001',
    '[0.123, 0.456, 0.789, ...]', -- 128 feature values
    0.92
);
```

### Face Recognition Events Table

Logs recognition events for analytics and improvement.

```sql
CREATE TABLE face_recognition_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    person_id TEXT,
    user_id TEXT NOT NULL,
    recognition_confidence REAL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    camera_context TEXT, -- front, back
    app_mode TEXT, -- translation, detection
    recognition_duration_ms INTEGER, -- Time taken for recognition
    FOREIGN KEY (person_id) REFERENCES face_enrollments (person_id),
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

---

## Chat History Schema

### Chat Conversations Table

Stores conversation sessions with the AI assistant.

```sql
CREATE TABLE chat_conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    title TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    message_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT 1,
    context_data TEXT, -- JSON string with conversation context
    language TEXT DEFAULT 'en',
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `conversation_id` | TEXT | Unique conversation identifier |
| `user_id` | TEXT | Owner of conversation |
| `title` | TEXT | Auto-generated or user-provided title |
| `created_at` | DATETIME | Conversation start time |
| `updated_at` | DATETIME | Last message time |
| `message_count` | INTEGER | Number of messages in conversation |
| `is_active` | BOOLEAN | Whether conversation is active |
| `context_data` | TEXT | Conversation context (JSON) |
| `language` | TEXT | Conversation language |

### Chat Messages Table

Stores individual messages in conversations.

```sql
CREATE TABLE chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT UNIQUE NOT NULL,
    conversation_id TEXT NOT NULL,
    role TEXT NOT NULL, -- user, assistant, system
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text', -- text, image, audio, asl_translation
    metadata TEXT, -- JSON string with message metadata
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    tokens_used INTEGER,
    model_version TEXT,
    confidence_score REAL,
    FOREIGN KEY (conversation_id) REFERENCES chat_conversations (conversation_id) ON DELETE CASCADE
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `message_id` | TEXT | Unique message identifier |
| `conversation_id` | TEXT | Reference to conversation |
| `role` | TEXT | Message sender role |
| `content` | TEXT | Message content |
| `message_type` | TEXT | Type of message content |
| `metadata` | TEXT | Additional message data (JSON) |
| `timestamp` | DATETIME | Message timestamp |
| `tokens_used` | INTEGER | Tokens consumed (for billing) |
| `model_version` | TEXT | AI model version used |
| `confidence_score` | REAL | Confidence in response |

**Sample Data**:
```sql
INSERT INTO chat_conversations (conversation_id, user_id, title, context_data) 
VALUES (
    'conv_001',
    '550e8400-e29b-41d4-a716-446655440000',
    'ASL Learning Help',
    '{"topic": "asl_basics", "experience_level": "beginner"}'
);

INSERT INTO chat_messages (message_id, conversation_id, role, content, metadata) VALUES
('msg_001', 'conv_001', 'user', 'How do I sign "hello" in ASL?', '{"language": "en"}'),
('msg_002', 'conv_001', 'assistant', 'To sign "hello" in ASL:\n\n1. Raise your hand...\n\n[detailed explanation]', '{"response_time_ms": 1250, "model": "gemini-2.5-pro"}');
```

---

## Cached Detections Schema

### Object Detection Cache Table

Caches object detection results to improve performance and reduce API calls.

```sql
CREATE TABLE object_detection_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT UNIQUE NOT NULL, -- Hash of image + settings
    detected_objects TEXT NOT NULL, -- JSON array of detected objects
    confidence_threshold REAL,
    model_version TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME,
    image_hash TEXT, -- Hash of the original image
    processing_time_ms INTEGER,
    spatial_data TEXT -- JSON with spatial information
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `cache_key` | TEXT | Unique cache identifier |
| `detected_objects` | TEXT | JSON array of detection results |
| `confidence_threshold` | REAL | Threshold used for detection |
| `model_version` | TEXT | YOLO model version |
| `created_at` | DATETIME | When cache entry was created |
| `expires_at` | DATETIME | Cache expiration time |
| `image_hash` | TEXT | Hash of source image |
| `processing_time_ms` | INTEGER | Time taken for detection |
| `spatial_data` | TEXT | Spatial information (JSON) |

### ASL Sign History Table

Stores detected ASL signs for user feedback and learning.

```sql
CREATE TABLE asl_sign_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    detected_sign TEXT NOT NULL,
    confidence_score REAL NOT NULL,
    frame_data TEXT, -- JSON with frame information
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    app_mode TEXT NOT NULL,
    translation TEXT, -- If sign was translated
    user_feedback TEXT, -- JSON with user feedback
    model_version TEXT,
    processing_time_ms INTEGER,
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `user_id` | TEXT | User who made the sign |
| `detected_sign` | TEXT | The sign that was detected |
| `confidence_score` | REAL | Confidence in detection |
| `frame_data` | TEXT | Frame information (JSON) |
| `timestamp` | DATETIME | When sign was detected |
| `app_mode` | TEXT | App mode during detection |
| `translation` | TEXT | Translated text (if applicable) |
| `user_feedback` | TEXT | User feedback data (JSON) |
| `model_version` | TEXT | CNN/LSTM model version |
| `processing_time_ms` | INTEGER | Time taken for detection |

### Performance Metrics Table

Stores app performance metrics for optimization.

```sql
CREATE TABLE performance_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    metric_type TEXT NOT NULL, -- inference_time, memory_usage, battery_usage
    metric_value REAL NOT NULL,
    unit TEXT NOT NULL, -- ms, MB, percentage
    context TEXT, -- JSON with additional context
    device_info TEXT, -- JSON with device information
    app_version TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

---

## Settings and Preferences

### App Settings Table

Stores global app settings and configuration.

```sql
CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    data_type TEXT NOT NULL, -- string, integer, float, boolean, json
    category TEXT NOT NULL, -- system, ml, camera, audio, accessibility
    is_encrypted BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key, auto-increment |
| `setting_key` | TEXT | Unique setting identifier |
| `setting_value` | TEXT | Setting value |
| `data_type` | TEXT | Data type of the setting |
| `category` | TEXT | Setting category |
| `is_encrypted` | BOOLEAN | Whether value is encrypted |
| `created_at` | DATETIME | Setting creation time |
| `updated_at` | DATETIME | Last update time |
| `description` | TEXT | Setting description |

**Sample Settings**:
```sql
INSERT INTO app_settings (setting_key, setting_value, data_type, category, description) VALUES
('app_theme', '"dark"', 'string', 'ui', 'App theme preference'),
('camera_resolution', '"high"', 'string', 'camera', 'Camera resolution setting'),
('ml_confidence_threshold', '0.85', 'float', 'ml', 'Minimum confidence for ML predictions'),
('spatial_audio_enabled', 'true', 'boolean', 'audio', 'Enable spatial audio features'),
('accessibility_high_contrast', 'false', 'boolean', 'accessibility', 'High contrast mode');
```

### Model Information Table

Stores information about loaded ML models.

```sql
CREATE TABLE model_information (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_type TEXT NOT NULL, -- cnn, lstm, yolo
    model_version TEXT NOT NULL,
    model_path TEXT NOT NULL,
    model_size_bytes INTEGER,
    accuracy_score REAL,
    performance_metrics TEXT, -- JSON with performance data
    is_active BOOLEAN DEFAULT 1,
    last_used DATETIME,
    usage_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## Performance and Optimization

### Database Indexes

Proper indexing for optimal query performance:

```sql
-- Users table indexes
CREATE INDEX idx_users_user_id ON users(user_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_last_active ON users(last_active);

-- Face recognition indexes
CREATE INDEX idx_face_enrollments_person_id ON face_enrollments(person_id);
CREATE INDEX idx_face_enrollments_user_id ON face_enrollments(user_id);
CREATE INDEX idx_face_features_person_id ON face_features(person_id);

-- Chat history indexes
CREATE INDEX idx_chat_conversations_conversation_id ON chat_conversations(conversation_id);
CREATE INDEX idx_chat_conversations_user_id ON chat_conversations(user_id);
CREATE INDEX idx_chat_messages_conversation_id ON chat_messages(conversation_id);
CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp);

-- Detection cache indexes
CREATE INDEX idx_object_detection_cache_key ON object_detection_cache(cache_key);
CREATE INDEX idx_object_detection_cache_expires ON object_detection_cache(expires_at);
CREATE INDEX idx_asl_sign_history_user_id ON asl_sign_history(user_id);
CREATE INDEX idx_asl_sign_history_timestamp ON asl_sign_history(timestamp);

-- Performance indexes
CREATE INDEX idx_performance_metrics_type ON performance_metrics(metric_type);
CREATE INDEX idx_performance_metrics_timestamp ON performance_metrics(timestamp);
```

### Data Retention Policies

**Automatic Cleanup**:

```sql
-- Delete expired cache entries
DELETE FROM object_detection_cache WHERE expires_at < datetime('now');

-- Delete old performance metrics (keep 30 days)
DELETE FROM performance_metrics 
WHERE timestamp < datetime('now', '-30 days') 
AND metric_type != 'error_rate';

-- Archive old chat messages (keep 1 year)
DELETE FROM chat_messages 
WHERE timestamp < datetime('now', '-365 days') 
AND message_type = 'text';
```

### Backup and Recovery

**Data Export**:
```dart
class DatabaseBackup {
  static Future<void> exportUserData(String userId) async {
    final db = await DatabaseService.database;
    
    // Export user profile
    final userData = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    // Export chat history
    final chatData = await db.query(
      'chat_messages',
      where: 'conversation_id IN (SELECT conversation_id FROM chat_conversations WHERE user_id = ?)',
      whereArgs: [userId],
    );
    
    // Export preferences
    final preferences = await db.query(
      'user_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    // Create backup file
    final backup = {
      'user': userData,
      'chat_messages': chatData,
      'preferences': preferences,
      'export_timestamp': DateTime.now().toIso8601String(),
    };
    
    // Save to file or cloud storage
    await _saveBackupFile(backup);
  }
}
```

### Privacy and Security

**Data Encryption**:
```dart
class SecureStorage {
  static const _encryptionKey = 'your-encryption-key';
  
  static Future<void> encryptSensitiveData() async {
    final db = await DatabaseService.database;
    
    // Encrypt face feature data
    await db.update(
      'face_features',
      {'feature_vector': _encrypt(_getFaceVector())},
      where: 'person_id = ?',
      whereArgs: [personId],
    );
    
    // Encrypt personal settings
    await db.update(
      'user_preferences',
      {'value': _encrypt(jsonEncode(userSettings))},
      where: 'user_id = ? AND key IN (?, ?, ?)',
      whereArgs: [userId, 'email', 'phone', 'address'],
    );
  }
}
```

### Migration Examples

**Adding New Columns**:
```sql
-- Add language support to conversations
ALTER TABLE chat_conversations ADD COLUMN language TEXT DEFAULT 'en';

-- Add model version tracking
ALTER TABLE asl_sign_history ADD COLUMN model_version TEXT;

-- Add spatial audio preferences
ALTER TABLE user_preferences ADD COLUMN is_spatial_enabled BOOLEAN DEFAULT true;
```

**Creating New Tables**:
```sql
-- Add voice command history
CREATE TABLE voice_commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    command_text TEXT NOT NULL,
    confidence_score REAL,
    execution_result TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
```

This comprehensive database schema provides a robust foundation for SignSync's data storage needs while maintaining performance, security, and privacy standards.