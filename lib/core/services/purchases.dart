import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'auth_service.dart';
import 'user_data_repository.dart';

/// Wraps RevenueCat SDK setup and the account-identity syncing needed so a
/// purchase is always attributed to the right user — mirrors how
/// [UserDataRepository] already keys everything off the current Firebase uid.
class RevenueCatService {
  RevenueCatService._();

  // Public SDK key from RevenueCat (Project settings -> API keys -> Apple
  // App Store). Safe to embed client-side — this is RevenueCat's public key,
  // not a secret.
  static const _iosApiKey = 'appl_OCXBYVMRWcTymYpDhYASvnYNYbs';

  // TODO: paste the Android public SDK key from RevenueCat here (Project
  // settings -> API keys -> Google Play Store; starts with "goog_"). Until
  // this is set, RevenueCat stays unconfigured on Android — the paywall
  // falls back to its placeholder prices there and refuses checkout with
  // "Pricing isn't available right now" rather than granting Pro for free.
  static const _androidApiKey = '';

  static bool _configured = false;

  /// Call once at app startup, after Firebase/auth is ready so the initial
  /// `appUserID` is already the signed-in (or anonymous) Firebase uid.
  static Future<void> configure() async {
    if (kIsWeb || _configured) return;
    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    if (apiKey.isEmpty) return;
    final configuration = PurchasesConfiguration(apiKey)..appUserID = AuthService.currentUser?.uid;
    try {
      await Purchases.configure(configuration);
      _configured = true;
    } catch (_) {
      // Misconfigured key or unsupported platform — the app still works,
      // just without live pricing/purchases until this is fixed.
    }
  }

  /// Keeps RevenueCat's identity in sync with whichever Firebase account is
  /// current. Call after sign-in/sign-out so a purchase made under one
  /// account is never attributed to a different one.
  static Future<void> syncIdentity() async {
    if (kIsWeb || !_configured) return;
    final uid = AuthService.currentUser?.uid;
    try {
      if (uid != null) {
        await Purchases.logIn(uid);
      } else {
        await Purchases.logOut();
      }
    } catch (_) {
      // Best-effort — "Restore Purchases" remains available as a fallback.
    }
  }
}

/// Restores a real purchase from the store via RevenueCat and updates the
/// local Pro flag to match whatever entitlement comes back. Falls back to
/// reporting the already-known local status if RevenueCat isn't configured
/// on this platform yet (e.g. Android before its API key is set).
Future<void> restorePurchases(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  bool isPro;
  try {
    final customerInfo = await Purchases.restorePurchases();
    isPro = customerInfo.entitlements.active.containsKey('pro');
    await UserDataRepository.setPro(isPro);
  } catch (_) {
    isPro = await UserDataRepository.isPro();
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(isPro ? 'Your Pro subscription has been restored.' : 'No purchases found to restore.')),
  );
}
