import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/services/purchases.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';

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
  Package? _annualPackage;
  Package? _monthlyPackage;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _closeReady = true);
    });
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || !mounted) return;
      setState(() {
        _annualPackage = current.annual ?? current.getPackage('\$rc_annual');
        _monthlyPackage = current.monthly ?? current.getPackage('\$rc_monthly');
      });
    } catch (_) {
      // Offerings unavailable (RevenueCat not configured on this platform
      // yet, or a network hiccup) — plan cards just keep their placeholder
      // prices, and checkout below refuses to proceed without a real
      // package rather than silently granting Pro for free.
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    final isYearly = _plan == 'yearly';
    final package = isYearly ? _annualPackage : _monthlyPackage;
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pricing isn't available right now — please try again shortly.")),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final isPro = result.customerInfo.entitlements.active.containsKey('pro');
      await UserDataRepository.setPro(isPro);
      if (!mounted) return;
      if (isPro) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text("You're on Pro now — enjoy the full experience.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Purchase went through, but Pro isn't active — try Restore Purchases.")),
        );
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase error: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 18),
                    for (final benefit in _benefits) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(benefit.icon, color: AppColors.ink, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(benefit.label, style: Theme.of(context).textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _PlanCard(
                              title: 'Yearly',
                              price: _annualPackage?.storeProduct.priceString != null
                                  ? '${_annualPackage!.storeProduct.priceString} / yr'
                                  : '\$59.99 / yr',
                              caption: 'Save 85% · 3-day free trial',
                              selected: isYearly,
                              onTap: () => setState(() => _plan = 'yearly'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PlanCard(
                              title: 'Monthly',
                              price: _monthlyPackage?.storeProduct.priceString != null
                                  ? '${_monthlyPackage!.storeProduct.priceString} / mo'
                                  : '\$9.99 / mo',
                              caption: 'Billed monthly',
                              selected: !isYearly,
                              onTap: () => setState(() => _plan = 'monthly'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isYearly)
                      Text(
                        '3 days free, then ${_annualPackage?.storeProduct.priceString ?? '\$59.99'}/year. Cancel anytime.',
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
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
            const SizedBox(height: 6),
            Text(price, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              caption,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11, color: selected ? AppColors.clay : AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
