# LSTM Model Setup for ASL Temporal Recognition

This guide explains how to convert and deploy LSTM models for temporal ASL sign recognition in SignSync.

## Overview

The LSTM model processes sequences of CNN features to recognize dynamic ASL signs like "morning", "computer", "thank you", etc. It works in conjunction with the CNN service for spatial feature extraction.

## Model Architecture Requirements

### Input Specifications
- **Shape**: `[1, 15, 512]` (batch_size=1, sequence_length=15, feature_dims=512)
- **Data Type**: Float32
- **Content**: CNN-extracted features from sequential frames

### Output Specifications
- **Shape**: `[1, 20]` (batch_size=1, num_classes=20)
- **Data Type**: Float32
- **Content**: Probabilities for 20 ASL dynamic signs

### Supported Dynamic Signs
1. MORNING - Good morning
2. NIGHT - Good night  
3. COMPUTER - Computer/work
4. WATER - Water/drink
5. EAT - Eat/food
6. HELLO - Formal greeting
7. THANKYOU - Thank you
8. YES - Yes/nodding
9. NO - No/shaking head
10. QUESTION - Question mark gesture
11. TIME - Time/clock
12. DAY - Day/time
13. LEARN - Learning/studying
14. HOME - Home/house
15. WORK - Work/job
16. LOVE - I love you
17. SICK - Sick/ill
18. BATHROOM - Bathroom/washroom
19. CALL - Phone call
20. UNKNOWN - Unknown/background

## Model Conversion Process

### Step 1: Prepare Training Data

Create sequences of CNN features with labels:

```python
import numpy as np
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam

# Example data preparation
def prepare_sequences(cnn_features_list, labels, sequence_length=15):
    sequences = []
    sequence_labels = []
    
    for i in range(len(cnn_features_list) - sequence_length + 1):
        sequence = cnn_features_list[i:i + sequence_length]
        label = labels[i + sequence_length - 1]
        sequences.append(sequence)
        sequence_labels.append(label)
    
    return np.array(sequences), np.array(sequence_labels)

# Load your CNN features (512-dimensional vectors)
# This would come from your trained CNN model's intermediate layer
cnn_features = load_cnn_features('path/to/features.npy')
labels = load_labels('path/to/labels.npy')

X, y = prepare_sequences(cnn_features, labels)
```

### Step 2: Build LSTM Model

```python
def create_asl_lstm_model(sequence_length=15, feature_dims=512, num_classes=20):
    model = Sequential([
        LSTM(256, return_sequences=True, input_shape=(sequence_length, feature_dims)),
        Dropout(0.3),
        LSTM(128, return_sequences=False),
        Dropout(0.3),
        Dense(64, activation='relu'),
        Dropout(0.2),
        Dense(num_classes, activation='softmax')
    ])
    
    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

# Create and train model
model = create_asl_lstm_model()
model.fit(X, y, epochs=50, validation_split=0.2, batch_size=32)
```

### Step 3: Convert to TensorFlow Lite

```python
import tensorflow as tf

# Convert to TFLite with quantization for better performance
def convert_to_tflite(model, output_path='asl_lstm.tflite'):
    # Convert model
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Enable quantization for better performance on mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Convert
    tflite_model = converter.convert()
    
    # Save model
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"LSTM model converted and saved to {output_path}")
    return tflite_model

# Convert the model
convert_to_tflite(model, 'assets/models/asl_lstm.tflite')
```

### Step 4: Test TFLite Model

```python
import tensorflow.lite as tflite

# Test the converted model
interpreter = tflite.Interpreter(model_path='asl_lstm.tflite')
interpreter.allocate_tensors()

# Get input/output details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input shape:", input_details[0]['shape'])
print("Output shape:", output_details[0]['shape'])

# Test with dummy data
test_input = np.random.random((1, 15, 512)).astype(np.float32)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()
output = interpreter.get_tensor(output_details[0]['index'])

print("Test output shape:", output.shape)
print("Predicted class:", np.argmax(output))
```

## Deployment in SignSync

### 1. Place Model File

Copy the converted model to your assets:
```bash
cp asl_lstm.tflite /path/to/signsync/assets/models/
```

### 2. Initialize LSTM Service

```dart
final lstmService = LstmInferenceService();
await lstmService.initialize(
  lstmModelPath: 'assets/models/asl_lstm.tflite',
  cnnModelPath: 'assets/models/asl_cnn.tflite',
);
```

### 3. Process Frames

```dart
// The service automatically handles temporal buffering
final sign = await lstmService.processFrame(cameraImage);
if (sign != null) {
  print('Detected dynamic sign: ${sign.word}');
}
```

## Performance Optimization

### Model Quantization
- Use INT8 quantization for 4x smaller models
- FP16 for balance between size and accuracy
- Dynamic range quantization for quickest conversion

### Inference Optimization
- Enable XNNPACK delegate for CPU optimization
- Use GPU delegate if available on device
- Thread count: 2-4 threads optimal

### Memory Management
- Clear frame buffer periodically to prevent memory leaks
- Use lazy loading to reduce startup time
- Dispose models when switching modes

## Troubleshooting

### Common Issues

**"LSTM model file not found"**
- Ensure model file exists in `assets/models/asl_lstm.tflite`
- Check pubspec.yaml includes assets directory
- Run `flutter clean && flutter pub get`

**"Invalid input shape"**
- Verify model expects [1, 15, 512] input shape
- Check feature extraction generates 512-dimensional vectors
- Ensure proper sequence padding

**"Low accuracy"**
- Increase training data for underrepresented signs
- Adjust confidence threshold (default 0.80)
- Check for class imbalance in training data
- Validate CNN feature quality

**Memory issues**
- Reduce sequence length if needed
- Clear frame buffer regularly
- Use model quantization
- Enable GPU delegate if available

### Performance Monitoring

Monitor these metrics:
- **Inference time**: Should be <100ms for real-time performance
- **Frame buffer size**: Monitor memory usage
- **Accuracy**: Track per-class performance
- **False positive rate**: Validate sign transitions

## Integration with CNN

The LSTM service automatically:
1. Extracts features from CNN results
2. Maintains 15-frame temporal buffer
3. Applies temporal validation
4. Runs inference when sequence is valid
5. Returns dynamic sign predictions

See `CnnInferenceService` for CNN integration details.

## Testing

Run the LSTM test suite:
```bash
flutter test test/lstm_inference_test.dart
```

Test with real camera feed:
```dart
// Example integration test
final lstmService = LstmInferenceService();
await lstmService.initialize();

// Simulate sign sequence
for (int i = 0; i < 20; i++) {
  final sign = await lstmService.processFrame(mockCameraImage);
  if (sign != null) {
    print('Detected: ${sign.word}');
  }
}
```

## Model Versioning

Keep track of:
- Model version and training date
- Training dataset details
- Performance metrics
- Conversion parameters

Update the service with new models by replacing the file and updating version constants.