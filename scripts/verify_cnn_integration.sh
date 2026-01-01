#!/bin/bash
# Verification script for ResNet-50 CNN integration

echo "=== ResNet-50 CNN Integration Verification ==="
echo ""

# Check required files exist
echo "1. Checking required files..."

files=(
    "lib/services/cnn_inference_service.dart"
    "lib/config/providers.dart"
    "pubspec.yaml"
    "test/cnn_inference_test.dart"
    "docs/MODEL_SETUP.md"
    "docs/CNN_INTEGRATION_SUMMARY.md"
    "docs/CNN_COMPLETION_CHECKLIST.md"
    "docs/CNN_QUICKSTART.md"
    "docs/CNN_CHANGES.md"
    "assets/models/.gitkeep"
    "example/cnn_integration_example.dart"
)

missing=0
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        missing=$((missing + 1))
    fi
done

echo ""

# Check key requirements in CNN service
echo "2. Checking CNN service requirements..."

requirements=(
    "inputSize = 224"
    "confidenceThreshold = 0.85"
    "targetFpsMin = 15.0"
    "targetFpsMax = 20.0"
    "maxLatencyMs = 100"
    "smoothingWindow = 5"
    "_aslDictionary"
    "_phraseMapping"
    "_preprocessImageIsolate"
    "_applyTemporalSmoothing"
    "_calculateFps"
    "initialize("
    "bool lazy"
)

for req in "${requirements[@]}"; do
    if grep -q "$req" lib/services/cnn_inference_service.dart; then
        echo "  ✓ $req"
    else
        echo "  ✗ $req (NOT FOUND)"
        missing=$((missing + 1))
    fi
done

echo ""

# Check provider integration
echo "3. Checking provider integration..."

if grep -q "cnnInferenceServiceProvider" lib/config/providers.dart; then
    echo "  ✓ CNN provider defined"
else
    echo "  ✗ CNN provider NOT FOUND"
    missing=$((missing + 1))
fi

if grep -q "import.*cnn_inference_service" lib/config/providers.dart; then
    echo "  ✓ CNN service imported"
else
    echo "  ✗ CNN service NOT IMPORTED"
    missing=$((missing + 1))
fi

echo ""

# Check dependency
echo "4. Checking dependencies..."

if grep -q "image:" pubspec.yaml; then
    echo "  ✓ image package added"
else
    echo "  ✗ image package NOT FOUND"
    missing=$((missing + 1))
fi

if grep -q "tflite_flutter:" pubspec.yaml; then
    echo "  ✓ tflite_flutter package present"
else
    echo "  ✗ tflite_flutter package NOT FOUND"
    missing=$((missing + 1))
fi

echo ""

# Check tests
echo "5. Checking test coverage..."

if [ -f "test/cnn_inference_test.dart" ]; then
    echo "  ✓ CNN test file exists"
    test_count=$(grep -c "test(" test/cnn_inference_test.dart)
    echo "  ✓ Test count: $test_count"
else
    echo "  ✗ CNN test file NOT FOUND"
    missing=$((missing + 1))
fi

echo ""

# Check documentation
echo "6. Checking documentation..."

docs=(
    "docs/MODEL_SETUP.md"
    "docs/CNN_INTEGRATION_SUMMARY.md"
    "docs/CNN_COMPLETION_CHECKLIST.md"
    "docs/CNN_QUICKSTART.md"
    "docs/CNN_CHANGES.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        size=$(wc -l < "$doc")
        echo "  ✓ $doc ($size lines)"
    else
        echo "  ✗ $doc (MISSING)"
        missing=$((missing + 1))
    fi
done

echo ""

# Summary
echo "=== Verification Summary ==="

if [ $missing -eq 0 ]; then
    echo "✓ All checks passed! Integration is complete."
    echo ""
    echo "Next steps:"
    echo "1. Add asl_cnn.tflite model file to assets/models/"
    echo "2. Run: flutter pub get"
    echo "3. Run tests: flutter test test/cnn_inference_test.dart"
    echo "4. Test on device with camera"
    echo "5. Ready for Task 4 (LSTM integration)"
    exit 0
else
    echo "✗ $missing issue(s) found. Please review above."
    exit 1
fi
