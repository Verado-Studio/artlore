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
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "No painting handy? Try a sample",
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  children: [
                    const Icon(Icons.remove, color: Colors.white70, size: 16),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          overlayColor: Colors.white24,
                          trackHeight: 2,
                        ),
                        child: Slider(
                          value: _zoomLevel.clamp(_minZoom, _maxZoom),
                          min: _minZoom,
                          max: _maxZoom,
                          onChanged: _setZoom,
                        ),
                      ),
                    ),
                    const Icon(Icons.add, color: Colors.white70, size: 16),
                  ],
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
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(asset, width: 84, height: 84, fit: BoxFit.cover),
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
