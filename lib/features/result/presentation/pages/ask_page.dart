import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/ask_context.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/painting_chat_service.dart';
import '../../../../core/services/painting_chat_store.dart';
import '../../../../core/services/scanned_image_store.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanned_image.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';

class AskPage extends StatefulWidget {
  const AskPage({super.key, required this.painting, this.embedded = false});

  final Painting painting;

  /// True when hosted inside the bottom-nav "Ask" tab, where a back arrow
  /// doesn't make sense since there's nothing to pop to.
  final bool embedded;

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _isPro = false;

  /// Which scanned painting is currently being chatted about — only ever
  /// changed from [widget.painting] in embedded mode (the bottom-nav Ask
  /// tab), where the picker below lets the user switch between their scans.
  Painting? _selected;
  List<Painting> _savedPaintings = [];

  /// Ask is Pro-only, capped at this many questions per painting.
  static const _maxQuestionsPerPainting = 10;

  Painting get _painting => _selected ?? widget.painting;

  List<ChatTurn> get _messages => PaintingChatStore.historyFor(_painting.title);

  int get _questionsAsked => _messages.where((m) => m.fromUser).length;

  static const _suggested = [
    'What was the artist feeling?',
    'What makes this painting significant?',
    'What inspired this painting?',
  ];

  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadIsPro();
    // The embedded Ask tab stays alive for the whole session, so it has to
    // follow later scans and sign-in changes rather than loading only once.
    if (widget.embedded) {
      _loadSavedPaintings();
      UserDataRepository.savedPaintingsChanged.addListener(_loadSavedPaintings);
      _authSubscription = AuthService.authStateChanges.listen((_) {
        _loadIsPro();
        _loadSavedPaintings();
      });
    }
  }

  Future<void> _loadIsPro() async {
    final isPro = await UserDataRepository.isPro();
    if (mounted) setState(() => _isPro = isPro);
  }

  Future<void> _loadSavedPaintings() async {
    final saved = await UserDataRepository.savedPaintings();
    if (!mounted) return;
    setState(() => _savedPaintings = saved.reversed.where(hasViewableImage).toList());
  }

  void _selectPainting(Painting painting) {
    if (painting.title == _painting.title) return;
    setState(() {
      _selected = painting;
      _sending = false;
    });
    AskContext.current.value = painting;
  }

  @override
  void didUpdateWidget(covariant AskPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.painting.title != widget.painting.title && mounted) {
      setState(() {
        _sending = false;
        _selected = null;
      });
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    if (!_isPro) {
      showPaywallSheet(context, subtitle: 'Unlock Ask to chat about this painting.');
      return;
    }
    if (_questionsAsked >= _maxQuestionsPerPainting) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You've reached the 10-question limit for this painting.")));
      return;
    }
    final title = _painting.title;
    setState(() {
      PaintingChatStore.append(title, ChatTurn(text, true));
      _sending = true;
    });
    _controller.clear();
    _scrollToEnd();

    try {
      final reply = await PaintingChatService.ask(
        painting: _painting,
        question: text,
        previousInteractionId: PaintingChatStore.interactionIdFor(title),
      );
      if (!mounted) return;
      setState(() {
        PaintingChatStore.append(title, ChatTurn(reply.answer, false));
        PaintingChatStore.setInteractionId(title, reply.interactionId);
      });
    } on PaintingChatException catch (e) {
      if (!mounted) return;
      setState(() => PaintingChatStore.append(title, ChatTurn(e.message, false)));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => PaintingChatStore.append(title, const ChatTurn("Couldn't get an answer — please try again.", false)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (widget.embedded) UserDataRepository.savedPaintingsChanged.removeListener(_loadSavedPaintings);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.embedded
              ? null
              : IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask about this painting',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        if (_isPro) ...[
                          const SizedBox(height: 8),
                          Text(
                            '$_questionsAsked / $_maxQuestionsPerPainting questions asked',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.embedded && _savedPaintings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _savedPaintings.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final painting = _savedPaintings[i];
                            final selected = painting.title == _painting.title;
                            return GestureDetector(
                              onTap: () => _selectPainting(painting),
                              child: SizedBox(
                                width: 60,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected ? AppColors.amber : Colors.transparent,
                                          width: 2.4,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: ScannedImage(
                                          seed: painting.imageSeed,
                                          imagePath: painting.scannedImagePath,
                                          imageUrl: painting.imageUrl,
                                          assetPath: painting.assetImagePath,
                                          showFrame: false,
                                          borderRadius: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      painting.title,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontSize: 10.5,
                                        color: selected ? AppColors.ink : AppColors.inkSoft,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (!_isPro)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: _LockedAskState(
                        onUnlock: () => showPaywallSheet(context, subtitle: 'Unlock Ask to chat about this painting.'),
                      ),
                    )
                  else ...[
                    _messages.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 80, bottom: 80),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Get answers about the artwork — try one of the suggestions below.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _messages.length + (_sending ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == _messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    children: [
                                      _AiAvatar(),
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkSoft),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final msg = _messages[i];
                              final bubble = Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                decoration: BoxDecoration(
                                  color: msg.fromUser ? AppColors.navy : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  msg.text,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(color: msg.fromUser ? Colors.white : AppColors.ink),
                                ),
                              );

                              if (msg.fromUser) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Align(alignment: Alignment.centerRight, child: bubble),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _AiAvatar(),
                                    Flexible(child: bubble),
                                  ],
                                ),
                              );
                            },
                          ),
                    if (_messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Suggested questions', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _suggested.map((q) => _SuggestedChip(label: q, onTap: () => _send(q))).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_isPro)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Type a question...',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.divider, width: 1.4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.divider, width: 1.4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
                            ),
                          ),
                          onSubmitted: _send,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _sending ? null : () => _send(_controller.text),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _sending ? AppColors.inkSoft : AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LockedAskState extends StatelessWidget {
  const _LockedAskState({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 36, color: AppColors.inkSoft),
            const SizedBox(height: 14),
            Text('Ask is a Pro feature', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Chat about this painting — up to 10 questions each — once you upgrade.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onUnlock,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink),
              child: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(right: 8, top: 2),
      decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
      child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
    );
  }
}

class _SuggestedChip extends StatelessWidget {
  const _SuggestedChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, size: 16, color: AppColors.teal),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal)),
          ],
        ),
      ),
    );
  }
}
