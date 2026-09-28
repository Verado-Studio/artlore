import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/sample_images.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/painting_placeholder.dart';
import '../scan_flow.dart';
import '../widgets/viewfinder_grid.dart';

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
          // Some devices report absurdly high digital-zoom ceilings (100x+)
          // that make the control useless — cap it at a sane range.
          _maxZoom = maxZoom > 4.0 ? 4.0 : maxZoom;
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

  Future<void> _pickSampleImage(String assetPath) async {
    Navigator.of(context).pop();
    if (!mounted) return;
    await startSampleScanFlow(context, assetPath);
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
                  for (final asset in sampleImages)
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
                child: _ZoomRulerControl(
                  min: _minZoom,
                  max: _maxZoom,
                  value: _zoomLevel,
                  onChanged: _setZoom,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

/// Zoom control matching a light "pill" card: quick-select 1x/2x/3x chips
/// on top, and a continuous tick-mark ruler below (draggable) covering the
/// full [min]-[max] range so values between presets, and above 3x up to
/// [max], stay reachable.
class _ZoomRulerControl extends StatelessWidget {
  const _ZoomRulerControl({required this.min, required this.max, required this.value, required this.onChanged});

  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  static const _presets = [1.0, 2.0, 3.0];
  static const _rulerWidth = 260.0;

  void _handle(double localX) {
    final t = (localX / _rulerWidth).clamp(0.0, 1.0);
    onChanged(min + t * (max - min));
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets.where((p) => p >= min && p <= max).toList();
    final t = (max > min) ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in presets) ...[
                  _ZoomPresetChip(label: '${p.toStringAsFixed(0)}x', selected: (value - p).abs() < 0.15, onTap: () => onChanged(p)),
                  if (p != presets.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handle(details.localPosition.dx),
              onHorizontalDragUpdate: (details) => _handle(details.localPosition.dx),
              child: SizedBox(
                width: _rulerWidth,
                height: 20,
                child: CustomPaint(painter: _ZoomRulerPainter(t: t)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomPresetChip extends StatelessWidget {
  const _ZoomPresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4CAF50).withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF7ED184) : Colors.white.withValues(alpha: 0.28), width: 1.4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFFA8F0AC) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _ZoomRulerPainter extends CustomPainter {
  _ZoomRulerPainter({required this.t});

  final double t;
  static const _tickCount = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i <= _tickCount; i++) {
      final x = size.width * i / _tickCount;
      final isMid = i == _tickCount ~/ 2;
      tickPaint.strokeWidth = isMid ? 1.6 : 1;
      canvas.drawLine(Offset(x, size.height * 0.3), Offset(x, size.height * (isMid ? 0.9 : 0.7)), tickPaint);
    }

    final markerX = size.width * t;
    canvas.drawLine(
      Offset(markerX, 0),
      Offset(markerX, size.height),
      Paint()
        ..color = const Color(0xFF4CAF50)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ZoomRulerPainter oldDelegate) => oldDelegate.t != t;
}
