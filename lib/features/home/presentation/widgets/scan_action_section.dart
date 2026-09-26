import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The bordered scan card at the top of Home: an outlined circle icon plus
/// "or upload from gallery" hint.
class ScanActionSection extends StatelessWidget {
  const ScanActionSection({super.key, required this.onScan, required this.onUpload});

  final VoidCallback onScan;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onScan,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 1.6),
              ),
              child: const Icon(Icons.camera_alt_outlined, color: AppColors.ink, size: 30),
            ),
            const SizedBox(height: 18),
            Text('Scan a painting', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onUpload,
              child: Text(
                'or upload from gallery',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
