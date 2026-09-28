import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/painting_placeholder.dart';
import '../scan_flow.dart';
import '../widgets/viewfinder_grid.dart';

/// Bundled demo photos so the app can be tried out without a real painting
/// on hand — picking one runs through the exact same identify pipeline as a
/// real camera/gallery photo.
const _sampleImages = [
  'assets/image1.webp',
  'assets/image2.webp',
  'assets/image3.jpg',
];

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  late final Animation<double> _bounceAnimation = Tween<double>(begin: 0, end: -8)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_bounceController);
  bool _flashOn = false;
  bool _capturing = false;
  static const _aspectRatio = 0.78;
  Offset? _focusPoint;
  Timer? _focusRingTimer;
  double _zoomLevel = 1;
  double _minZoom = 1;
  double _maxZoom = 1;

  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setUpCamera();
  }

  @override
  void dispose() {
    _focusRingTimer?.cancel();
    _bounceController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _setUpCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device — use Gallery instead.');
        return;
      }
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      await _openCamera(backCamera);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access the camera — use Gallery instead.");
    }
  }

  Future<void> _openCamera(CameraDescription description) async {
    final previous = _controller;
    final controller = CameraController(description, ResolutionPreset.medium, enableAudio: false);
    final initializeFuture = controller.initialize();
    setState(() {
      _controller = controller;
      _initializeControllerFuture = initializeFuture;
      _error = null;
    });
    try {
      await initializeFuture;
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access the camera — use Gallery instead.");
      await previous?.dispose();
      return;
    }

    // Neither of these is essential to a working camera — some devices
    // don't support torch mode or reporting a zoom range at all — so a
    // failure here only means "no flash toggle"/"no zoom slider", not a
    // full camera error.
    try {
      await controller.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      // Flash unsupported on this device — leave the toggle inert.
    }
    try {
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      if (mounted) {
        setState(() {
          _minZoom = minZoom;
          _maxZoom = maxZoom;
          _zoomLevel = minZoom;
        });
      }
    } catch (_) {
      // Zoom unsupported/unreadable on this device — the slider just won't show.
    }
    await previous?.dispose();
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _zoomLevel = value);
    try {
      await controller.setZoomLevel(value);
    } catch (_) {
      // Not every device supports programmatic zoom.
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _flashOn = next);
    } catch (_) {
      // Not every device/browser supports torch mode — leave the toggle as-is.
    }
  }

  Future<void> _handleTapToFocus(TapUpDetails details, BoxConstraints constraints) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final point = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (_) {
      // Not every device/browser supports manual focus/exposure points.
    }
    _focusRingTimer?.cancel();
    setState(() => _focusPoint = details.localPosition);
    _focusRingTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      await controller.dispose();
      if (mounted) setState(() => _controller = null);
      if (!mounted) return;
      await startScanFlow(context, image: file);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't take the photo. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await startScanFlow(context, image: image);
  }

  /// On Android/iOS, copies a bundled demo asset into a real temp file and
  /// runs it through the normal scan flow — an [XFile] backed purely by
  /// in-memory bytes has no real filesystem path, which later steps
  /// (compression, then copying the photo into permanent storage) need. On
  /// web there's no filesystem at all, so it's passed straight through as
  /// in-memory bytes instead (identify still works; the later "save to
  /// permanent storage" step is itself a no-op on web).
  Future<void> _pickSampleImage(String assetPath) async {
    Navigator.of(context).pop();
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final name = assetPath.split('/').last;
    if (!mounted) return;
    if (kIsWeb) {
      await startScanFlow(context, image: XFile.fromData(bytes, name: name));
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    await startScanFlow(context, image: XFile(file.path));
  }

  void _showSampleImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No painting handy?',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap a sample below to try a scan.',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final asset in _sampleImages)
                    _SampleThumbnail(
                      asset: asset,
                      onTap: () => _pickSampleImage(asset),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ToolbarIcon(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const reservedForText = 56.0;
                    final maxFrameHeight = (constraints.maxHeight - reservedForText).clamp(80.0, double.infinity);
                    var frameWidth = constraints.maxWidth;
                    var frameHeight = frameWidth / _aspectRatio;
                    if (frameHeight > maxFrameHeight) {
                      frameHeight = maxFrameHeight;
                      frameWidth = frameHeight * _aspectRatio;
                    }

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: frameWidth,
                            height: frameHeight,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: AppColors.frameGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LayoutBuilder(
                                  builder: (context, previewConstraints) {
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (details) => _handleTapToFocus(details, previewConstraints),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildPreview(),
                                          const ViewfinderGrid(),
                                          if (_focusPoint case final point?)
                                            Positioned(
                                              left: point.dx - 24,
                                              top: point.dy - 24,
                                              child: const _FocusRing(),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _error ?? 'Fill the frame with the painting',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_maxZoom > _minZoom)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _ZoomArcControl(
                  min: _minZoom,
                  max: _maxZoom,
                  value: _zoomLevel,
                  onChanged: _setZoom,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _GalleryShortcut(onTap: _pickFromGallery),
                  _ShutterButton(onTap: _capturing ? null : _capture),
                  _ToolbarIcon(
                    icon: _flashOn ? Icons.flash_on : Icons.flash_off_outlined,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _showSampleImagePicker,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _bounceAnimation.value),
                        child: child,
                      );
                    },
                    child: const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    final initializeFuture = _initializeControllerFuture;
    if (_error != null || controller == null || initializeFuture == null) {
      return const PaintingPlaceholder(icon: Icons.photo_camera_outlined, seed: 0, showFrame: false);
    }
    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !controller.value.isInitialized) {
          return const ColoredBox(
            color: Colors.black26,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        final size = controller.value.previewSize;
        if (size == null) return CameraPreview(controller);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.height,
                height: size.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
      ),
    );
  }
}

