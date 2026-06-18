import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/classifier_service.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});
  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  Uint8List? _debugImageBytes;
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isDetecting = false;
  bool _isSwitching = false;
  String _stableSign = '';
  double _stableConf = 0.0;
  int _stableCount = 0;
  String _lastSign = '';
  int _frameCount = 0;
  Map<String, dynamic>? _handBox;
  Map<String, dynamic>? _lastHandBox;
  Map<String, dynamic>? _displayBox;
  bool _handFound = false;
  int _noHandCount = 0;

  static const int FRAME_SKIP = 6;
  static const int NO_HAND_TIMEOUT = 15;

  // Video overlay
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCameras();
    ClassifierService.load().then((_) {
      print('Classifier load complete');
    });
    _initVideo();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startCamera(_cameraIndex);
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('assets/signer_video.mp4')
      ..initialize().then((_) {
        setState(() {
          _videoInitialized = true;
        });
        _videoController!.setLooping(true);
        _videoController!.play();
      });
  }

  Future<void> _startCamera(int index) async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;

    if (index >= _cameras.length) return;

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

    if (!mounted) return;

    _controller = controller;
    _stableSign = '';
    _handFound = false;
    _handBox = null;
    _lastHandBox = null;
    _displayBox = null;

    _controller!.startImageStream((CameraImage cameraImage) async {
      _frameCount++;
      if (_frameCount % FRAME_SKIP != 0) return;
      if (_isDetecting || _isSwitching) return;
      _isDetecting = true;

      try {
        final isFront =
            _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

        final frameData = {
          'w': cameraImage.width,
          'h': cameraImage.height,
          'yBytes': Uint8List.fromList(cameraImage.planes[0].bytes),
          'uBytes': Uint8List.fromList(cameraImage.planes[1].bytes),
          'vBytes': Uint8List.fromList(cameraImage.planes[2].bytes),
          'yRow': cameraImage.planes[0].bytesPerRow,
          'uRow': cameraImage.planes[1].bytesPerRow,
          'vRow': cameraImage.planes[2].bytesPerRow,
          'uvPixel': cameraImage.planes[1].bytesPerPixel ?? 1,
          'isFrontCamera': isFront,
        };

        final resultMap = await compute(_processImageInBackground, frameData);

        if (resultMap == null) {
          _isDetecting = false;
          return;
        }

        final int rw = resultMap['width'] as int;
        final int rh = resultMap['height'] as int;
        final Uint8List pixels = resultMap['pixels'] as Uint8List;
        final Uint8List debugBytes = resultMap['debugBytes'] as Uint8List;

        final rotatedImage = img.Image.fromBytes(
          width: rw,
          height: rh,
          bytes: pixels.buffer,
          format: img.Format.uint8,
          numChannels: 3,
        );

        final result = await ClassifierService.classifyFrame(rotatedImage);

        if (mounted) {
          setState(() {
            _debugImageBytes = debugBytes;
          });
        }

        if (result != null && mounted) {
          final sign = result.label;
          final conf = result.confidence;

          if (sign == _lastSign) {
            _stableCount++;
          } else {
            _stableCount = 0;
            _lastSign = sign;
          }

          final handBox =
              result.handBox ??
              {'x1': 0.15, 'y1': 0.20, 'x2': 0.85, 'y2': 0.80};

          setState(() {
            _handBox = handBox;
            _lastHandBox = handBox;
            _handFound = true;
            _noHandCount = 0;
            _updateDisplayBox(_handBox);
            if (_stableCount >= 2) {
              _stableSign = sign;
              _stableConf = conf;
            }
          });
        } else if (mounted) {
          _noHandCount++;
          if (_noHandCount > NO_HAND_TIMEOUT) {
            setState(() {
              _handFound = false;
              _handBox = null;
              _displayBox = null;
              _stableSign = '';
              _stableCount = 0;
            });
          } else {
            setState(() {
              _handBox = _lastHandBox;
              _handFound = _lastHandBox != null;
              _updateDisplayBox(_handBox);
            });
          }
        }
      } catch (e) {
        print('Stream ERROR: $e');
      } finally {
        _isDetecting = false;
      }
    });
    setState(() {});
  }

  void _updateDisplayBox(Map<String, dynamic>? target) {
    if (target == null) {
      _displayBox = null;
      return;
    }
    if (_displayBox == null) {
      _displayBox = Map<String, dynamic>.from(target);
      return;
    }
    const double alpha = 0.5;
    _displayBox = {
      'x1': _lerp(_displayBox!['x1'], target['x1'], alpha),
      'y1': _lerp(_displayBox!['y1'], target['y1'], alpha),
      'x2': _lerp(_displayBox!['x2'], target['x2'], alpha),
      'y2': _lerp(_displayBox!['y2'], target['y2'], alpha),
    };
  }

  double _lerp(dynamic a, dynamic b, double t) =>
      (a as num).toDouble() * (1 - t) + (b as num).toDouble() * t;

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isSwitching) return;
    setState(() => _isSwitching = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera(_cameraIndex);
    setState(() => _isSwitching = false);
  }

  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameraIndex < _cameras.length &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _videoController?.dispose();
    ClassifierService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCameraReady =
        _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      body: Stack(
        children: [
          if (isCameraReady)
            SizedBox.expand(child: CameraPreview(_controller!)),
          if (!isCameraReady) const Center(child: CircularProgressIndicator()),

          // ── Video overlay (top‑right) ──────────────────────────────
          if (_videoInitialized && _videoController != null)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ),

          // ── Hand detection overlays ────────────────────────────────
          if (isCameraReady && _displayBox != null)
            CustomPaint(
              painter: _HandBoxPainter(
                handBox: _displayBox,
                handFound: _handFound,
                sign: _stableSign,
                conf: _stableConf,
              ),
              size: Size.infinite,
            ),
          if (isCameraReady && !_handFound)
            CustomPaint(
              painter: _SearchIndicatorPainter(),
              size: Size.infinite,
            ),

          // ── Top controls ─────────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam,
                        color: Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isFrontCamera ? 'Front' : 'Back',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cameraswitch,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_stableSign.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _PredictionPanel(sign: _stableSign, conf: _stableConf),
            ),
        ],
      ),
    );
  }
}

