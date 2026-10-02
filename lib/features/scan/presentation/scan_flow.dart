import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

/// Loads a bundled demo painting asset and runs it through the normal scan
/// flow — see [startScanFlow]. On Android/iOS the asset is copied into a
/// real temp file (an [XFile] backed purely by in-memory bytes has no real
/// filesystem path, which later steps need); on web it's passed straight
/// through as in-memory bytes since there's no filesystem there at all.
Future<void> startSampleScanFlow(BuildContext context, String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final name = assetPath.split('/').last;
  if (!context.mounted) return;
  if (kIsWeb) {
    await startScanFlow(context, image: XFile.fromData(bytes, name: name));
    return;
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  if (!context.mounted) return;
  await startScanFlow(context, image: XFile(file.path));
}
