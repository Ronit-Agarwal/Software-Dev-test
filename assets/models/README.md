# Model assets

Place the FP16-quantized ResNet-50 ASL classifier here.

Expected default path (configurable in `CnnInferenceConfig`):

- `assets/models/asl_resnet50_fp16.tflite`

Also keep the class-index mapping file aligned with the model output:

- `assets/models/asl_sign_dictionary.json`

The app loads the model lazily (only when ASL Translation mode is activated).