// ── Custom painters and panels ──────────────────────────────────────────

class _SearchIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const padding = 60.0;
    final rect = Rect.fromLTWH(
      padding,
      (size.height - size.width + padding * 2) / 2,
      size.width - padding * 2,
      size.width - padding * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    const t = 18.0;
    canvas.drawLine(
      Offset(rect.left + t, rect.top),
      Offset(rect.left, rect.top),
      Paint()
        ..color = Colors.white38
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + t),
      Paint()
        ..color = Colors.white38
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SearchIndicatorPainter oldDelegate) => false;
}

class _HandBoxPainter extends CustomPainter {
  final Map<String, dynamic>? handBox;
  final bool handFound;
  final String sign;
  final double conf;

  const _HandBoxPainter({
    required this.handBox,
    required this.handFound,
    required this.sign,
    required this.conf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (handBox == null) return;

    final x1 = (handBox!['x1'] as num).toDouble();
    final y1 = (handBox!['y1'] as num).toDouble();
    final x2 = (handBox!['x2'] as num).toDouble();
    final y2 = (handBox!['y2'] as num).toDouble();

    final left = x1 * size.width;
    final top = y1 * size.height;
    final right = x2 * size.width;
    final bottom = y2 * size.height;
    final rect = Rect.fromLTRB(left, top, right, bottom);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = (sign.isNotEmpty ? AppTheme.primary : Colors.white)
            .withOpacity(0.08)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = sign.isNotEmpty ? AppTheme.primary : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    _drawCorners(
      canvas,
      rect,
      sign.isNotEmpty ? AppTheme.primary : Colors.white,
    );

    if (sign.isNotEmpty) _drawLabel(canvas, rect, sign, conf);
  }

  void _drawCorners(Canvas canvas, Rect rect, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    const l = 22.0;
    canvas.drawLine(
      Offset(rect.left, rect.top + l),
      Offset(rect.left, rect.top),
      p,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + l, rect.top),
      p,
    );
    canvas.drawLine(
      Offset(rect.right - l, rect.top),
      Offset(rect.right, rect.top),
      p,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + l),
      p,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom - l),
      Offset(rect.left, rect.bottom),
      p,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + l, rect.bottom),
      p,
    );
    canvas.drawLine(
      Offset(rect.right - l, rect.bottom),
      Offset(rect.right, rect.bottom),
      p,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - l),
      p,
    );
  }

  void _drawLabel(Canvas canvas, Rect rect, String sign, double conf) {
    final label = '$sign  ${(conf * 100).toStringAsFixed(0)}%';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const pad = 8.0;
    final tagW = tp.width + pad * 2;
    final tagH = tp.height + pad;
    final tagL = rect.left;
    final tagT = (rect.top - tagH - 4).clamp(0.0, double.infinity);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tagL, tagT, tagW, tagH),
        const Radius.circular(6),
      ),
      Paint()..color = AppTheme.primary,
    );
    tp.paint(canvas, Offset(tagL + pad, tagT + pad / 2));
  }

  @override
  bool shouldRepaint(_HandBoxPainter old) =>
      old.handBox != handBox ||
      old.handFound != handFound ||
      old.sign != sign ||
      old.conf != conf;
}

