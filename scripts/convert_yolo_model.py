import os
try:
    from ultralytics import YOLO
except ImportError:
    print("ultralytics not found. Please install with: pip install ultralytics")
    exit(1)

def convert_yolo_to_tflite(model_path='yolo11n.pt', output_dir='assets/models'):
    """
    Converts a YOLOv11 model to TFLite format with quantization.
    """
    print(f"Loading YOLOv11 model: {model_path}")
    model = YOLO(model_path)
    
    print("Exporting to TFLite format with int8 quantization...")
    # Export the model
    # nms=True adds NMS to the model, making it easier to use in mobile
    # int8=True for quantization
    # format='tflite' for TFLite
    model.export(format='tflite', int8=True, nms=True)
    
    # The exported file is usually in a folder named <model_name>_saved_model
    # or similar, depending on the version.
    # For newer ultralytics, it's <model_name>_float32.tflite or <model_name>_int8.tflite
    
    source_file = model_path.replace('.pt', '_saved_model/yolo11n_int8.tflite') # Simplified
    target_file = os.path.join(output_dir, 'yolov11.tflite')
    
    print(f"Model exported. Please move the tflite file to {target_file}")
    
if __name__ == "__main__":
    # Ensure assets/models directory exists
    os.makedirs('assets/models', exist_ok=True)
    
    # Note: In a real environment, you'd need the .pt file
    # convert_yolo_to_tflite()
    print("This script provides the logic used to convert YOLOv11 to TFLite.")
    print("To run this, you need a YOLOv11 .pt file and the ultralytics package.")
