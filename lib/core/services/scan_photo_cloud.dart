import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'auth_service.dart';

/// Keeps a copy of each scan photo in Firebase Storage under the signed-in
/// account (`users/{uid}/scans/`), so every device on that account can show
/// it — the local copy only exists on the phone that took the photo.
class ScanPhotoCloud {
  ScanPhotoCloud._();

  static FirebaseStorage? _storageOverride;

  @visibleForTesting
  static set debugStorage(FirebaseStorage? storage) => _storageOverride = storage;

  static FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Uploads [jpeg] and returns its download URL, or null when there's no
  /// account to store it under.
  static Future<String?> upload(Uint8List jpeg) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final ref = _storage.ref('users/$uid/scans/${DateTime.now().microsecondsSinceEpoch}.jpg');
    await ref.putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Best-effort: a photo that's already gone, or belongs to another account
  /// (e.g. merged in from a guest session), is simply left alone.
  static Future<void> delete(String? url) async {
    if (url == null) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  static Future<void> deleteAllForCurrentUser() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      final listing = await _storage.ref('users/$uid/scans').listAll();
      await Future.wait(listing.items.map((item) => item.delete()));
    } catch (_) {}
  }
}
