import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'page_dots.dart';

/// Shared chrome (skip row + content + dots/bottom actions) used by the
/// "How it works", "Pick your level" and "Permissions" onboarding pages.
///
/// Each page renders this wrapper itself (rather than the parent PageView
/// swapping shared chrome in/out) so every page reports the exact same
/// size to the PageView — resizing the viewport mid-swipe/animation causes
/// Flutter's page-transition math to throw.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    required this.pageCount,
    required this.pageIndex,
    required this.bottomActions,
    this.showSkip = true,
    this.onSkip,
    this.backgroundColor = AppColors.background,
    this.skipColor = AppColors.ink,
    this.dotsActiveColor = AppColors.ink,
    this.dotsInactiveColor = AppColors.divider,
  });

  final Widget child;
  final int pageCount;
  final int pageIndex;
  final Widget bottomActions;
  final bool showSkip;
  final VoidCallback? onSkip;
  final Color backgroundColor;
  final Color skipColor;
  final Color dotsActiveColor;
  final Color dotsInactiveColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: child),
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (showSkip)
                            TextButton(
                              onPressed: onSkip,
                              style: TextButton.styleFrom(foregroundColor: skipColor),
                              child: const Text('Skip'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  bottomActions,
                  const SizedBox(height: 20),
                  PageDots(
                    count: pageCount,
                    index: pageIndex,
                    activeColor: dotsActiveColor,
                    inactiveColor: dotsInactiveColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
