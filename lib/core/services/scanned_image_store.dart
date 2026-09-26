import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists a scan's photo into the app's own permanent storage, instead of
/// leaving [Painting.scannedImagePath] pointing at the OS temp/cache file
/// `image_picker`/the camera handed back — which the OS is free to clear at
/// any time, silently breaking Collection's "open offline from cache"
/// requirement.
class ScannedImageStore {
  ScannedImageStore._();

  static Future<Directory> _scansDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/scans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into permanent app storage and returns the new path.
  static Future<String> persist(String sourcePath) async {
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
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup — an orphaned file costs a little disk space,
      // nothing user-visible breaks.
    }
  }
}
