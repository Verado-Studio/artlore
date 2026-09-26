import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/ask_context.dart';
import '../../../../core/services/tts_cache_service.dart';
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

enum _ListenState { idle, playing, paused }

class _ResultPageState extends State<ResultPage> {
  String _depth = 'Simple';
  bool _saved = false;
  _ListenState _listenState = _ListenState.idle;
  bool _isPro = false;

  Painting get _painting => widget.painting;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    AskContext.current.value = _painting;
  }

  @override
  void dispose() {
    TtsCacheService.stop();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listenState == _ListenState.playing) {
      if (TtsCacheService.supportsPause) {
        await TtsCacheService.pause();
        if (mounted) setState(() => _listenState = _ListenState.paused);
      } else {
        await TtsCacheService.stop();
        if (mounted) setState(() => _listenState = _ListenState.idle);
      }
      return;
    }
    if (_listenState == _ListenState.paused) {
      await TtsCacheService.resume();
      if (mounted) setState(() => _listenState = _ListenState.playing);
      return;
    }
    if (!_isPro) {
      _openPaywall('Unlock audio narration with Pro.');
      return;
    }
    final text = _painting.storyFor(_depth, isPro: _isPro);
    if (text.isEmpty) return;
    setState(() => _listenState = _ListenState.playing);
    await TtsCacheService.speak(
      cacheKey: '${_painting.title}::$_depth',
      text: text,
      onDone: () {
        if (mounted) setState(() => _listenState = _ListenState.idle);
      },
    );
  }

  Future<void> _loadPreferences() async {
    final depth = await UserDataRepository.defaultDepth();
    final saved = await UserDataRepository.savedPaintings();
    final isPro = await UserDataRepository.isPro();
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: AspectRatio(
                  aspectRatio: 1.05,
                  child: ScannedImage(
                    seed: _painting.imageSeed,
                    imagePath: _painting.scannedImagePath,
                    icon: Icons.image_outlined,
                    showFrame: false,
                    borderRadius: 0,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundIcon(icon: Icons.arrow_back, onTap: _goHome),
                      Row(
                        children: [
                          _RoundIcon(icon: Icons.ios_share, onTap: () => showShareCardSheet(context, _painting)),
                          const SizedBox(width: 10),
                          _RoundIcon(
                            icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                            onTap: _toggleSaved,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
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
                  Text(
                    '${_painting.artist} • ${_painting.year}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  ConfidenceBadge(confidence: _painting.confidence),
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
                      TtsCacheService.stop();
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
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _PillActionButton(
                        icon: switch (_listenState) {
                          _ListenState.playing =>
                            TtsCacheService.supportsPause ? Icons.pause_circle_outlined : Icons.stop_circle_outlined,
                          _ListenState.paused => Icons.play_circle_outline,
                          _ListenState.idle => Icons.volume_up_outlined,
                        },
                        label: switch (_listenState) {
                          _ListenState.playing => TtsCacheService.supportsPause ? 'Pause' : 'Stop',
                          _ListenState.paused => 'Resume',
                          _ListenState.idle => 'Listen',
                        },
                        onTap: _toggleListen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Ask',
                        onTap: () {
                          if (!_isPro) {
                            _openPaywall('Unlock Ask to chat about this painting.');
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AskPage(painting: _painting)));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HiddenDetailsPage(painting: _painting)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.clay),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _painting.details.isEmpty
                                    ? 'No hidden details found'
                                    : '${_painting.details.length} hidden details found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (lockedCount > 0)
                                Text(
                                  '$lockedCount locked · unlock with Pro',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        if (_painting.details.isNotEmpty) const Icon(Icons.chevron_right, color: AppColors.inkSoft),
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

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}


class _PillActionButton extends StatelessWidget {
  const _PillActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
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
