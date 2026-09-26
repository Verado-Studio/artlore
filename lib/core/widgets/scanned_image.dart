import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'painting_placeholder.dart';

/// Shows the actual photo the user captured or picked, when there is one —
/// otherwise falls back to the same [PaintingPlaceholder] mock art used
/// everywhere else, so recent-scans/collection items without a real photo
/// still look like the rest of the app.
class ScannedImage extends StatelessWidget {
  const ScannedImage({
    super.key,
    required this.seed,
    this.imagePath,
    this.icon = Icons.image_outlined,
    this.showFrame = true,
    this.borderRadius = 20,
  });

  final int seed;
  final String? imagePath;
  final IconData icon;
  final bool showFrame;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null) {
      return PaintingPlaceholder(seed: seed, icon: icon, showFrame: showFrame, borderRadius: borderRadius);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showFrame ? Border.all(color: AppColors.divider, width: 6) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: kIsWeb
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  PaintingPlaceholder(seed: seed, icon: icon, showFrame: false, borderRadius: borderRadius),
            )
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  PaintingPlaceholder(seed: seed, icon: icon, showFrame: false, borderRadius: borderRadius),
            ),
    );
  }
}
