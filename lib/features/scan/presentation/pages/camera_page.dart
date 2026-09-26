import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/painting_placeholder.dart';
import '../scan_flow.dart';
import '../widgets/viewfinder_grid.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _flashOn = false;
  bool _gridOn = true;
  bool _capturing = false;
  double _aspectRatio = 0.78;
  Offset? _focusPoint;
  Timer? _focusRingTimer;

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
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
      await _openCamera(_cameraIndex);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access the camera — use Gallery instead.");
    }
  }

  Future<void> _openCamera(int index) async {
    final previous = _controller;
    final controller = CameraController(_cameras[index], ResolutionPreset.medium, enableAudio: false);
    final initializeFuture = controller.initialize();
    setState(() {
      _controller = controller;
      _initializeControllerFuture = initializeFuture;
      _error = null;
    });
    try {
      await initializeFuture;
      await controller.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access the camera — use Gallery instead.");
    } finally {
      await previous?.dispose();
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

  Future<void> _resetFocus() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {
      // Not every device/browser supports switching focus mode.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Focus reset to auto'), duration: Duration(seconds: 1)),
    );
  }

  void _cycleAspectRatio() {
    setState(() => _aspectRatio = _aspectRatio == 0.78 ? 1.0 : 0.78);
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(_cameraIndex);
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
                  Row(
                    children: [
                      _ToolbarIcon(
                        icon: _flashOn ? Icons.flash_on : Icons.flash_off_outlined,
                        onTap: _toggleFlash,
                      ),
                      const SizedBox(width: 8),
                      _ToolbarIcon(icon: Icons.center_focus_weak_outlined, onTap: _resetFocus),
                      const SizedBox(width: 8),
                      _ToolbarIcon(icon: Icons.crop_free, onTap: _cycleAspectRatio),
                      const SizedBox(width: 8),
                      _ToolbarIcon(
                        icon: _gridOn ? Icons.grid_on_outlined : Icons.grid_off_outlined,
                        onTap: () => setState(() => _gridOn = !_gridOn),
                      ),
                    ],
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
                                          if (_gridOn) const ViewfinderGrid(),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _GalleryShortcut(onTap: _pickFromGallery),
                  _ShutterButton(onTap: _capturing ? null : _capture),
                  _ToolbarIcon(icon: Icons.flip_camera_ios_outlined, onTap: _flipCamera),
                ],
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
