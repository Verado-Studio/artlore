import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';

import 'purchases.dart';
import 'user_data_repository.dart';

/// Thin wrapper around Firebase Authentication. Email/password, Google (web
/// popup, and native Android/iOS via google_sign_in) and Apple (Firebase's
/// generic OAuth `signInWithProvider` flow) are all real.
class AuthService {
  AuthService._();

  // The Android OAuth "web" client from android/app/google-services.json —
  // required so google_sign_in can mint an ID token Firebase will accept.
  // iOS reads its client ID straight from GoogleService-Info.plist.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '326099273958-fe4vg2apt5v3kctmlf3pgbp07nn7u2gq.apps.googleusercontent.com',
  );

  static FirebaseAuth? _authOverride;

  /// Lets widget tests substitute a fake (e.g. firebase_auth_mocks) instead
  /// of touching the real `FirebaseAuth.instance`, which needs a live
  /// Firebase app.
  @visibleForTesting
  static set debugAuth(FirebaseAuth? auth) => _authOverride = auth;

  static FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  /// Whether [currentUser] is a real (non-anonymous) account — the signal
  /// every "signed in?" decision in the UI should actually check, now that
  /// guests also carry a Firebase identity (see [ensureSignedIn]).
  static bool get isSignedIn => currentUser != null && !currentUser!.isAnonymous;

  /// Every device gets a stable Firebase identity at launch, even a guest
  /// who never signs in — anonymously. Without this, per-account server-side
  /// enforcement (the daily scan quota) has nothing to key on for guests,
  /// since Firestore rules can't trust a client-supplied id.
  static Future<void> ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } catch (_) {
      // Falls back to fully local (no Firestore sync, best-effort scan
      // quota) rather than blocking app launch — e.g. if the Anonymous
      // sign-in provider isn't enabled yet, or the device is offline.
    }
  }

  /// Every device is signed in anonymously from launch (see [ensureSignedIn])
  /// so its scans land in Firestore under that anonymous uid. A plain
  /// `createUserWithEmailAndPassword`/`signInWithCredential` call abandons
  /// that uid for a brand-new one, which is what was silently losing scans
  /// on sign-up — [_upgradeOrSignIn] links the new credential onto the
  /// *same* anonymous account instead, keeping its uid (and Firestore data)
  /// intact, unless that credential already belongs to a different,
  /// pre-existing account — in which case switching to that account (and
  /// leaving this device's anonymous data behind) is the correct behavior.
  static Future<UserCredential> _upgradeOrSignIn(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
      }
    }
    return _auth.signInWithCredential(credential);
  }

  static Future<void> signUp({required String email, required String password, required String displayName}) async {
    final credential = await _upgradeOrSignIn(EmailAuthProvider.credential(email: email, password: password));
    await credential.user?.updateDisplayName(displayName);
    await UserDataRepository.migrateLocalDataIfNeeded();
    await RevenueCatService.syncIdentity();
  }

  static Future<void> signIn({required String email, required String password}) async {
    // A plain sign-in is always into a pre-existing separate account, so
    // there's no anonymous uid worth preserving here — `_upgradeOrSignIn`
    // would just hit `email-already-in-use` and fall through to the same
    // `signInWithCredential` call anyway.
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await UserDataRepository.migrateLocalDataIfNeeded();
    await RevenueCatService.syncIdentity();
  }

  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          await current.linkWithPopup(GoogleAuthProvider());
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
          await _auth.signInWithPopup(GoogleAuthProvider());
        }
      } else {
        await _auth.signInWithPopup(GoogleAuthProvider());
      }
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(code: 'popup-closed-by-user', message: 'Sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _upgradeOrSignIn(credential);
    }
    await UserDataRepository.migrateLocalDataIfNeeded();
    await RevenueCatService.syncIdentity();
  }

  /// Apple's OAuth 2 provider, via Firebase's own generic `signInWithProvider`
  /// flow (a Custom Tab/`ASWebAuthenticationSession` redirect through Apple,
  /// landing back on Firebase's own auth-handler domain) — no separate
  /// native SDK needed. Requires the Apple provider to be configured in
  /// Firebase Console (Services ID, Team ID, Key ID, private key from an
  /// Apple Developer account); without that this throws.
  static Future<void> signInWithApple() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithProvider(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
        await _auth.signInWithProvider(provider);
      }
    } else {
      await _auth.signInWithProvider(provider);
    }
    await UserDataRepository.migrateLocalDataIfNeeded();
    await RevenueCatService.syncIdentity();
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await RevenueCatService.syncIdentity();
  }

  /// Turns a [FirebaseAuthException] into copy a user can actually act on.
  static String friendlyMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}
