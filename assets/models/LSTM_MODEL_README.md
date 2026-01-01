# LSTM Model Placeholder

This is a placeholder file for the LSTM model. In production, this should be replaced with an actual TFLite model.

## To Generate a Real Model

1. Install Python dependencies:
   ```bash
   pip install tensorflow==2.13.0 numpy==1.24.0
   ```

2. Run the model generator:
   ```bash
   python scripts/generate_lstm_model.py
   ```

3. Copy the generated model:
   ```bash
   cp models/asl_lstm_demo.tflite assets/models/asl_lstm.tflite
   ```

## Model Specifications

- **Input Shape**: [1, 15, 512]
- **Output Shape**: [1, 20]  
- **Format**: TensorFlow Lite (.tflite)
- **Classes**: 20 dynamic ASL signs

## Testing Without Model

The LSTM service includes fallback behavior for missing models:
- Graceful error handling
- Detailed error messages
- Mock processing for testing

For development and testing, you can run the app without the LSTM model and it will still function with CNN-only static sign recognition.