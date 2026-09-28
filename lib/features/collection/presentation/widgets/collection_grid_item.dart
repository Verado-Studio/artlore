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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ScannedImage(
                    seed: painting.imageSeed,
                    imagePath: painting.scannedImagePath,
                    borderRadius: 16,
                    showFrame: false,
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
          ),
          const SizedBox(height: 8),
          Text(
            painting.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            '${painting.artist} · ${painting.year}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.clay, fontWeight: FontWeight.w600),
          ),
          if (painting.movement.isNotEmpty && painting.movement != '—') ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.palette_outlined, size: 12, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    painting.movement,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
