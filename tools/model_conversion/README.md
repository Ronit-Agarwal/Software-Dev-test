# Model conversion (ResNet-50 -> TFLite FP16)

This folder contains **developer utilities** to convert a pre-trained CNN model to a mobile-friendly **TensorFlow Lite** format.

## TensorFlow (SavedModel) -> TFLite FP16

1. Export your trained model as a TensorFlow SavedModel.
2. Run:

```bash
python3 tools/model_conversion/convert_tf_savedmodel_to_tflite_fp16.py \
  --saved_model_dir /path/to/saved_model \
  --output assets/models/asl_resnet50_fp16.tflite
```

## PyTorch -> TFLite (recommended path)

The most reliable pipeline is:

1. PyTorch -> ONNX
2. ONNX -> TensorFlow SavedModel (via a conversion tool)
3. SavedModel -> TFLite FP16 (script above)

Exact steps depend on the training repo and are intentionally kept out of the Flutter app repository.

## Validation checklist

- Ensure the resulting `.tflite` file is ideally **< 50MB**.
- Confirm model input shape matches what the app expects (default: `1x224x224x3`).
- Confirm the output tensor shape is `1 x numClasses`.
- Ensure `assets/models/asl_sign_dictionary.json` matches the class index order.
