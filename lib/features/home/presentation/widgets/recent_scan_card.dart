import 'dart:ui';

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
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ScannedImage(
              seed: painting.imageSeed,
              imagePath: painting.scannedImagePath,
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
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55)),
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
          ],
        ),
      ),
    );
  }
}
