import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/painting.dart';

/// Device-local storage. Serves as the source of truth for guests (no
/// Firebase account), and as the fallback [UserDataRepository] reads/writes
/// through when nobody's signed in. "Pro" stays local-only for now since
/// there's no real purchase flow to tie it to an account yet.
class AppPreferences {
  AppPreferences._();

  static const _keyIsPro = 'isPro';
  static const _keySavedPaintingsData = 'savedPaintingsData';
  static const _keyScansUsedToday = 'scansUsedToday';
  static const _keyScanDateKey = 'scanDateKey';
  static const _keyDefaultDepth = 'defaultDepth';
  static const _keyShownInitialPaywall = 'shownInitialPaywall';
  static const _keyOnboardingComplete = 'onboardingComplete';

  /// Free-tier scans allowed per day before the paywall kicks in — resets at
  /// local midnight.
  static const int freeScanLimit = 3;

  /// Free-tier collection size — only the most recent entries are kept once
  /// this many scans have been recorded. Pro keeps everything.
  static const int freeScanHistoryLimit = 5;

  static Future<bool> isPro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPro) ?? false;
  }

  static Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPro, value);
  }

  static Future<List<Painting>> savedPaintings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedPaintingsData) ?? const [];
    return raw.map((s) => Painting.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  static Future<void> setSavedPaintings(List<Painting> paintings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySavedPaintingsData, paintings.map((p) => jsonEncode(p.toJson())).toList());
  }

  /// Scans used since local midnight on [todayKey] (a "yyyy-MM-dd" date
  /// string) — a stale stored date means the day has rolled over, so the
  /// count is implicitly back to zero. Read-only fallback for the (broken-
  /// auth) case where there's no Firestore doc to read the server's count
  /// from at all; nothing writes through this path since the Cloud
  /// Function's quota transaction is the only authoritative writer.
  static Future<int> scansUsedToday(String todayKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyScanDateKey) != todayKey) return 0;
    return prefs.getInt(_keyScansUsedToday) ?? 0;
  }

  /// Whether the automatic "right after your first result" paywall has
  /// already been shown once. It should never trigger a second time.
  static Future<bool> hasShownInitialPaywall() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShownInitialPaywall) ?? false;
  }

  static Future<void> setShownInitialPaywall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShownInitialPaywall, true);
  }

  /// Whether the user has ever completed (or skipped) onboarding — it
  /// should never be shown again once this is true.
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  static Future<void> setCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, true);
  }

  static Future<String> defaultDepth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultDepth) ?? 'Simple';
  }

  static Future<void> setDefaultDepth(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultDepth, value);
  }
}
