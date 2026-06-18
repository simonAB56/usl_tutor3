import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math' as math;

class ClassifierService {
  static Interpreter? _interpreter;
  static List<String> _labels = [];
  static bool _isLoaded = false;

  static const int INPUT_SIZE = 224;
  static const double CONF_THRESH = 0.50; // lowered to detect more
  static const int NUM_CLASSES = 37;

  static Future<void> load() async {
    if (_isLoaded) return;
    try {
      print('=== Loading TFLite model ===');
      final options = InterpreterOptions()..threads = 5;
      if (Platform.isAndroid) {
        try {
          options.addDelegate(GpuDelegateV2());
          print('GPU delegate (v2) requested');
        } catch (e) {
          print('GPU delegate unavailable, falling back to CPU: $e');
        }
      } else if (Platform.isIOS) {
        try {
          options.addDelegate(GpuDelegate());
          print('GPU delegate requested');
        } catch (e) {
          print('GPU delegate unavailable, falling back to CPU: $e');
        }
      }

      _interpreter = await Interpreter.fromAsset(
        'assets/model/usl_model.tflite',
        options: options,
      );

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      print('Input  shape : ${inputTensor.shape}');
      print('Output shape : ${outputTensor.shape}');

      final outShape = outputTensor.shape;
      if (outShape.length == 3) {
        final modelNC = outShape[1] - 4;
        if (modelNC != NUM_CLASSES) {
          print(
            '⚠️ WARNING: model has $modelNC classes but NUM_CLASSES=$NUM_CLASSES',
          );
        } else {
          print('✅ Output shape matches: NC=$modelNC, anchors=${outShape[2]}');
        }
      }

      final raw = await rootBundle.loadString('assets/model/labels.txt');
      _labels = raw
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      print('Labels loaded: ${_labels.length} → $_labels');

      _isLoaded = true;
      print('=== TFLite model ready ===');
    } catch (e, stack) {
      print('=== LOAD ERROR: $e ===');
      print(stack);
    }
  }

  static Future<DetectionResult?> classifyFrame(img.Image image) async {
    if (!_isLoaded || _interpreter == null) {
      print('Classifier not loaded — skipping');
      return null;
    }

    try {
      final resized = img.copyResize(
        image,
        width: INPUT_SIZE,
        height: INPUT_SIZE,
      );
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      final Float32List inputData = Float32List(
        1 * INPUT_SIZE * INPUT_SIZE * 3,
      );
      int idx = 0;
      for (int y = 0; y < INPUT_SIZE; y++) {
        for (int x = 0; x < INPUT_SIZE; x++) {
          final pixel = resized.getPixel(x, y);
          inputData[idx++] = pixel.r.toDouble() / 255.0;
          inputData[idx++] = pixel.g.toDouble() / 255.0;
          inputData[idx++] = pixel.b.toDouble() / 255.0;
        }
      }

      final input = inputData.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);

      final outputSize = outputShape.reduce((a, b) => a * b);
      final outputData = Float32List(outputSize);
      final output = outputData.reshape(outputShape);

      _interpreter!.run(input, output);
      return _parseOutput(output, outputShape);
    } catch (e, stack) {
      print('classifyFrame ERROR: $e');
      print(stack);
      return null;
    }
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  static DetectionResult? _parseOutput(dynamic output, List<int> shape) {
    try {
      double bestConf = 0.0;
      String bestLabel = '';

      final data = output[0] as List; // shape [41, 1029]
      final numAnchors = shape[2];

      for (int d = 0; d < numAnchors; d++) {
        double maxConf = 0.0;
        int classId = 0;

        for (int c = 0; c < NUM_CLASSES; c++) {
          final double rawScore = (data[4 + c][d] as num).toDouble();
          final double score = _sigmoid(rawScore);
          if (score > maxConf) {
            maxConf = score;
            classId = c;
          }
        }

        if (maxConf > CONF_THRESH && maxConf > bestConf) {
          bestConf = maxConf;
          bestLabel = classId < _labels.length ? _labels[classId] : '$classId';
        }
      }

      if (bestLabel.isEmpty) return null;

      // ── Override the box to cover the entire screen ──
      // This makes the detection highlight the whole screen.
      return DetectionResult(
        label: bestLabel,
        confidence: bestConf,
        handBox: {'x1': 0.0, 'y1': 0.0, 'x2': 1.0, 'y2': 1.0},
      );
    } catch (e) {
      print('_parseOutput ERROR: $e');
      return null;
    }
  }

  static void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}

class DetectionResult {
  final String label;
  final double confidence;
  final Map<String, dynamic>? handBox;
  const DetectionResult({
    required this.label,
    required this.confidence,
    this.handBox,
  });
}
