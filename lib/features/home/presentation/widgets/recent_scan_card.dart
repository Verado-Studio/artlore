import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanned_image.dart';

class RecentScanCard extends StatelessWidget {
  const RecentScanCard({super.key, required this.painting, required this.onTap});

  final Painting painting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 128,
              width: 128,
              child: ScannedImage(
                seed: painting.imageSeed,
                imagePath: painting.scannedImagePath,
                imageUrl: painting.imageUrl,
                assetPath: painting.assetImagePath,
                borderRadius: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              painting.title,
              maxLines: 2,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              painting.artist,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
