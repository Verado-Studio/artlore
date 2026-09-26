import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/purchases.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/pages/privacy_policy_page.dart';
import '../../../settings/presentation/pages/terms_page.dart';

/// Shows the Pro paywall as a dialog-style sheet: the triggering screen stays
/// visible (dimmed) behind it, with a close control over that reveal and a
/// rounded card below carrying the offer. [subtitle] ties the pitch to
/// whatever the user just tapped, e.g. "Unlock the 4 hidden details in this painting."
Future<void> showPaywallSheet(BuildContext context, {String subtitle = 'Unlock the full art experience.'}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PaywallSheet(subtitle: subtitle),
  );
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({required this.subtitle});

  final String subtitle;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  String _plan = 'yearly';
  bool _submitting = false;
  bool _closeReady = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _closeReady = true);
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _submitting = true);
    // No real store/RevenueCat integration yet — this just flips the local
    // "Pro" flag so the rest of the app's gating (scans, locked details,
    // Art-lover depth) behaves as if a purchase went through. Prices below
    // are placeholders too: per the brief, these should come from
    // RevenueCat's offerings once that's wired up, never hard-coded.
    await UserDataRepository.setPro(true);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text("You're on Pro now — enjoy the full experience.")),
    );
  }

  static const _benefits = [
    (icon: Icons.all_inclusive, label: 'Unlimited scans, every day'),
    (icon: Icons.auto_awesome, label: 'Every hidden detail unlocked'),
    (icon: Icons.menu_book_outlined, label: 'Full stories at every depth'),
    (icon: Icons.chat_bubble_outline, label: 'Ask unlimited questions, with audio narration'),
  ];

  @override
  Widget build(BuildContext context) {
    final isYearly = _plan == 'yearly';

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    opacity: _closeReady ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: _RoundIcon(
                      icon: Icons.close,
                      onTap: _closeReady ? () => Navigator.of(context).pop() : () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            top: 110,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Go Pro',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 22),
                    for (final benefit in _benefits) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(benefit.icon, color: AppColors.ink, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(benefit.label, style: Theme.of(context).textTheme.bodyLarge)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PlanCard(
                            title: 'Yearly',
                            price: '\$59.99 / yr',
                            caption: 'Save 85% · 3-day free trial',
                            selected: isYearly,
                            onTap: () => setState(() => _plan = 'yearly'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlanCard(
                            title: 'Monthly',
                            price: '\$9.99 / mo',
                            caption: 'Billed monthly',
                            selected: !isYearly,
                            onTap: () => setState(() => _plan = 'monthly'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (isYearly)
                      Text(
                        '3 days free, then \$59.99/year. Cancel anytime.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.inkSoft, fontStyle: FontStyle.italic),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _continue,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                                )
                              : Text(isYearly ? 'Start Free Trial' : 'Continue'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => restorePurchases(context),
                        child: const Text('Restore Purchases'),
                      ),
                    ),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsPage()),
                            ),
                            child: const Text('Terms'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                            ),
                            child: const Text('Privacy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber.withValues(alpha: 0.16) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.amber : AppColors.divider, width: selected ? 1.8 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(price, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? AppColors.clay : AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
