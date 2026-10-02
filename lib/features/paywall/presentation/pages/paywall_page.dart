import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/purchases.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/pages/sign_in_page.dart';

/// Shows the Pro paywall as a dialog-style sheet: the triggering screen stays
/// visible (dimmed) behind it, with a close control over that reveal and a
/// rounded card below carrying the offer. [subtitle] ties the pitch to
/// whatever the user just tapped, e.g. "Unlock the 4 hidden details in this painting."
///
/// A guest sees the full offer immediately — sign-in is only required once
/// they actually tap to subscribe (see [_PaywallSheetState._continue]),
/// since Pro status is tied to a real account so it can follow them across
/// devices.
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
  Timer? _messageTimer;
  Package? _annualPackage;
  Package? _monthlyPackage;

  // A regular SnackBar targets the ScaffoldMessenger of the page that opened
  // this sheet, whose overlay sits *below* this modal route — so it renders
  // invisibly behind the sheet instead of on top of it. Showing feedback as
  // part of the sheet's own content avoids that entirely.
  String? _message;

  void _showMessage(String text) {
    _messageTimer?.cancel();
    setState(() => _message = text);
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  void initState() {
    super.initState();
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
    _messageTimer?.cancel();
    super.dispose();
  }

  /// Shows a "sign in to continue" dialog and, if the user taps through and
  /// signs in successfully, returns true. Cancelling either the dialog or the
  /// sign-in flow returns false so [_continue] can bail out.
  Future<bool> _promptSignIn() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Text(
          'Sign in to continue',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "You'll need an account so your Pro subscription follows you across devices.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft, fontSize: 14.5),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final signedIn = await Navigator.of(dialogContext).push<bool>(
                    MaterialPageRoute(builder: (_) => const SignInPage()),
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(signedIn == true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _continue() async {
    if (!AuthService.isSignedIn) {
      final signedIn = await _promptSignIn();
      if (!signedIn || !mounted) return;
    }

    final isYearly = _plan == 'yearly';
    final package = isYearly ? _annualPackage : _monthlyPackage;
    if (package == null) {
      _showMessage("Pricing isn't available right now — please try again shortly.");
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
        _showMessage("Purchase went through, but Pro isn't active — try Restore Purchases.");
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError && mounted) {
        _showMessage('Purchase error: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (mounted) _showMessage('Purchase error: $e');
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
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _RoundIcon(icon: Icons.close, onTap: () => Navigator.of(context).pop()),
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
              // The card's own height is set by fixed top/bottom offsets from the
              // screen edges, so it's often taller than the content needs — on a
              // tall phone that left everything bunched at the top with dead space
              // below. Centering the content (via the min-height constraint) fills
              // that space evenly instead, while still scrolling if it doesn't fit.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Go Pro',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 23, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => restorePurchases(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.clay,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text(
                                    'Restore Purchase',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/paywall.webp',
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (_message case final message?) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    for (final benefit in _benefits) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(benefit.icon, color: AppColors.ink, size: 19),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                benefit.label,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
                              ),
                            ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
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
                              : Text(
                                  isYearly ? 'Start Free Trial' : 'Continue',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                        ),
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
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
            const SizedBox(height: 6),
            Text(price, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
            const SizedBox(height: 2),
            Text(
              caption,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 12.5, color: selected ? AppColors.clay : AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
