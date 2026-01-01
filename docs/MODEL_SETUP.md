# ASL Sign Recognition Model Setup

This document describes how to set up the ResNet-50 CNN model for ASL static sign recognition.

## Overview

The ASL static sign recognition uses a **ResNet-50 CNN** with the following specifications:

- **Architecture**: ResNet-50 (50 layers deep)
- **Input**: 224x224x3 RGB images
- **Output**: 27 classes (26 letters A-Z + UNKNOWN)
- **Quantization**: FP16 (half-precision floating point)
- **Inference Speed**: 15-20 FPS with <100ms latency
- **Confidence Threshold**: 0.85 (85%)

## Model Conversion

### Prerequisites

```bash
pip install tensorflow==2.13.0
pip install tf-nightly  # For latest TFLite converter
```

### Step 1: Train or Download Pre-trained Model

**Option A: Use Pre-trained ResNet-50**

```python
import tensorflow as tf
from tensorflow.keras.applications import ResNet50

# Load pre-trained ResNet-50 without top layers
base_model = ResNet50(
    weights='imagenet',
    include_top=False,
    input_shape=(224, 224, 3)
)

# Add custom classification head for 27 classes
x = base_model.output
x = tf.keras.layers.GlobalAveragePooling2D()(x)
x = tf.keras.layers.Dropout(0.5)(x)
x = tf.keras.layers.Dense(512, activation='relu')(x)
x = tf.keras.layers.Dense(27, activation='softmax')(x)

model = tf.keras.Model(inputs=base_model.input, outputs=x)

# Freeze base layers initially
for layer in base_model.layers:
    layer.trainable = False
```

**Option B: Train from Scratch**

```python
# Define dataset path (ASL alphabet images)
train_dir = 'path/to/asl_alphabet_dataset/train'
val_dir = 'path/to/asl_alphabet_dataset/val'

# Data augmentation and preprocessing
train_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
    rescale=1./255,
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    horizontal_flip=False,  # Don't flip ASL signs
    zoom_range=0.2,
    fill_mode='nearest'
)

train_generator = train_datagen.flow_from_directory(
    train_dir,
    target_size=(224, 224),
    batch_size=32,
    class_mode='categorical'
)

# Compile and train
model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.0001),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

model.fit(
    train_generator,
    epochs=50,
    validation_data=val_generator,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10),
        tf.keras.callbacks.ModelCheckpoint('best_model.h5', save_best_only=True)
    ]
)
```

### Step 2: Convert to TFLite with FP16 Quantization

```python
import tensorflow as tf

# Load the trained model
model = tf.keras.models.load_model('best_model.h5')

# Convert to TFLite with FP16 quantization
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Enable FP16 quantization
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

# Convert the model
tflite_model = converter.convert()

# Save the model
with open('asl_cnn.tflite', 'wb') as f:
    f.write(tflite_model)

print("Model converted successfully!")
```

### Step 3: Verify Model

```python
# Load and verify the TFLite model
interpreter = tf.lite.Interpreter(model_path='asl_cnn.tflite')
interpreter.allocate_tensors()

# Check input/output details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input shape:", input_details[0]['shape'])
print("Input type:", input_details[0]['dtype'])
print("Output shape:", output_details[0]['shape'])
print("Output type:", output_details[0]['dtype'])

# Expected output:
# Input shape: [1, 224, 224, 3]
# Input type: float16
# Output shape: [1, 27]
# Output type: float16
```

## Model Deployment

### Step 4: Add to Flutter Assets

1. Create the assets directory structure:
   ```
   assets/
   └── models/
       └── asl_cnn.tflite
   ```

2. Add the model file to `assets/models/` directory

3. Ensure `assets/models/` is listed in `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/models/
   ```

### Step 5: Model Specifications

The model file should have the following characteristics:

- **File size**: ~100-150 MB (FP16 quantized ResNet-50)
- **Input tensor**: [1, 224, 224, 3] (batch, height, width, channels)
- **Output tensor**: [1, 27] (batch, num_classes)
- **Data type**: Float16
- **Normalization**: ImageNet mean/std (handled in preprocessing)

### Step 6: Preprocessing

The CNN service handles the following preprocessing steps automatically:

1. **YUV420→RGB Conversion**: Camera frames are in YUV420 format
2. **Resize**: Frames are resized to 224x224 pixels
3. **Normalization**: ImageNet normalization applied
   - Mean: [0.485, 0.456, 0.406] (R, G, B)
   - Std: [0.229, 0.224, 0.225] (R, G, B)
