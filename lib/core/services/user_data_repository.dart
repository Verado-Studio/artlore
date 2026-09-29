import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb, visibleForTesting;

import '../models/painting.dart';
import 'app_preferences.dart';
import 'auth_service.dart';
import 'scan_photo_cloud.dart';
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

  // The saved list is cached in memory (per account) so Home and Collection
  // show a new scan instantly instead of each re-downloading the whole list,
  // one network read after another.
  static List<Painting>? _savedCache;
  static String? _savedCacheUid;

  /// Bumps whenever the saved list changes, so screens that are already open
  /// (Home and Collection live on in the tab shell) can refresh right away.
  static final ValueNotifier<int> savedPaintingsChanged = ValueNotifier(0);

  static bool get _savedCacheValid => _savedCache != null && _savedCacheUid == AuthService.currentUser?.uid;

  static Future<List<Painting>> savedPaintings() async {
    if (_savedCacheValid) return List.of(_savedCache!);
    await _awaitMigration();
    final doc = _doc;
    final List<Painting> list;
    if (doc == null) {
      list = await AppPreferences.savedPaintings();
    } else {
      final snapshot = await doc.get();
      final raw = (snapshot.data()?['savedPaintingsData'] as List?) ?? const [];
      list = raw.map((e) => Painting.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    _savedCache = list;
    _savedCacheUid = AuthService.currentUser?.uid;
    return List.of(list);
  }

  static Future<void> setSavedPaintings(List<Painting> paintings) async {
    _savedCache = List.of(paintings);
    _savedCacheUid = AuthService.currentUser?.uid;
    savedPaintingsChanged.value++;
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
      if (p.imageUrl != painting.imageUrl) await ScanPhotoCloud.delete(p.imageUrl);
    }
    history.removeWhere((p) => p.title == painting.title);
    history.add(painting);
    // The last known Pro status is fine for trimming history; a fresh server
    // read here would hold up the scan result for no user-visible benefit.
    final proStatus = _proCacheValid ? _cachedPro! : await isPro();
    if (!proStatus && history.length > AppPreferences.freeScanHistoryLimit) {
      final overflowCount = history.length - AppPreferences.freeScanHistoryLimit;
      for (final p in history.take(overflowCount)) {
        await ScannedImageStore.delete(p.scannedImagePath);
        await ScanPhotoCloud.delete(p.imageUrl);
      }
      history.removeRange(0, overflowCount);
    }
    await setSavedPaintings(history);
  }

  /// Uploads a just-recorded scan's photo to the cloud and saves its URL on
  /// that entry. Runs in the background after the scan is saved, so a slow
  /// upload never holds up the result; if it fails, [backfillScanPhotos]
  /// retries later from the local copy.
  static Future<void> uploadScanPhoto(Painting painting, Uint8List jpeg) async {
    try {
      final url = await ScanPhotoCloud.upload(jpeg);
      if (url != null) await _attachImageUrl(painting, url);
    } catch (_) {}
  }

  static Future<void> _attachImageUrl(Painting painting, String url) async {
    final history = await savedPaintings();
    final index = history.indexWhere(
      (p) => p.title == painting.title && p.scannedImagePath == painting.scannedImagePath,
    );
    if (index == -1) {
      // The scan was removed or replaced while uploading.
      await ScanPhotoCloud.delete(url);
      return;
    }
    history[index] = history[index].withImageUrl(url);
    await setSavedPaintings(history);
  }

  static String? _backfilledUid;

  /// Uploads any scan photo that exists on this device but has no cloud copy
  /// yet — scans from before cloud storage, or an upload that failed. Runs at
  /// most once per account per app session.
  static Future<void> backfillScanPhotos() async {
    final uid = AuthService.currentUser?.uid;
    if (kIsWeb || uid == null || _backfilledUid == uid) return;
    _backfilledUid = uid;
    final history = await savedPaintings();
    for (final p in history) {
      final path = p.scannedImagePath;
      if (p.imageUrl != null || path == null) continue;
      try {
        final file = File(ScannedImageStore.resolve(path));
        if (!await file.exists()) continue;
        await uploadScanPhoto(p, await file.readAsBytes());
      } catch (_) {}
    }
  }

  /// Adds scans made as a guest on this device to the account just signed
  /// into. Signing in to an existing account switches identity, which would
  /// otherwise leave those scans behind on the guest account.
  static Future<void> mergeGuestScans(List<Painting> guestScans) async {
    if (guestScans.isEmpty) return;
    final history = await savedPaintings();
    for (final scan in guestScans) {
      if (!history.any((p) => p.title == scan.title)) history.add(scan);
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    history.sort((a, b) => (a.scannedAt ?? epoch).compareTo(b.scannedAt ?? epoch));
    final proStatus = await isPro();
    if (!proStatus && history.length > AppPreferences.freeScanHistoryLimit) {
      history.removeRange(0, history.length - AppPreferences.freeScanHistoryLimit);
    }
    await setSavedPaintings(history);
  }

  /// Flips the favorite star on a painting already in the collection.
  static Future<void> toggleFavorite(Painting painting) async {
    final history = await savedPaintings();
    final index = history.indexWhere((p) => p.title == painting.title);
    if (index == -1) return;
    history[index] = history[index].withFavorite(!history[index].isFavorite);
    await setSavedPaintings(history);
  }

  /// Removes [painting] from the user's collection entirely, including its
  /// persisted scan photo.
  static Future<void> deleteScan(Painting painting) async {
    final history = await savedPaintings();
    history.removeWhere((p) => p.title == painting.title);
    await setSavedPaintings(history);
    await ScannedImageStore.delete(painting.scannedImagePath);
    await ScanPhotoCloud.delete(painting.imageUrl);
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

  static bool? _cachedPro;
  static String? _cachedProUid;

  static bool get _proCacheValid => _cachedPro != null && _cachedProUid == AuthService.currentUser?.uid;

  static Future<bool> isPro() async {
    final value = await _fetchIsPro();
    _cachedPro = value;
    _cachedProUid = AuthService.currentUser?.uid;
    return value;
  }

  static Future<bool> _fetchIsPro() async {
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
    _cachedPro = value;
    _cachedProUid = AuthService.currentUser?.uid;
    await _awaitMigration();
    await AppPreferences.setPro(value);
    final doc = _doc;
    if (doc == null) return;
    await doc.set({'isPro': value}, SetOptions(merge: true));
  }

  // Kept in memory so every screen picks up a depth change the instant it's
  // made in Settings, instead of each one re-awaiting its own Firestore
  // round-trip (which was showing the old depth for a few seconds on the
  // very next Result screen).
  static String? _cachedDepth;

  /// The last known default depth, if any screen has already loaded or set
  /// one this session — lets a page seed its initial state synchronously
  /// instead of starting from a hardcoded guess while the real value loads.
  static String? get cachedDepth => _cachedDepth;

  static Future<String> defaultDepth() async {
    final cached = _cachedDepth;
    if (cached != null) return cached;
    await _awaitMigration();
    final doc = _doc;
    final value = doc == null
        ? await AppPreferences.defaultDepth()
        : (await doc.get()).data()?['defaultDepth'] as String? ?? 'Simple';
    _cachedDepth = value;
    return value;
  }

  static Future<void> setDefaultDepth(String value) async {
    _cachedDepth = value;
    await _awaitMigration();
    final doc = _doc;
    if (doc == null) return AppPreferences.setDefaultDepth(value);
    await doc.set({'defaultDepth': value}, SetOptions(merge: true));
  }

  /// Permanently deletes this account's Firestore document (saved paintings,
  /// Pro status, preferences) — called right before the Firebase Auth user
  /// itself is deleted, while the account can still authenticate the delete.
  static Future<void> deleteAllData() async {
    _savedCache = null;
    _cachedPro = null;
    final doc = _doc;
    if (doc == null) return;
    await doc.delete();
  }
}
