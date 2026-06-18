import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image/image.dart' as img;
import '../theme/app_theme.dart';
import '../models/sign_model.dart';
import '../services/progress_service.dart';
import '../services/classifier_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  CameraController? _controller;
  bool _isDetecting = false;
  bool _quizStarted = false;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  String _feedback = '';
  bool? _lastCorrect;
  String _detectedSign = '';
  int _stableCount = 0;
  String _lastSeen = '';

  late List<SignModel> _quizSigns;

  @override
  void initState() {
    super.initState();
    _quizSigns = List.from(SignModel.allSigns)..shuffle();
    _quizSigns = _quizSigns.take(10).toList();
    _initCamera();
    ClassifierService.load();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  void _startDetecting() {
    _controller!.startImageStream((CameraImage cameraImage) async {
      if (_isDetecting || !_quizStarted) return;
      _isDetecting = true;

      try {
        // Convert CameraImage to img.Image
        final image = _convertCameraImage(cameraImage);
        if (image == null) return;

        // Run inference using tflite_flutter
        final result = await ClassifierService.classifyFrame(image);

        if (result != null && mounted) {
          final sign = result.label;
          final conf = result.confidence;

          if (sign == _lastSeen) {
            _stableCount++;
          } else {
            _stableCount = 0;
            _lastSeen = sign;
          }

          // Confirm after 5 stable frames with 50%+ confidence
          if (_stableCount >= 5 && conf >= 0.50) {
            _stableCount = 0;
            _lastSeen = '';
            _checkAnswer(sign);
          }

          if (mounted) setState(() => _detectedSign = sign);
        } else {
          if (mounted) setState(() => _detectedSign = '');
        }
      } finally {
        _isDetecting = false;
      }
    });
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      // ── Fix: use named parameters for img.Image constructor ──────────
      final image = img.Image(width: width, height: height);

      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yVal = yBytes[y * yPlane.bytesPerRow + x] & 0xFF;
          final int uvX = x ~/ 2;
          final int uvY = y ~/ 2;
          final int uVal = uBytes[uvY * uPlane.bytesPerRow + uvX] & 0xFF;
          final int vVal = vBytes[uvY * vPlane.bytesPerRow + uvX] & 0xFF;

          final int r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toInt();
          final int g =
              (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
                  .clamp(0, 255)
                  .toInt();
          final int b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toInt();

          // ── Fix: setPixel instead of setPixelRgba ────────────────────
          image.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }
      return image;
    } catch (e) {
      print('_convertCameraImage ERROR: $e');
      return null;
    }
  }

  void _checkAnswer(String detected) {
    if (_currentIndex >= _quizSigns.length) return;
    final target = _quizSigns[_currentIndex].label;
    final correct = detected == target;

    ProgressService.recordQuizResult(target, correct);

    setState(() {
      _lastCorrect = correct;
      _feedback = correct ? '✓ Correct!' : '✗ Try again — expected $target';

      if (correct) {
        _score++;
        _streak++;
        if (_currentIndex < _quizSigns.length - 1) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              setState(() {
                _currentIndex++;
                _lastCorrect = null;
                _feedback = '';
              });
            }
          });
        } else {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) _showResults();
          });
        }
      } else {
        _streak = 0;
      }
    });
  }

  void _showResults() {
    _controller?.stopImageStream();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Quiz Complete!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_score / ${_quizSigns.length}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            Text(
              '${(_score / _quizSigns.length * 100).toStringAsFixed(0)}% accuracy',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _score / _quizSigns.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _quizSigns = List.from(SignModel.allSigns)..shuffle();
                _quizSigns = _quizSigns.take(10).toList();
                _currentIndex = 0;
                _score = 0;
                _streak = 0;
                _lastCorrect = null;
                _feedback = '';
                _quizStarted = false;
                _detectedSign = '';
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentSign = _currentIndex < _quizSigns.length
        ? _quizSigns[_currentIndex]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          Positioned.fill(child: CameraPreview(_controller!)),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_quizStarted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_score / ${_quizSigns.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_streak > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🔥 $_streak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: !_quizStarted
                  ? _buildStartPanel()
                  : _buildQuizPanel(currentSign),
            ),
          ),

          // Feedback overlay
          if (_lastCorrect != null)
            Positioned.fill(
              child:
                  Container(
                        color: _lastCorrect!
                            ? AppTheme.primary.withValues(alpha: 0.25)
                            : AppTheme.accent.withValues(alpha: 0.25),
                      )
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .then()
                      .fadeOut(duration: 800.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildStartPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Ready to practice?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Show the correct hand sign when prompted',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _quizStarted = true);
              _startDetecting();
            },
            child: const Text('Start Quiz'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizPanel(SignModel? sign) {
    if (sign == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar
        Row(
          children: List.generate(
            _quizSigns.length,
            (i) => Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < _currentIndex
                      ? AppTheme.primary
                      : i == _currentIndex
                      ? Colors.white54
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Show this sign:',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sign.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (sign.isMotion)
                    const Text(
                      'Motion sign — perform the full gesture',
                      style: TextStyle(color: AppTheme.accent, fontSize: 11),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                const Text(
                  'Detected:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  _detectedSign.isNotEmpty ? _detectedSign : '—',
                  style: TextStyle(
                    color: _detectedSign == sign.label
                        ? AppTheme.primary
                        : Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),

        if (_feedback.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _lastCorrect == true
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _feedback,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _lastCorrect == true
                    ? AppTheme.primary
                    : AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
