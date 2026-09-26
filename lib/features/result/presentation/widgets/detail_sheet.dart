import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanned_image.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';

/// The detail bottom sheet shown when tapping a hotspot: the full detail
/// for an unlocked one, or a blurred preview + upgrade prompt for a locked
/// (Pro-only) one. [isPro] overrides [PaintingDetail.locked] so Pro users see
/// every detail unlocked regardless of what the mock data marks as locked.
Future<void> showDetailSheet(BuildContext context, Painting painting, PaintingDetail detail, {required bool isPro}) {
  final locked = detail.locked && !isPro;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.62),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ScannedImage(seed: painting.imageSeed, imagePath: painting.scannedImagePath, showFrame: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(painting.title, style: Theme.of(sheetContext).textTheme.titleMedium),
                      Text(
                        '${painting.artist} • ${painting.year}',
                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Icon(Icons.close, color: AppColors.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 20),
            Text(detail.title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(detail.description, style: Theme.of(sheetContext).textTheme.bodyMedium),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: locked
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: ScannedImage(
                              seed: painting.imageSeed + 2,
                              imagePath: painting.scannedImagePath,
                              showFrame: false,
                            ),
                          ),
                          Container(color: Colors.black.withValues(alpha: 0.3)),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, color: Colors.white, size: 26),
                                const SizedBox(height: 8),
                                Text(
                                  'Unlock with Pro to see the full detail.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ScannedImage(seed: painting.imageSeed + 2, imagePath: painting.scannedImagePath, showFrame: false),
              ),
            ),
            if (locked) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    final lockedCount = painting.details.where((d) => d.locked).length;
                    showPaywallSheet(
                      context,
                      subtitle: 'Unlock the $lockedCount hidden detail${lockedCount == 1 ? '' : 's'} in this painting.',
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink),
                  child: const Text('Upgrade to Pro'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
