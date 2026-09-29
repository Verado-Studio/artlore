import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/ask_context.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/scanned_image.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/depth_toggle.dart';
import '../widgets/share_card_sheet.dart';
import '../widgets/wrong_id_sheet.dart';
import 'ask_page.dart';
import 'hidden_details_page.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.painting});

  final Painting painting;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

enum _ListenState { idle, loading, playing, paused }

class _ResultPageState extends State<ResultPage> {
  String _depth = UserDataRepository.cachedDepth ?? 'Simple';
  bool _saved = false;
  bool _isFavorite = false;
  _ListenState _listenState = _ListenState.idle;
  bool _isPro = false;

  Painting get _painting => widget.painting;

  @override
  void initState() {
    super.initState();
    _isFavorite = _painting.isFavorite;
    _loadPreferences();
    AskContext.current.value = _painting;
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listenState == _ListenState.loading) {
      await TtsService.stop();
      if (mounted) setState(() => _listenState = _ListenState.idle);
      return;
    }
    if (_listenState == _ListenState.playing) {
      if (TtsService.supportsPause) {
        await TtsService.pause();
        if (mounted) setState(() => _listenState = _ListenState.paused);
      } else {
        await TtsService.stop();
        if (mounted) setState(() => _listenState = _ListenState.idle);
      }
      return;
    }
    if (_listenState == _ListenState.paused) {
      setState(() => _listenState = _ListenState.playing);
      await TtsService.resume();
      return;
    }
    if (!_isPro) {
      _openPaywall('Unlock audio narration with Pro.');
      return;
    }
    final text = _painting.storyFor(_depth, isPro: _isPro);
    if (text.isEmpty) return;
    setState(() => _listenState = _ListenState.loading);
    await TtsService.speak(
      text: text,
      onStart: () {
        if (mounted && _listenState == _ListenState.loading) {
          setState(() => _listenState = _ListenState.playing);
        }
      },
      onDone: () {
        if (mounted) setState(() => _listenState = _ListenState.idle);
      },
    );
  }

  Future<void> _loadPreferences() async {
    final results = await Future.wait([
      UserDataRepository.defaultDepth(),
      UserDataRepository.savedPaintings(),
      UserDataRepository.isPro(),
    ]);
    final depth = results[0] as String;
    final saved = results[1] as List<Painting>;
    final isPro = results[2] as bool;
    if (!mounted) return;
    setState(() {
      _depth = depth;
      _saved = saved.any((p) => p.title == _painting.title);
      _isPro = isPro;
    });
    await _maybeShowInitialPaywall(isPro);
  }

  /// Shows the paywall once, automatically, shortly after the very first
  /// result the user ever sees — never again after that.
  Future<void> _maybeShowInitialPaywall(bool isPro) async {
    if (isPro) return;
    final alreadyShown = await AppPreferences.hasShownInitialPaywall();
    if (alreadyShown) return;
    await AppPreferences.setShownInitialPaywall();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await _openPaywall('Unlock everything Pro has to offer.');
  }

  Future<void> _toggleSaved() async {
    final nowSaved = await UserDataRepository.toggleSavedPainting(_painting);
    if (!mounted) return;
    setState(() => _saved = nowSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(nowSaved ? 'Saved to your collection' : 'Removed from collection')),
    );
  }

  Future<void> _toggleFavorite() async {
    await UserDataRepository.toggleFavorite(_painting);
    if (!mounted) return;
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _openPaywall(String subtitle) async {
    await showPaywallSheet(context, subtitle: subtitle);
    final isPro = await UserDataRepository.isPro();
    if (mounted) setState(() => _isPro = isPro);
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowConfidence = _painting.isLowConfidence;
    final lockedCount = _isPro ? 0 : _painting.details.where((d) => d.locked).length;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Stack(
              children: [
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: AspectRatio(
                  aspectRatio: 1.05,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ScannedImage(
                        seed: _painting.imageSeed,
                        imagePath: _painting.scannedImagePath,
                        imageUrl: _painting.imageUrl,
                        assetPath: _painting.assetImagePath,
                        icon: Icons.image_outlined,
                        showFrame: false,
                        borderRadius: 0,
                      ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.8, 0.94, 1],
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                AppColors.background.withValues(alpha: 0.7),
                                AppColors.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _RoundIcon(icon: Icons.arrow_back, onTap: _goHome),
              ),
              Positioned(
                right: 14,
                top: 0,
                bottom: 0,
                child: Align(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RoundIcon(
                          icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                          iconColor: _isFavorite ? AppColors.clay : Colors.white,
                          onTap: _toggleFavorite,
                        ),
                        const SizedBox(height: 6),
                        _RoundIcon(
                          icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                          onTap: _toggleSaved,
                        ),
                        const SizedBox(height: 6),
                        _RoundIcon(icon: Icons.ios_share, onTap: () => showShareCardSheet(context, _painting)),
                        const SizedBox(height: 6),
                        _RoundIcon(
                          icon: switch (_listenState) {
                            _ListenState.playing =>
                              TtsService.supportsPause ? Icons.pause : Icons.stop,
                            _ListenState.paused => Icons.play_arrow,
                            _ListenState.loading || _ListenState.idle => Icons.volume_up_outlined,
                          },
                          loading: _listenState == _ListenState.loading,
                          onTap: _toggleListen,
                        ),
                        const SizedBox(height: 6),
                        _RoundIcon(
                          icon: Icons.chat_bubble_outline,
                          onTap: () {
                            if (!_isPro) {
                              _openPaywall('Unlock Ask to chat about this painting.');
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => AskPage(painting: _painting)));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lowConfidence) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text("We couldn't pin this one down", style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: 'Style · ${_painting.movement}'),
                      const _InfoChip(label: 'Technique · Oil on canvas'),
                      const _InfoChip(label: 'Mood · Contemplative'),
                      _InfoChip(label: 'Likely era · ${_painting.year}'),
                    ],
                  ),
                ] else ...[
                  Text(
                    _painting.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  _ArtistAndConfidenceRow(artist: _painting.artist, confidence: _painting.confidence),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: _ArrowLine(pointLeft: true)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'Year: ${_painting.year}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                        ),
                      ),
                      const Expanded(child: _ArrowLine(pointLeft: false)),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                DepthToggle(
                  options: const ['Simple', 'Art-lover', 'Kid'],
                  selected: _depth,
                  badged: _isPro ? const {} : const {'Art-lover'},
                  onSelected: (value) {
                    if (value == 'Art-lover' && !_isPro) {
                      _openPaywall('Unlock the full Art-lover story');
                      return;
                    }
                    if (_listenState != _ListenState.idle) {
                      TtsService.stop();
                      _listenState = _ListenState.idle;
                    }
                    setState(() => _depth = value);
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  '"${_painting.hook}"',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 14),
                Text(_painting.storyFor(_depth, isPro: _isPro), style: Theme.of(context).textTheme.bodyLarge),
                if (!_isPro && _painting.shortStories.containsKey(_depth)) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openPaywall('Unlock the full story at every depth.'),
                    child: Text(
                      'Showing the short version — Pro unlocks the full story.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.clay),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (_painting.details.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.clay),
                        const SizedBox(width: 14),
                        Text('No hidden details found', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => HiddenDetailsPage(painting: _painting)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_painting.details.length} hidden details found',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          if (lockedCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '$lockedCount locked · unlock with Pro',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => showWrongIdSheet(context, _painting),
                    child: Text('Wrong ID?', style: TextStyle(color: AppColors.inkSoft)),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// A circular translucent icon button. Consecutive icons in the result
/// page's side rail are stacked with no gap and a hairline seam so they read
/// as one fused chain of bubbles, matching the reference design.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.iconColor = Colors.white, this.loading = false});

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.6),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 19, color: iconColor),
      ),
    );
  }
}

