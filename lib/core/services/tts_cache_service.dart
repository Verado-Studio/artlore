import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// Plays "Listen" narration, caching the synthesized audio to disk after the
/// first play so replaying the same painting/depth doesn't re-synthesize.
///
/// File-based synthesis (`synthesizeToFile`) is Android/iOS only, so on web
/// this transparently falls back to direct on-device speech with no cache —
/// there's nothing costly to cache there anyway since browsers don't expose
/// file-synthesis at all.
class TtsCacheService {
  TtsCacheService._();

  static final FlutterTts _tts = FlutterTts();
  static final AudioPlayer _player = AudioPlayer();

  static bool get _supportsFileCache => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _voiceConfigured = false;

  /// Switches to one of iOS's "Siri" voices, if the device has one
  /// downloaded (Settings → Accessibility → Spoken Content → Voices) —
  /// same narration behavior, just a nicer-sounding voice. Runs once, and
  /// silently keeps the platform default if no Siri voice is available.
  static Future<void> _configureVoiceIfNeeded() async {
    if (_voiceConfigured || kIsWeb || !Platform.isIOS) return;
    _voiceConfigured = true;
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final siriVoices = voices
          .whereType<Map>()
          .where((v) => (v['name'] as String? ?? '').toLowerCase().contains('siri'))
          .toList()
        ..sort((a, b) {
          int rank(Map v) {
            final quality = (v['quality'] as String? ?? '').toLowerCase();
            if (quality.contains('premium')) return 0;
            if (quality.contains('enhanced')) return 1;
            return 2;
          }

          return rank(a).compareTo(rank(b));
        });
      if (siriVoices.isEmpty) return;
      final chosen = siriVoices.first;
      final identifier = chosen['identifier'] as String?;
      if (identifier != null && identifier.isNotEmpty) {
        await _tts.setVoice({'identifier': identifier});
      } else {
        await _tts.setVoice({
          'name': chosen['name'] as String? ?? '',
          'locale': chosen['locale'] as String? ?? '',
        });
      }
    } catch (_) {
      // No Siri voice on this device, or the platform call failed — keep
      // whatever voice flutter_tts already defaults to.
    }
  }

  /// Whether [pause]/[resume] actually pause and resume in place, rather than
  /// just stopping — true wherever playback goes through [_player] (the same
  /// platforms that support file caching), since `AudioPlayer.pause` keeps
  /// its position. There's no reliable resume-from-pause in `flutter_tts`
  /// itself, so the direct-speak fallback (web) doesn't offer this.
  static bool get supportsPause => _supportsFileCache;

  static Future<String> _cachePathFor(String cacheKey) async {
    final dir = await getTemporaryDirectory();
    final safe = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${dir.path}/tts_cache_$safe.wav';
  }

  /// Speaks [text], invoking [onDone] when playback finishes or fails.
  static Future<void> speak({required String cacheKey, required String text, required VoidCallback onDone}) async {
    await _configureVoiceIfNeeded();
    if (_supportsFileCache) {
      final path = await _cachePathFor(cacheKey);
      final file = File(path);
      if (!await file.exists()) {
        final synthesized = Completer<void>();
        _tts.setCompletionHandler(() {
          if (!synthesized.isCompleted) synthesized.complete();
        });
        _tts.setErrorHandler((_) {
          if (!synthesized.isCompleted) synthesized.complete();
        });
        await _tts.synthesizeToFile(text, path, true);
        await synthesized.future;
      }
      _player.onPlayerComplete.first.then((_) => onDone());
      await _player.play(DeviceFileSource(path));
    } else {
      _tts.setCompletionHandler(onDone);
      _tts.setErrorHandler((_) => onDone());
      await _tts.speak(text);
    }
  }

  static Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }

  /// Pauses in place — only meaningful when [supportsPause] is true; a no-op
  /// otherwise, since the fallback path has nothing to pause into.
  static Future<void> pause() async {
    if (_supportsFileCache) await _player.pause();
  }

  static Future<void> resume() async {
    if (_supportsFileCache) await _player.resume();
  }
}
