import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/painting_chat_service.dart';
import '../../../../core/services/painting_chat_store.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
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

  /// Ask is Pro-only, capped at this many questions per painting.
  static const _maxQuestionsPerPainting = 10;

  List<ChatTurn> get _messages => PaintingChatStore.historyFor(widget.painting.title);

  int get _questionsAsked => _messages.where((m) => m.fromUser).length;

  static const _suggested = [
    'What was the artist feeling?',
    'What makes this painting significant?',
    'What inspired this painting?',
  ];

  @override
  void initState() {
    super.initState();
    _loadIsPro();
  }

  Future<void> _loadIsPro() async {
    final isPro = await UserDataRepository.isPro();
    if (mounted) setState(() => _isPro = isPro);
  }

  @override
  void didUpdateWidget(covariant AskPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.painting.title != widget.painting.title && mounted) {
      setState(() => _sending = false);
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    if (!_isPro) {
      showPaywallSheet(context, subtitle: 'Unlock Ask to chat about this painting.');
      return;
    }
    if (_questionsAsked >= _maxQuestionsPerPainting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've reached the 10-question limit for this painting.")),
      );
      return;
    }
    final title = widget.painting.title;
    setState(() {
      PaintingChatStore.append(title, ChatTurn(text, true));
      _sending = true;
    });
    _controller.clear();
    _scrollToEnd();

    try {
      final reply = await PaintingChatService.ask(
        painting: widget.painting,
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
      setState(() => PaintingChatStore.append(title, const ChatTurn("Couldn't get an answer — please try again.", false)));
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask about this painting',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get answers about the artwork, artist, style, and more.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
          if (!_isPro)
            Expanded(child: _LockedAskState(onUnlock: () => showPaywallSheet(context, subtitle: 'Unlock Ask to chat about this painting.')))
          else ...[
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Ask anything about "${widget.painting.title}" — try one of the suggestions below.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: msg.fromUser ? Colors.white : AppColors.ink,
                              ),
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
        ],
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
            Text(
              'Ask is a Pro feature',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
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