/// Keeps the artist name and confidence badge on one row, badge at the right
/// end, only when both fit without truncating the artist name — otherwise
/// the badge drops to its own row below so the full name always shows.
/// Draws a single continuous line with an arrowhead fused to one end (no
/// gap, uniform color) — a separate Icon + Container line always left a seam
/// where the icon's own internal padding met the line.
class _ArrowLine extends StatelessWidget {
  const _ArrowLine({required this.pointLeft});

  final bool pointLeft;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArrowLinePainter(pointLeft: pointLeft),
      child: const SizedBox(height: 14, width: double.infinity),
    );
  }
}

class _ArrowLinePainter extends CustomPainter {
  _ArrowLinePainter({required this.pointLeft});

  final bool pointLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final midY = size.height / 2;
    const arrowSize = 5.0;

    if (pointLeft) {
      canvas.drawLine(Offset(arrowSize, midY), Offset(size.width, midY), paint);
      final path = Path()
        ..moveTo(arrowSize, midY - arrowSize)
        ..lineTo(0, midY)
        ..lineTo(arrowSize, midY + arrowSize);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(Offset(0, midY), Offset(size.width - arrowSize, midY), paint);
      final path = Path()
        ..moveTo(size.width - arrowSize, midY - arrowSize)
        ..lineTo(size.width, midY)
        ..lineTo(size.width - arrowSize, midY + arrowSize);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowLinePainter oldDelegate) => oldDelegate.pointLeft != pointLeft;
}

class _ArtistAndConfidenceRow extends StatelessWidget {
  const _ArtistAndConfidenceRow({required this.artist, required this.confidence});

  final String artist;
  final int confidence;

  double _textWidth(BuildContext context, String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final artistStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft);
    final badgeTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    final badge = ConfidenceBadge(confidence: confidence);

    return LayoutBuilder(
      builder: (context, constraints) {
        final artistWidth = _textWidth(context, artist, artistStyle);
        final badgeTextWidth = _textWidth(context, '$confidence% confidence', badgeTextStyle);
        // icon (14) + icon-text gap (5) + the badge's own horizontal padding (10 * 2)
        final badgeWidth = badgeTextWidth + 14 + 5 + 20;
        final fitsOnOneRow = artistWidth + 12 + badgeWidth <= constraints.maxWidth;

        if (fitsOnOneRow) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: Text(artist, style: artistStyle)),
                const Spacer(),
                badge,
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(artist, style: artistStyle),
            const SizedBox(height: 8),
            badge,
          ],
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
