import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A stand-in "painting" used everywhere a real photo/artwork would go.
/// Renders a soft gradient canvas with a frame and a motif icon so every
/// mock screen still feels like a gallery instead of a grey box.
class PaintingPlaceholder extends StatelessWidget {
  const PaintingPlaceholder({
    super.key,
    this.borderRadius = 20,
    this.icon = Icons.image_outlined,
    this.seed = 0,
    this.showFrame = true,
  });

  final double borderRadius;
  final IconData icon;
  final int seed;
  final bool showFrame;

  static const List<List<Color>> _palettes = [
    [Color(0xFFE7C9A9), Color(0xFF9C6B45)],
    [Color(0xFFD8B4C0), Color(0xFF7A4E63)],
    [Color(0xFFB9CBB0), Color(0xFF5C7A56)],
    [Color(0xFFCDD8E0), Color(0xFF4D6478)],
    [Color(0xFFE3D2A0), Color(0xFF9A7B34)],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[seed % _palettes.length];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showFrame ? Border.all(color: AppColors.divider, width: 6) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette,
              ),
            ),
          ),
          Center(
            child: Icon(icon, size: 42, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
