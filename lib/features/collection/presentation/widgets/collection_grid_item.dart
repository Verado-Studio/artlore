import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanned_image.dart';

class CollectionGridItem extends StatelessWidget {
  const CollectionGridItem({
    super.key,
    required this.painting,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final Painting painting;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ScannedImage(
              seed: painting.imageSeed,
              imagePath: painting.scannedImagePath,
              imageUrl: painting.imageUrl,
              assetPath: painting.assetImagePath,
              borderRadius: 0,
              showFrame: false,
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(color: const Color(0xFFCFCBC6).withValues(alpha: 0.72)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          painting.title,
                          maxLines: 2,
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.inkSoft),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                painting.year,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: InkWell(
                onTap: onToggleFavorite,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: Icon(
                    painting.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 15,
                    color: painting.isFavorite ? AppColors.clay : Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
