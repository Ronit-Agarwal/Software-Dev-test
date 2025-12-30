#!/usr/bin/env python3
"""Convert a TensorFlow SavedModel/Keras model to TFLite with FP16 quantization.

Usage:
  python3 convert_tf_savedmodel_to_tflite_fp16.py \
    --saved_model_dir /path/to/saved_model \
    --output assets/models/asl_resnet50_fp16.tflite

Notes:
- This script expects a TensorFlow model already exported in TF format.
- If your training pipeline is PyTorch, export to ONNX first and then convert to
  TensorFlow (e.g., via onnx-tf / tf2onnx) before running this script.

It prints:
- output file size
- input/output tensor shapes (when possible)
"""

from __future__ import annotations

import argparse
import os


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--saved_model_dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--fp16", action="store_true", default=True)
    args = parser.parse_args()

    import tensorflow as tf

    converter = tf.lite.TFLiteConverter.from_saved_model(args.saved_model_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    if args.fp16:
        converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(tflite_model)

    size_mb = os.path.getsize(args.output) / 1024 / 1024
    print(f"Wrote: {args.output}")
    print(f"Size: {size_mb:.2f} MB")

    try:
        interpreter = tf.lite.Interpreter(model_path=args.output)
        interpreter.allocate_tensors()
        in_details = interpreter.get_input_details()
        out_details = interpreter.get_output_details()
        print("Input tensors:")
        for d in in_details:
            print(f"  - name={d.get('name')} shape={d.get('shape')} dtype={d.get('dtype')}")
        print("Output tensors:")
        for d in out_details:
            print(f"  - name={d.get('name')} shape={d.get('shape')} dtype={d.get('dtype')}")
    except Exception as e:
        print(f"(inspect skipped) Failed to inspect model: {e}")


if __name__ == "__main__":
    main()
