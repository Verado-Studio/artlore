import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingPickLevelView extends StatelessWidget {
  const OnboardingPickLevelView({super.key, required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  static const _levels = [
    (
      key: 'Kid',
      icon: Icons.emoji_emotions_outlined,
      cardColor: AppColors.pastelGreen,
      iconColor: AppColors.iconGreen,
      subtitle: 'Simple & fun',
      age: 'ages 6+',
    ),
    (
      key: 'Simple',
      icon: Icons.wb_sunny_outlined,
      cardColor: AppColors.pastelBlue,
      iconColor: AppColors.iconBlue,
      subtitle: 'Clear & concise',
      age: 'ages 12+',
    ),
    (
      key: 'Art-lover',
      icon: Icons.school_outlined,
      cardColor: AppColors.pastelCoral,
      iconColor: AppColors.iconCoral,
      subtitle: 'In-depth & detailed',
      age: 'ages 16+',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your depth',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              "Select the level of detail you'd like. You can change this later in settings.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            for (final level in _levels) ...[
              _LevelCard(
                icon: level.icon,
                cardColor: level.cardColor,
                iconColor: level.iconColor,
                title: level.key,
                subtitle: level.subtitle,
                age: level.age,
                selected: selected == level.key,
                onTap: () => onSelected(level.key),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.icon,
    required this.cardColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.age,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color cardColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String age;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.ink : Colors.transparent, width: 1.8),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.ink, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  Text(age, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
