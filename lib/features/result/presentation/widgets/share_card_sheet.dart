import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/painting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanned_image.dart';

/// Renders the on-screen share card to a PNG and opens the native share
/// sheet with that image attached, rather than sharing plain text.
Future<void> _shareCardImage(BuildContext context, GlobalKey boundaryKey, Painting painting) async {
  final renderObject = boundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();
    final file = XFile.fromData(bytes, mimeType: 'image/png', name: 'painting_share.png');
    await Share.shareXFiles(
      [file],
      text: '${painting.title} by ${painting.artist} — discovered with ${AppStrings.appName}.',
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text("Couldn't create the share image — please try again.")));
  }
}

void showShareCardSheet(BuildContext context, Painting painting) {
  final boundaryKey = GlobalKey();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            Text('Share card', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: boundaryKey,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    children: [
                      Expanded(
                        child: ScannedImage(
                          seed: painting.imageSeed,
                          imagePath: painting.scannedImagePath,
                          assetPath: painting.assetImagePath,
                          borderRadius: 16,
                          showFrame: false,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        painting.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        painting.hook,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.appName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _shareCardImage(context, boundaryKey, painting),
                icon: const Icon(Icons.ios_share),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    ),
  );
}
