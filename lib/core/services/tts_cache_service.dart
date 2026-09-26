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
