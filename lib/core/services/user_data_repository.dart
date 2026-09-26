import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/painting.dart';
import 'app_preferences.dart';
import 'auth_service.dart';
import 'scanned_image_store.dart';

/// Account-tied data: saved paintings, scans used, default depth.
///
/// Signed in -> read/write Firestore (`users/{uid}`), so it follows the
/// account across devices. Signed out -> falls back to the local
/// [AppPreferences] copy, same as before Firebase was wired up.
class UserDataRepository {
  UserDataRepository._();

  static FirebaseFirestore? _firestoreOverride;

  /// Lets widget tests substitute a fake (e.g. fake_cloud_firestore) instead
  /// of touching the real `FirebaseFirestore.instance`.
  @visibleForTesting
  static set debugFirestore(FirebaseFirestore? firestore) => _firestoreOverride = firestore;

  static FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  // `authStateChanges` listeners across the app (Home, Settings, Collection)
  // react to sign-in the instant Firebase Auth reports it — which can be
  // before the migration below has finished writing to Firestore. Every read
  // waits on this so it never sees a half-migrated (or pre-migration) doc.
  static Future<void>? _migrationInFlight;

  /// The first time a device signs in to an account with no cloud data yet,
  /// carry over whatever was tracked locally as a guest instead of losing it.
  static Future<void> migrateLocalDataIfNeeded() async {
    final future = _migrate();
    _migrationInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_migrationInFlight, future)) _migrationInFlight = null;
    }
  }

  static Future<void> _migrate() async {
    final doc = _doc;
    if (doc == null) return;
    final snapshot = await doc.get();
    if (snapshot.exists) return;
    final saved = await AppPreferences.savedPaintings();
    final todayKey = _todayKey();
    final scansUsedToday = await AppPreferences.scansUsedToday(todayKey);
    final defaultDepth = await AppPreferences.defaultDepth();
    final isPro = await AppPreferences.isPro();
    await doc.set({
      'savedPaintingsData': saved.map((p) => p.toJson()).toList(),
      'scansUsedToday': scansUsedToday,
      'scanDateKey': todayKey,
      'defaultDepth': defaultDepth,
      'isPro': isPro,
    });
  }

  /// Local calendar date as "yyyy-MM-dd" — the bucket key the free-tier scan
  /// counter resets against at local midnight.
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _awaitMigration() async {
    final inFlight = _migrationInFlight;
    if (inFlight != null) await inFlight;
  }

  static Future<List<Painting>> savedPaintings() async {
    await _awaitMigration();
    final doc = _doc;
    if (doc == null) return AppPreferences.savedPaintings();
    final snapshot = await doc.get();
    final list = (snapshot.data()?['savedPaintingsData'] as List?) ?? const [];
    return list.map((e) => Painting.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<void> setSavedPaintings(List<Painting> paintings) async {
    await _awaitMigration();
    final doc = _doc;
    if (doc == null) return AppPreferences.setSavedPaintings(paintings);
    await doc.set({'savedPaintingsData': paintings.map((p) => p.toJson()).toList()}, SetOptions(merge: true));
  }

  /// Adds [painting] to the saved list, or removes it if a painting with the
  /// same title is already saved.
  static Future<bool> toggleSavedPainting(Painting painting) async {
    final saved = await savedPaintings();
    final wasSaved = saved.any((p) => p.title == painting.title);
    if (wasSaved) {
      saved.removeWhere((p) => p.title == painting.title);
    } else {
      saved.add(painting);
    }
    await setSavedPaintings(saved);
    return !wasSaved;
  }

  /// Records every completed scan into the user's collection automatically
  /// (re-scanning the same painting just bumps it to most recent). Free
  /// accounts keep only their most recent [AppPreferences.freeScanHistoryLimit]
  /// entries; Pro accounts keep everything. Any scan photo that falls out of
  /// the kept history (replaced by a rescan, or trimmed off the free-tier
  /// cap) has its persisted file cleaned up too.
  static Future<void> recordScan(Painting painting) async {
    final history = await savedPaintings();
    final replaced = history.where((p) => p.title == painting.title);
    for (final p in replaced) {
      if (p.scannedImagePath != painting.scannedImagePath) await ScannedImageStore.delete(p.scannedImagePath);
    }
    history.removeWhere((p) => p.title == painting.title);
    history.add(painting);
    final proStatus = await isPro();
    if (!proStatus && history.length > AppPreferences.freeScanHistoryLimit) {
      final overflowCount = history.length - AppPreferences.freeScanHistoryLimit;
      for (final p in history.take(overflowCount)) {
        await ScannedImageStore.delete(p.scannedImagePath);
      }
      history.removeRange(0, overflowCount);
    }
    await setSavedPaintings(history);
  }

  /// Removes [painting] from the user's collection entirely, including its
  /// persisted scan photo.
  static Future<void> deleteScan(Painting painting) async {
    final history = await savedPaintings();
    history.removeWhere((p) => p.title == painting.title);
    await setSavedPaintings(history);
    await ScannedImageStore.delete(painting.scannedImagePath);
  }

  /// Scans used today (resets at local midnight) — read-only here. The only
  /// writer is the Cloud Function's quota transaction (see
  /// `checkAndConsumeScanQuota` in `functions/src/index.ts`), which is the
  /// authoritative check; this is just what the client reads back for
  /// instant UI (the Home "scans left" pill, the pre-scan paywall check).
  static Future<int> scansUsedToday() async {
    await _awaitMigration();
    final todayKey = _todayKey();
    final doc = _doc;
    if (doc == null) return AppPreferences.scansUsedToday(todayKey);
    final snapshot = await doc.get();
    final data = snapshot.data();
    if (data?['scanDateKey'] != todayKey) return 0;
    return (data?['scansUsedToday'] as int?) ?? 0;
  }

  static Future<bool> isPro() async {
    await _awaitMigration();
    final doc = _doc;
    if (doc == null) return AppPreferences.isPro();
    // Forces a server read rather than trusting the SDK's local cache —
    // this gates real Pro entitlements, so a stale cached "false" (e.g.
    // right after another read/write to the same doc) must never show a
    // paying user locked content. Falls back to cache only if genuinely
    // offline, same as the default behavior otherwise.
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await doc.get(const GetOptions(source: Source.server));
    } catch (_) {
      snapshot = await doc.get();
    }
    return (snapshot.data()?['isPro'] as bool?) ?? false;
  }

  static Future<void> setPro(bool value) async {
    await _awaitMigration();
    await AppPreferences.setPro(value);
    final doc = _doc;
    if (doc == null) return;
    await doc.set({'isPro': value}, SetOptions(merge: true));
  }

  static Future<String> defaultDepth() async {
    await _awaitMigration();
    final doc = _doc;
    if (doc == null) return AppPreferences.defaultDepth();
    final snapshot = await doc.get();
    return (snapshot.data()?['defaultDepth'] as String?) ?? 'Simple';
  }

  static Future<void> setDefaultDepth(String value) async {
    await _awaitMigration();
    final doc = _doc;
    if (doc == null) return AppPreferences.setDefaultDepth(value);
    await doc.set({'defaultDepth': value}, SetOptions(merge: true));
  }
}
