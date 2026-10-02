import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/art_facts.dart';
import '../../../../core/constants/sample_images.dart';
import '../../../../core/models/painting.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/scanned_image_store.dart';
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
  final int _factIndex = math.Random().nextInt(artFacts.length);
  late final StreamSubscription<User?> _authSubscription;
  late final StreamSubscription<User?> _profileSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((_) => _loadUserData());
    // The name is saved just after sign-up completes, so catch it arriving
    // rather than keeping whatever was there at sign-in.
    _profileSubscription = AuthService.userChanges.listen((user) {
      if (mounted) setState(() => _displayName = _firstNameOf(user));
    });
    UserDataRepository.savedPaintingsChanged.addListener(_loadUserData);
    _loadUserData();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _profileSubscription.cancel();
    UserDataRepository.savedPaintingsChanged.removeListener(_loadUserData);
    super.dispose();
  }

  static String? _firstNameOf(User? user) {
    final name = user?.displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  Future<void> _loadUserData() async {
    final results = await Future.wait([
      UserDataRepository.scansUsedToday(),
      UserDataRepository.savedPaintings(),
      UserDataRepository.isPro(),
    ]);
    final used = results[0] as int;
    final saved = results[1] as List<Painting>;
    final isPro = results[2] as bool;
    final user = AuthService.currentUser;
    unawaited(UserDataRepository.backfillScanPhotos());
    if (!mounted) return;
    setState(() {
      _scansUsed = used;
      _recentScans = saved.reversed.where(hasViewableImage).toList();
      _isPro = isPro;
      _displayName = _firstNameOf(user);
    });
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await startScanFlow(context, image: image);
  }

  Future<void> _pickSample(String assetPath) async {
    await startSampleScanFlow(context, assetPath);
    _loadUserData();
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
                Text('Recently Scanned', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionPage())),
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ArtFactCard(fact: artFacts[_factIndex]),
            const SizedBox(height: 20),
            if (recent.isEmpty)
              SizedBox(
                height: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No paintings yet — try a sample:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          for (final asset in sampleImages) ...[
                            Expanded(child: _HomeSampleThumb(asset: asset, onTap: () => _pickSample(asset))),
                            if (asset != sampleImages.last) const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 230,
                child: ListView.separated(
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

class _HomeSampleThumb extends StatelessWidget {
  const _HomeSampleThumb({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(asset, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      ),
    );
  }
}

class _ArtFactCard extends StatelessWidget {
  const _ArtFactCard({required this.fact});

  final String fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.pastelYellow, shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.clayDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Did you know?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(fact, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
