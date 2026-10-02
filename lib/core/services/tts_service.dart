import 'dart:io';

import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// Plays "Listen" narration by speaking directly, so audio starts as soon as
/// the engine begins — pre-synthesizing the whole story to a file first made
/// the first tap wait many seconds, and on iOS that file step could hang.
class TtsService {
  TtsService._();

  static final FlutterTts _tts = FlutterTts();
  static bool _configured = false;
  static String? _lastText;

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Only iOS resumes in place: its plugin continues a paused utterance when
  /// `speak` is called again. Elsewhere pausing would restart from the top.
  static bool get supportsPause => _isIOS;

  static Future<void> _configureIfNeeded() async {
    if (_configured) return;
    _configured = true;
    if (!_isIOS) return;
    try {
      await _tts.setSharedInstance(true);
      // The default category is silenced by the Silent switch, which made
      // narration seem broken on most iPhones.
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [IosTextToSpeechAudioCategoryOptions.duckOthers],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    } catch (_) {}
    await _useSiriVoiceIfAvailable();
  }

  /// Prefers a downloaded Siri voice (Settings → Accessibility → Spoken
  /// Content → Voices); silently keeps the platform default otherwise.
  static Future<void> _useSiriVoiceIfAvailable() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      int rank(Map v) {
        final quality = (v['quality'] as String? ?? '').toLowerCase();
        if (quality.contains('premium')) return 0;
        if (quality.contains('enhanced')) return 1;
        return 2;
      }

      final siriVoices = voices
          .whereType<Map>()
          .where((v) => (v['name'] as String? ?? '').toLowerCase().contains('siri'))
          .toList()
        ..sort((a, b) => rank(a).compareTo(rank(b)));
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
    } catch (_) {}
  }

  /// Speaks [text]. [onStart] fires when audio actually begins (use it to
  /// end a loading state); [onDone] fires when it finishes or fails.
  static Future<void> speak({
    required String text,
    required VoidCallback onStart,
    required VoidCallback onDone,
  }) async {
    await _configureIfNeeded();
    _lastText = text;
    _tts.setStartHandler(onStart);
    _tts.setCompletionHandler(onDone);
    _tts.setErrorHandler((_) => onDone());
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    _lastText = null;
    await _tts.stop();
  }

  static Future<void> pause() async {
    if (supportsPause) await _tts.pause();
  }

  static Future<void> resume() async {
    final text = _lastText;
    if (supportsPause && text != null) await _tts.speak(text);
  }
}
