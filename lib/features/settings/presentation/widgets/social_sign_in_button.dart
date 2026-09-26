import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Google + Apple sign-in, side by side. Apple goes through Firebase's
/// generic OAuth redirect flow (a Custom Tab / in-app browser to Apple's own
/// sign-in page), which works the same way on Android as on iOS — it isn't
/// limited to devices with a native Apple ID configured.
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({super.key, required this.onGoogleTap, required this.onAppleTap});

  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SocialSignInButton(icon: const GoogleMark(), label: 'Google', onTap: onGoogleTap)),
        const SizedBox(width: 12),
        Expanded(
          child: SocialSignInButton(
            icon: const Icon(Icons.apple, size: 20, color: Colors.white),
            label: 'Apple',
            dark: true,
            onTap: onAppleTap,
          ),
        ),
      ],
    );
  }
}

/// A "Continue with Google/Apple" style button.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({super.key, required this.icon, required this.label, required this.onTap, this.dark = false});

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? AppColors.ink : AppColors.surface,
          side: BorderSide(color: dark ? AppColors.ink : AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lightweight "G" mark standing in for the Google logo (no brand asset bundled).
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)),
        ),
      ),
    );
  }
}
