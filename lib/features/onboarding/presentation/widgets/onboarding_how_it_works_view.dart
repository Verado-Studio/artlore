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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
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
              _StepRow(number: i + 1, step: _steps[i]),
              if (i != _steps.length - 1) const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});

  final int number;
  final ({IconData icon, String title, String subtitle}) step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: AppColors.pastelYellow, shape: BoxShape.circle),
          child: Icon(step.icon, color: AppColors.ink, size: 26),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                step.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
