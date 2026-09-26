import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/user_data_repository.dart';
import '../../paywall/presentation/pages/paywall_page.dart';
import 'pages/analysing_page.dart';

/// Free-tier gating shared by every entry point into a scan (camera shutter,
/// gallery pick): a fast-path check against the daily counter (Firestore if
/// signed in, else local) so the paywall shows instantly once the free limit
/// is reached, without waiting on a network round trip. The actual counter
/// is only ever incremented server-side, by the Cloud Function that handles
/// the scan — this check never writes, so it can never double-count.
Future<void> startScanFlow(BuildContext context, {XFile? image}) async {
  final isPro = await UserDataRepository.isPro();
  final used = await UserDataRepository.scansUsedToday();
  if (!isPro && used >= AppPreferences.freeScanLimit) {
    if (!context.mounted) return;
    showPaywallSheet(context, subtitle: "You've hit today's free scan limit. Unlock unlimited scans with Pro.");
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalysingPage(image: image)));
}