class _SampleThumbnail extends StatelessWidget {
  const _SampleThumbnail({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(asset, width: 92, height: 92, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _GalleryShortcut extends StatelessWidget {
  const _GalleryShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text('Gallery', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

/// iOS-style curved zoom dial: a dotted arc from [min] to [max] with a
/// draggable pill showing the current multiplier, matching the native
/// Camera app's zoom control instead of a plain straight slider.
class _ZoomArcControl extends StatelessWidget {
  const _ZoomArcControl({required this.min, required this.max, required this.value, required this.onChanged});

  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  static const _width = 220.0;
  static const _height = 64.0;

  void _handle(Offset localPosition) {
    final t = (localPosition.dx / _width).clamp(0.0, 1.0);
    onChanged(min + t * (max - min));
  }

  @override
  Widget build(BuildContext context) {
    final t = (max > min) ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _handle(details.localPosition),
        onHorizontalDragUpdate: (details) => _handle(details.localPosition),
        child: SizedBox(
          width: _width,
          height: _height,
          child: CustomPaint(
            painter: _ZoomArcPainter(
              t: t,
              minLabel: '${min.toStringAsFixed(0)}x',
              maxLabel: '${max.toStringAsFixed(0)}x',
              valueLabel: '${value.toStringAsFixed(1)}x',
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomArcPainter extends CustomPainter {
  _ZoomArcPainter({required this.t, required this.minLabel, required this.maxLabel, required this.valueLabel});

  final double t;
  final String minLabel;
  final String maxLabel;
  final String valueLabel;

  static Offset _pointOnArc(Size size, double t) {
    final p0 = Offset(size.width * 0.06, size.height * 0.92);
    final p2 = Offset(size.width * 0.94, size.height * 0.92);
    final pc = Offset(size.width * 0.5, size.height * 0.02);
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * pc.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * pc.dy + t * t * p2.dy,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center, {
    Color color = Colors.white70,
    FontWeight weight = FontWeight.w500,
    double fontSize = 12,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    const dotCount = 26;
    for (var i = 0; i <= dotCount; i++) {
      canvas.drawCircle(_pointOnArc(size, i / dotCount), 1.5, dotPaint);
    }

    _drawLabel(canvas, minLabel, _pointOnArc(size, 0) + const Offset(0, 12), color: Colors.white60, fontSize: 11);
    _drawLabel(canvas, maxLabel, _pointOnArc(size, 1) + const Offset(0, 12), color: Colors.white60, fontSize: 11);

    final bubbleCenter = _pointOnArc(size, t);
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bubbleCenter, width: 48, height: 26),
      const Radius.circular(13),
    );
    canvas.drawRRect(bubbleRect, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _drawLabel(canvas, valueLabel, bubbleCenter, color: Colors.white, weight: FontWeight.w700, fontSize: 13);
  }

  @override
  bool shouldRepaint(covariant _ZoomArcPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.valueLabel != valueLabel;
}
