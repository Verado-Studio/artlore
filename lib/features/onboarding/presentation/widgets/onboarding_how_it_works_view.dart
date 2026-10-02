import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingHowItWorksView extends StatelessWidget {
  const OnboardingHowItWorksView({super.key});

  static const _steps = [
    (
      icon: Icons.camera_alt_outlined,
      title: 'Snap',
      subtitle: 'Take a photo or upload a painting.',
    ),
    (
      icon: Icons.camera_outlined,
      title: 'Discover the story',
      subtitle: 'AI identifies the artwork and gives you a detailed story.',
    ),
    (
      icon: Icons.camera_alt_outlined,
      title: 'Unlock hidden details',
      subtitle: 'Explore fascinating details, colours, and more.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text(
              'Get the story in 3 simple steps.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 40),
            for (var i = 0; i < _steps.length; i++) ...[
              _StepRow(step: _steps[i]),
              if (i != _steps.length - 1) const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final ({IconData icon, String title, String subtitle}) step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.pastelYellow, shape: BoxShape.circle),
              child: Icon(step.icon, color: AppColors.ink, size: 26),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                step.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 74),
          child: Text(
            step.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
          ),
        ),
      ],
    );
  }
}