4. **Type conversion**: Convert to Float32List for TFLite input

This is handled in `CnnInferenceService._preprocessImageIsolate()`.

## Model Training Dataset

### Recommended Datasets

1. **Kaggle ASL Alphabet Dataset**
   - 87,000 images
   - 26 classes (A-Z)
   - Various backgrounds and lighting conditions

2. **Roboflow ASL Alphabet**
   - Real-world hand images
   - Multiple hand positions
   - Balanced classes

### Dataset Requirements

- **Minimum images per class**: 3,000-5,000
- **Resolution**: 224x224 or higher
- **Format**: PNG or JPG
- **Variations**:
  - Different skin tones
  - Various lighting conditions
  - Multiple hand positions/angles
  - Different backgrounds

## Performance Optimization

### Current Implementation

The CNN inference service includes:

- **Lazy Loading**: Model loads on first inference request
- **Isolate Processing**: Preprocessing runs in background isolate
- **Temporal Smoothing**: 3-5 frame window to reduce jitter
- **Confidence Filtering**: 0.85 threshold to reduce false positives
- **FPS Targeting**: 15-20 FPS with <100ms latency

### Further Optimization (Optional)

1. **Model Pruning**: Remove less important weights
   ```python
   prune_low_magnitude = tfmot.sparsity.keras.prune_low_magnitude

   pruning_params = {
       'pruning_schedule': tfmot.sparsity.keras.ConstantSparsity(
           0.5, begin_step=0, frequency=100
       )
   }

   model_for_pruning = prune_low_magnitude(model, **pruning_params)
   ```

2. **Model Quantization-aware Training**: Train with quantization in mind
   ```python
   converter.optimizations = [tf.lite.Optimize.DEFAULT]
   converter.target_spec.supported_types = [tf.float16]
   converter.experimental_new_quantizer = True
   ```

3. **Edge TPU Optimization**: For devices with Edge TPU
   ```bash
   pip install edgetpu_compiler
   edgetpu_compiler asl_cnn.tflite -o asl_cnn_edgetpu.tflite
   ```

## Testing the Model

### Unit Tests

```python
import tensorflow as tf
import numpy as np

# Load model
interpreter = tf.lite.Interpreter(model_path='asl_cnn.tflite')
interpreter.allocate_tensors()

# Create test input
test_image = np.random.rand(1, 224, 224, 3).astype(np.float16)

# Run inference
interpreter.set_tensor(interpreter.get_input_details()[0]['index'], test_image)
interpreter.invoke()

# Get output
output = interpreter.get_tensor(interpreter.get_output_details()[0]['index'])

# Check output shape and values
assert output.shape == (1, 27), "Output shape mismatch"
assert np.allclose(np.sum(output), 1.0, atol=0.01), "Probabilities should sum to 1"

print("Model test passed!")
```

### Integration Testing

The Flutter app includes automatic testing:

- Model loading verification
- Inference performance checks
- Confidence threshold validation
- Temporal smoothing behavior

## Troubleshooting

### Issue: Model not loading

**Solution**: Ensure the model file is in `assets/models/` and listed in `pubspec.yaml`.

### Issue: Low FPS (< 15)

**Possible causes**:
1. Device is too slow - model will automatically reduce quality
2. Camera resolution too high - reduce camera resolution
3. Background processes consuming CPU

**Solution**: Check device performance metrics in the CNN service.

### Issue: Low accuracy

**Possible causes**:
1. Model not trained on diverse dataset
2. Poor lighting conditions
3. Hand not centered in frame

**Solution**:
1. Retrain with more diverse data
2. Improve lighting
3. Add hand detection/bounding box preprocessing

### Issue: High latency (> 100ms)

**Solution**:
1. Reduce model complexity (use MobileNet instead of ResNet-50)
2. Use TFLite GPU delegate (requires device with GPU)
3. Optimize preprocessing pipeline

## References

- [TensorFlow Lite Guide](https://www.tensorflow.org/lite/guide)
- [ResNet Paper](https://arxiv.org/abs/1512.03385)
- [TFLite Model Optimization](https://www.tensorflow.org/lite/performance/model_optimization)
- [ASL Datasets](https://www.kaggle.com/datasets/grassknoted/asl-alphabet)

## Next Steps

After setting up the CNN model:

1. **Test Model**: Run the app and verify sign recognition accuracy
2. **Fine-tune**: Adjust confidence threshold and temporal smoothing window
3. **Optimize**: Further optimize for specific device targets
4. **LSTM Integration**: The CNN output feeds into the LSTM for dynamic sign recognition (Task 4)
