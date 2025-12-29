import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class UrgencyClassifier {
  late Interpreter _interpreter;
  final List<String> labels = ['High', 'Medium', 'Minor'];

  UrgencyClassifier() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/urgency_model.tflite');
  }

  Future<String> classify(File imageFile) async {
    // 1. Read and Resize the image (MobileNetV2 expects 224x224)
    final imageData = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageData);
    img.Image resizedImage = img.copyResize(originalImage!, width: 224, height: 224);

    // 2. Convert image to a 4D list (Tensor) [1, 224, 224, 3]
    var input = List.generate(1, (i) =>
        List.generate(224, (j) =>
            List.generate(224, (k) =>
                List.generate(3, (l) => 0.0))));

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0; // Red
        input[0][y][x][1] = pixel.g / 255.0; // Green
        input[0][y][x][2] = pixel.b / 255.0; // Blue
      }
    }

    // 3. Run Inference
    var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _interpreter.run(input, output);

    // 4. Find the highest probability
    double maxScore = -1;
    int bestIndex = 0;
    for (int i = 0; i < 3; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        bestIndex = i;
      }
    }

    return labels[bestIndex];
  }
}