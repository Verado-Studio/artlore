import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingPermissionsView extends StatelessWidget {
  const OnboardingPermissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 132,
              height: 132,
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera_outlined, size: 56, color: AppColors.ink),
            ),
            const SizedBox(height: 32),
            Text(
              'Camera Access Needed',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'We need access to your camera to let you scan paintings and bring their stories to life.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
