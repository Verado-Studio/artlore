import 'package:flutter/material.dart';

import 'user_data_repository.dart';

/// Checks the locally-stored entitlement and reports back to the user.
/// There's no real store integration yet (see the paywall purchase flow),
/// so this will report "no purchases found" until that's wired up — but the
/// UI/UX round-trip (loading state, feedback message) is real.
Future<void> restorePurchases(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final isPro = await UserDataRepository.isPro();
  await Future.delayed(const Duration(milliseconds: 600));
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(isPro ? 'Your Pro subscription has been restored.' : 'No purchases found to restore.')),
  );
}
