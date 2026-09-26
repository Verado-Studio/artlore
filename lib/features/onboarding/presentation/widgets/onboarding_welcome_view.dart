import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingWelcomeView extends StatelessWidget {
  const OnboardingWelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/hero-image.webp', fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.transparent, AppColors.ink],
                      stops: [0, 0.6, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every painting\nhas a secret.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Discover the story, the artist, and the hidden details behind every masterpiece.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
