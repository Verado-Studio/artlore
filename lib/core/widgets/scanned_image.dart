import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/scanned_image_store.dart';
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
    this.imageUrl,
    this.assetPath,
    this.icon = Icons.image_outlined,
    this.showFrame = true,
    this.borderRadius = 20,
  });

  final int seed;

  /// The photo saved on this device, if this device took it.
  final String? imagePath;

  /// The cloud copy of the photo — used when this device doesn't have it,
  /// e.g. a scan made on another phone signed in to the same account.
  final String? imageUrl;

  /// A bundled app asset to show when there's no real photo — see
  /// [Painting.assetImagePath].
  final String? assetPath;
  final IconData icon;
  final bool showFrame;
  final double borderRadius;

  Widget _placeholder() => PaintingPlaceholder(seed: seed, icon: icon, showFrame: false, borderRadius: borderRadius);

  Widget? _photo() {
    final path = imagePath;
    final url = imageUrl;
    Widget network(String src) =>
        Image.network(src, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());

    if (path != null) {
      // On web the local "path" is a temporary blob URL that dies on reload,
      // so the cloud copy is the reliable one there.
      if (kIsWeb) return network(url ?? path);
      final file = File(ScannedImageStore.resolve(path));
      if (file.existsSync() || url == null) {
        return Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
      }
      return network(url);
    }
    if (url != null) return network(url);
    final asset = assetPath;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo();
    if (photo == null) {
      return PaintingPlaceholder(seed: seed, icon: icon, showFrame: showFrame, borderRadius: borderRadius);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showFrame ? Border.all(color: AppColors.divider, width: 6) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo,
    );
  }
}
