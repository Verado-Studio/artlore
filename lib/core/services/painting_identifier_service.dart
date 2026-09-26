import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/painting.dart';
import 'auth_service.dart';

/// Thrown when the AI backend can't identify the painting — callers should
/// show a friendly error rather than a crash.
class PaintingIdentificationException implements Exception {
  PaintingIdentificationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the server-side quota check rejects the scan because the
/// free-tier daily limit was already hit — distinct from other failures so
/// callers can show the paywall instead of a generic error.
class PaintingQuotaExceededException implements Exception {
  PaintingQuotaExceededException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when Gemini determines the photo isn't of a painting/artwork at
/// all — distinct from a low-confidence identification, which still is art,
/// just not a recognized piece.
class NotArtworkException implements Exception {
  NotArtworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Identifies a painting by writing a "pending" request document to
/// Firestore and waiting for a Cloud Function (triggered by that write) to
/// fill in the result. This avoids needing a publicly-invokable HTTP
/// endpoint — blocked by this project's org policy — while keeping the
/// Gemini API key server-side.
class PaintingIdentifierService {
  PaintingIdentifierService._();

  static const int _maxDimension = 1280;
  static const int _jpegQuality = 80;

  /// Firestore documents cap out at 1MiB; leave headroom under that for the
  /// base64 inflation (~4/3) plus the other fields on the document.
  static const int _maxBase64Length = 900000;

  static Future<Painting> identify(XFile image) async {
    final base64Image = await _compressToBase64(image);

    final docRef = FirebaseFirestore.instance.collection('identifyRequests').doc();
    await docRef.set({
      'status': 'pending',
      'imageBase64': base64Image,
      'mimeType': 'image/jpeg',
      'userId': AuthService.currentUser?.uid,
      'scanDateKey': _todayKey(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final data = await _waitForCompletion(docRef);
    final result = Map<String, dynamic>.from(data['result'] as Map? ?? {});
    if (result['isArtwork'] == false) {
      throw NotArtworkException("This doesn't look like a painting — try scanning an actual artwork.");
    }
    final storiesRaw = Map<String, dynamic>.from(result['stories'] as Map? ?? {});
    final shortStoriesRaw = Map<String, dynamic>.from(result['shortStories'] as Map? ?? {});
    final detailsRaw = (result['details'] as List? ?? []).cast<Map>();

    return Painting(
      title: result['title'] as String? ?? 'Untitled',
      artist: result['artist'] as String? ?? 'Unknown',
      year: result['year'] as String? ?? 'Unknown',
      movement: result['movement'] as String? ?? 'Unknown',
      museum: result['museum'] as String? ?? '—',
      confidence: ((result['confidence'] as num?) ?? 0).round(),
      imageSeed: image.path.hashCode,
      hook: result['hook'] as String? ?? '',
      stories: {
        'Kid': storiesRaw['Kid'] as String? ?? '',
        'Simple': storiesRaw['Simple'] as String? ?? '',
        'Art-lover': storiesRaw['Art-lover'] as String? ?? '',
      },
      shortStories: {
        if (shortStoriesRaw['Kid'] is String) 'Kid': shortStoriesRaw['Kid'] as String,
        if (shortStoriesRaw['Simple'] is String) 'Simple': shortStoriesRaw['Simple'] as String,
      },
      details: detailsRaw
          .map(
            (d) => PaintingDetail(
              x: (d['x'] as num).toDouble(),
              y: (d['y'] as num).toDouble(),
              title: d['title'] as String? ?? '',
              description: d['description'] as String? ?? '',
              locked: d['locked'] as bool? ?? false,
            ),
          )
          .toList(),
    );
  }

  static Future<Map<String, dynamic>> _waitForCompletion(DocumentReference<Map<String, dynamic>> docRef) async {
    late final Map<String, dynamic> data;
    try {
      data = await docRef
          .snapshots()
          .map((snap) => snap.data())
          .where((data) => data != null && data['status'] != 'pending')
          .cast<Map<String, dynamic>>()
          .first
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw PaintingIdentificationException('Could not reach the AI backend — check your connection and try again.');
    }

    if (data['status'] == 'quota_exceeded') {
      throw PaintingQuotaExceededException(
        data['error'] as String? ?? "You've reached today's free scan limit. Upgrade to Pro for unlimited scans.",
      );
    }
    if (data['status'] == 'error') {
      throw PaintingIdentificationException(data['error'] as String? ?? "Couldn't identify the painting — please try again.");
    }
    return data;
  }

  /// Local calendar date as "yyyy-MM-dd" — must match
  /// `UserDataRepository._todayKey`, since this is the bucket key the server
  /// resets the free-tier scan counter against.
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<String> _compressToBase64(XFile image) async {
    final rawBytes = await image.readAsBytes();
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw PaintingIdentificationException("That photo couldn't be processed — please try another.");
    }

    final resized = decoded.width > _maxDimension || decoded.height > _maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _maxDimension : null,
            height: decoded.height > decoded.width ? _maxDimension : null,
          )
        : decoded;

    Uint8List jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
    var base64Image = base64Encode(jpegBytes);

    // Fall back to a smaller/lower-quality pass if still too large (e.g. a
    // very detailed or unusually large source photo).
    if (base64Image.length > _maxBase64Length) {
      final smaller = img.copyResize(resized, width: 640);
      jpegBytes = Uint8List.fromList(img.encodeJpg(smaller, quality: 70));
      base64Image = base64Encode(jpegBytes);
    }

    if (base64Image.length > _maxBase64Length) {
      throw PaintingIdentificationException("That photo couldn't be processed — please try another.");
    }

    return base64Image;
  }
}
