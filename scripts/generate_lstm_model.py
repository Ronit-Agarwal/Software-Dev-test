#!/usr/bin/env python3
"""
LSTM Model Generator for ASL Temporal Recognition

This script creates a demo LSTM model for testing the temporal ASL recognition pipeline.
In production, you would replace this with your trained model.

Usage:
    python generate_lstm_model.py

Requirements:
    tensorflow==2.13.0
    numpy==1.24.0
"""

import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam
import os

def create_demo_lstm_model(
    sequence_length=15,
    feature_dims=512,
    num_classes=20,
    output_path='asl_lstm_demo.tflite'
):
    """
    Creates a demo LSTM model for ASL temporal recognition.
    
    This is a simplified model for demonstration purposes.
    In production, you would train this on real ASL sequence data.
    """
    print(f"Creating demo LSTM model...")
    print(f"  Sequence length: {sequence_length}")
    print(f"  Feature dimensions: {feature_dims}")
    print(f"  Number of classes: {num_classes}")
    
    # Build LSTM architecture
    model = Sequential([
        LSTM(256, return_sequences=True, input_shape=(sequence_length, feature_dims)),
        Dropout(0.3),
        LSTM(128, return_sequences=False),
        Dropout(0.3),
        Dense(64, activation='relu'),
        Dropout(0.2),
        Dense(num_classes, activation='softmax')
    ])
    
    # Compile model
    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    print("\\nModel architecture:")
    model.summary()
    
    # Generate dummy training data for demonstration
    print("\\nGenerating dummy training data...")
    batch_size = 32
    X_train = np.random.random((batch_size * 10, sequence_length, feature_dims)).astype(np.float32)
    y_train = np.random.randint(0, num_classes, (batch_size * 10,)).astype(np.int32)
    
    # Train for a few epochs (this is just for demo)
    print("\\nTraining model (demo)...")
    history = model.fit(
        X_train, y_train,
        epochs=5,
        batch_size=batch_size,
        validation_split=0.2,
        verbose=1
    )
    
    print(f"\\nTraining completed. Final loss: {history.history['loss'][-1]:.4f}")
    
    # Convert to TensorFlow Lite
    print("\\nConverting to TensorFlow Lite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Enable optimization
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Convert model
    tflite_model = converter.convert()
    
    # Save model
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"\\nDemo LSTM model saved to: {output_path}")
    print(f"Model size: {len(tflite_model) / 1024:.1f} KB")
    
    # Test the converted model
    print("\\nTesting converted model...")
    test_model = tf.lite.Interpreter(model_path=output_path)
    test_model.allocate_tensors()
    
    input_details = test_model.get_input_details()
    output_details = test_model.get_output_details()
    
    print(f"Input shape: {input_details[0]['shape']}")
    print(f"Output shape: {output_details[0]['shape']}")
    
    # Test inference
    test_input = np.random.random((1, sequence_length, feature_dims)).astype(np.float32)
    test_model.set_tensor(input_details[0]['index'], test_input)
    test_model.invoke()
    output = test_model.get_tensor(output_details[0]['index'])
    
    predicted_class = np.argmax(output)
    confidence = output[0][predicted_class]
    
    print(f"Test prediction: class {predicted_class} with confidence {confidence:.3f}")
    
    return output_path

def generate_model_info(output_path):
    """Generate model information file."""
    info_content = f"""# ASL LSTM Model Information

## Model Details
- Architecture: LSTM with Dense layers
- Input Shape: [1, 15, 512] (batch, sequence_length, features)
- Output Shape: [1, 20] (batch, num_classes)
- Data Type: Float32

## ASL Dynamic Signs
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

## Usage in SignSync
Place this file in: assets/models/asl_lstm.tflite

## Note
This is a demo model. For production use, train on real ASL sequence data.
"""
    
    info_path = output_path.replace('.tflite', '_info.md')
    with open(info_path, 'w') as f:
        f.write(info_content)
    
    print(f"Model info saved to: {info_path}")

def main():
    """Main function to generate demo LSTM model."""
    print("ASL LSTM Model Generator")
    print("=" * 30)
    
    # Create models directory if it doesn't exist
    models_dir = "models"
    os.makedirs(models_dir, exist_ok=True)
    
    output_path = os.path.join(models_dir, "asl_lstm_demo.tflite")
    
    try:
        # Generate demo model
        model_path = create_demo_lstm_model(output_path=output_path)
        
        # Generate model info
        generate_model_info(model_path)
        
        print("\\n" + "=" * 30)
        print("Model generation completed successfully!")
        print(f"\\nTo use in SignSync:")
        print(f"1. Copy {model_path} to your Flutter project's assets/models/")
        print(f"2. Rename to asl_lstm.tflite")
        print(f"3. Update pubspec.yaml if needed")
        print(f"4. Run the app and test LSTM integration")
        
    except Exception as e:
        print(f"\\nError generating model: {e}")
        print("\\nMake sure you have TensorFlow installed:")
        print("pip install tensorflow==2.13.0 numpy==1.24.0")

if __name__ == "__main__":
    main()