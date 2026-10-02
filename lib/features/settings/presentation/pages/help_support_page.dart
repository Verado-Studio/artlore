import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const _faqs = [
    (
      question: 'How does scanning a painting work?',
      answer: 'Point your camera at a painting or upload a photo from your gallery. Our AI identifies the '
          'artwork and generates a story, hidden details, and more in seconds.',
    ),
    (
      question: "What's included in Pro?",
      answer: 'Pro unlocks unlimited scans, every hidden detail, audio narration, unlimited questions in Ask, '
          'and an unlimited collection.',
    ),
    (
      question: 'Can I use Artful offline?',
      answer: 'Paintings you have already scanned stay available offline in your Collection, but scanning a '
          'new painting needs an internet connection.',
    ),
    (
      question: 'How do I change my depth level?',
      answer: "Go to Settings → Depth level and pick Kid, Simple, or Art-lover. You can change it anytime, "
          "and switching depth on a result doesn't use another scan.",
    ),
  ];

  Future<void> _emailUs() async {
    final uri = Uri(scheme: 'mailto', path: 'ryan@veradostudio.com', query: 'subject=Support request');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Help & Support',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _ContactCard(
                    icon: Icons.mail_outline,
                    label: 'Email us',
                    subtitle: 'ryan@veradostudio.com',
                    onTap: _emailUs,
                  ),
                  const SizedBox(height: 28),
                  Text('Frequently asked questions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final faq in _faqs) _FaqTile(question: faq.question, answer: faq.answer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.icon, required this.label, required this.subtitle, required this.onTap});

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.ink),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        title: Text(question, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        expandedAlignment: Alignment.centerLeft,
        children: [Text(answer, style: Theme.of(context).textTheme.bodyMedium)],
      ),
    );
  }
}
