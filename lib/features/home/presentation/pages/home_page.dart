import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../collection/presentation/pages/collection_page.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../result/presentation/pages/result_page.dart';
import '../../../scan/presentation/pages/camera_page.dart';
import '../../../scan/presentation/scan_flow.dart';
import '../widgets/recent_scan_card.dart';
import '../widgets/scan_action_section.dart';
import '../widgets/scans_left_pill.dart';
import '../widgets/upgrade_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _scansUsed = 0;
  List<Painting> _recentScans = [];
  String? _displayName;
  bool _isPro = false;
  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((_) => _loadUserData());
    _loadUserData();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final used = await UserDataRepository.scansUsedToday();
    final saved = await UserDataRepository.savedPaintings();
    final isPro = await UserDataRepository.isPro();
    final user = AuthService.currentUser;
    if (!mounted) return;
    setState(() {
      _scansUsed = used;
      _recentScans = saved.reversed.toList();
      _isPro = isPro;
      _displayName = user?.displayName?.trim().split(' ').first ?? user?.email?.split('@').first;
    });
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await startScanFlow(context, image: image);
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recentScans;
    final remaining = (AppPreferences.freeScanLimit - _scansUsed).clamp(0, AppPreferences.freeScanLimit);
    final name = _displayName;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              name == null ? 'Good morning! 👋' : 'Good morning, $name! 👋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep exploring the world of art.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            ScansLeftPill(remaining: remaining, total: AppPreferences.freeScanLimit, isPro: _isPro),
            if (!_isPro) ...[
              const SizedBox(height: 20),
              UpgradeBanner(
                onTap: () async {
                  await showPaywallSheet(context, subtitle: 'Unlock everything Pro has to offer.');
                  _loadUserData();
                },
              ),
            ],
            const SizedBox(height: 32),
            ScanActionSection(
              onScan: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraPage()));
                _loadUserData();
              },
              onUpload: _pickFromGallery,
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your recent scans', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionPage())),
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 190,
              child: recent.isEmpty
                  ? Center(
                      child: Text(
                        'Scan a painting to see it here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => RecentScanCard(
                        painting: recent[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ResultPage(painting: recent[i])),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
