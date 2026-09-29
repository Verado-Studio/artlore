import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/purchases.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_shell.dart';
import '../widgets/settings_tile.dart';
import 'help_support_page.dart';
import 'privacy_policy_page.dart';
import 'sign_in_page.dart';
import 'terms_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _depth = UserDataRepository.cachedDepth ?? 'Simple';
  User? _user;
  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((user) {
      setState(() => _user = user);
      _loadDepth();
    });
    _user = AuthService.currentUser;
    _loadDepth();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadDepth() async {
    final depth = await UserDataRepository.defaultDepth();
    if (!mounted) return;
    setState(() => _depth = depth);
  }

  Future<void> _handleSignInTap() async {
    final user = _user;
    if (user != null && !user.isAnonymous) {
      final label = user.displayName?.isNotEmpty == true ? user.displayName! : (user.email ?? 'this account');
      final signOut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign out?'),
          content: Text('You are signed in as $label.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sign out')),
          ],
        ),
      );
      if (signOut != true) return;
      await AuthService.signOut();
      return;
    }
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SignInPage()));
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and all your data — your Collection, Pro status, and '
          'preferences. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.friendlyMessage(e))));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete your account — please try again.")),
      );
    }
  }

  void _pickDepth() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RadioGroup<String>(
            groupValue: _depth,
            onChanged: (v) {
              setState(() => _depth = v!);
              UserDataRepository.setDefaultDepth(v!);
              Navigator.of(sheetContext).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final level in const ['Kid', 'Simple', 'Art-lover'])
                  RadioListTile<String>(
                    value: level,
                    title: Text(level),
                    activeColor: AppColors.clay,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final signedIn = user != null && !user.isAnonymous;
    final signedInLabel = !signedIn
        ? null
        : (user.displayName?.isNotEmpty == true ? user.displayName! : user.email);

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
                    onPressed: _goHome,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  SettingsTile(icon: Icons.tune, label: 'Default depth', value: _depth, onTap: _pickDepth),
                  SettingsTile(icon: Icons.restore, label: 'Restore purchases', onTap: () => restorePurchases(context)),
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy policy',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                  ),
                  SettingsTile(
                    icon: Icons.description_outlined,
                    label: 'Terms',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsPage())),
                  ),
                  SettingsTile(
                    icon: Icons.help_outline,
                    label: 'Contact support',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportPage())),
                  ),
                  const SettingsTile(icon: Icons.language_outlined, label: 'Language', value: 'English'),
                  SettingsTile(
                    icon: Icons.login,
                    label: signedIn ? 'Signed in' : 'Sign in',
                    value: signedInLabel,
                    onTap: _handleSignInTap,
                    showDivider: signedIn,
                  ),
                  if (signedIn)
                    SettingsTile(
                      icon: Icons.delete_outline,
                      label: 'Delete account',
                      color: AppColors.error,
                      onTap: _handleDeleteAccount,
                      showDivider: false,
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
