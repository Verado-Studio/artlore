import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/painting.dart';

/// Whether [painting] has an image this device can actually show: a bundled
/// asset, a cloud copy, or a photo saved on this device. Only an old scan from
/// another phone that was never uploaded fails this check.
bool hasViewableImage(Painting painting) {
  if (painting.assetImagePath != null || painting.imageUrl != null) return true;
  final path = painting.scannedImagePath;
  if (path == null) return false;
  if (kIsWeb) return true;
  return File(ScannedImageStore.resolve(path)).existsSync();
}

/// Persists a scan's photo into the app's own permanent storage, instead of
/// leaving [Painting.scannedImagePath] pointing at the OS temp/cache file
/// `image_picker`/the camera handed back — which the OS is free to clear at
/// any time, silently breaking Collection's "open offline from cache"
/// requirement. No-op on web, which has no real filesystem to persist to.
class ScannedImageStore {
  ScannedImageStore._();

  static String? _scansDirPath;

  /// Caches the current scans folder so [resolve] can run synchronously
  /// while building image widgets. Call once at startup.
  static Future<void> init() async {
    if (kIsWeb) return;
    _scansDirPath = (await _scansDir()).path;
  }

  /// Maps a saved photo path onto this install's current scans folder. iOS
  /// moves the app's container on every update/reinstall, so a stored
  /// absolute path goes stale even though the file itself is still there
  /// under the same name.
  static String resolve(String path) {
    final dir = _scansDirPath;
    if (dir == null || !path.contains('/scans/')) return path;
    return '$dir/${path.substring(path.lastIndexOf('/') + 1)}';
  }

  static Future<Directory> _scansDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/scans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into permanent app storage and returns the new path.
  static Future<String> persist(String sourcePath) async {
    if (kIsWeb) return sourcePath;
    final dir = await _scansDir();
    final ext = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
    final destPath = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Deletes a previously-persisted scan photo, if it still exists. Safe to
  /// call with a path this store didn't create (e.g. an already-deleted or
  /// never-persisted one) — failures are swallowed since this is best-effort
  /// cleanup, not user-facing.
  static Future<void> delete(String? path) async {
    if (path == null || kIsWeb) return;
    try {
      final file = File(resolve(path));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup — an orphaned file costs a little disk space,
      // nothing user-visible breaks.
    }
  }
}