class _PredictionPanel extends StatelessWidget {
  final String sign;
  final double conf;
  const _PredictionPanel({required this.sign, required this.conf});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: Center(
              child: Text(
                sign,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Detected Sign',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                Text(
                  sign,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(conf * 100).toStringAsFixed(0)}% confident',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background image processing (isolate‑safe) ──────────────────────────
Map<String, dynamic>? _processImageInBackground(Map<String, dynamic> data) {
  try {
    final int w = data['w'];
    final int h = data['h'];
    final bool isFrontCamera = data['isFrontCamera'] ?? false;

    final Uint8List yBytes = data['yBytes'];
    final Uint8List uBytes = data['uBytes'];
    final Uint8List vBytes = data['vBytes'];
    final int yRow = data['yRow'];
    final int uRow = data['uRow'];
    final int vRow = data['vRow'];
    final int uvPixel = data['uvPixel'];

    final out = img.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int yy = yBytes[y * yRow + x] & 0xFF;
        final int uvX = (x ~/ 2) * uvPixel;
        final int uvY = y ~/ 2;
        final int ui = uvY * uRow + uvX;
        final int vi = uvY * vRow + uvX;
        if (ui >= uBytes.length || vi >= vBytes.length) continue;
        final int uu = uBytes[ui] & 0xFF;
        final int vv = vBytes[vi] & 0xFF;

        final int r = (yy + 1.370705 * (vv - 128)).clamp(0, 255).toInt();
        final int g = (yy - 0.698001 * (vv - 128) - 0.337633 * (uu - 128))
            .clamp(0, 255)
            .toInt();
        final int b = (yy + 1.732446 * (uu - 128)).clamp(0, 255).toInt();

        out.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    img.Image processed = out;

    if (isFrontCamera) {
      processed = img.copyRotate(processed, angle: 270);
      processed = img.flipHorizontal(processed);
    } else {
      processed = img.copyRotate(processed, angle: 90);
    }

    final debugJpgBytes = img.encodeJpg(processed);

    final int pw = processed.width;
    final int ph = processed.height;
    final rawPixels = Uint8List(pw * ph * 3);
    int i = 0;
    for (int py = 0; py < ph; py++) {
      for (int px = 0; px < pw; px++) {
        final p = processed.getPixel(px, py);
        rawPixels[i++] = p.r.toInt();
        rawPixels[i++] = p.g.toInt();
        rawPixels[i++] = p.b.toInt();
      }
    }

    return {
      'pixels': rawPixels,
      'width': pw,
      'height': ph,
      'debugBytes': Uint8List.fromList(debugJpgBytes),
    };
  } catch (e) {
    print('❌ Isolate YUV ERROR: $e');
    return null;
  }
}
