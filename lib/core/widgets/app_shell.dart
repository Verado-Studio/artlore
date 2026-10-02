import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/collection/presentation/pages/collection_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/result/presentation/pages/ask_page.dart';
import '../../features/scan/presentation/pages/camera_page.dart';
import '../../features/scan/presentation/scan_flow.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../services/ask_context.dart';
import '../theme/app_colors.dart';

/// The persistent bottom-nav shell: Home, Collection, a raised scan button,
/// Ask and Profile (Settings).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    AskContext.current.addListener(_onAskContextChanged);
    // AppShell only ever mounts once onboarding/routing has settled (see
    // splash_page.dart / onboarding_page.dart), so it's a safe, stable place
    // to pick up a photo shared into the app from another app's share sheet
    // — both a cold start (the app wasn't running yet) and a warm one (the
    // app was already open) end up here.
    // Where the share plugin isn't built in (web, or iOS before its Share
    // Extension is set up) these calls throw; sharing just isn't available.
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleSharedMedia, onError: (_) {});
    _checkInitialSharedMedia();
  }

  Future<void> _checkInitialSharedMedia() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      if (media.isEmpty) return;
      await ReceiveSharingIntent.instance.reset();
      _handleSharedMedia(media);
    } catch (_) {}
  }

  void _handleSharedMedia(List<SharedMediaFile> media) {
    SharedMediaFile? image;
    for (final file in media) {
      if (file.type == SharedMediaType.image) {
        image = file;
        break;
      }
    }
    if (image == null || !mounted) return;
    startScanFlow(context, image: XFile(image.path));
  }

  @override
  void dispose() {
    AskContext.current.removeListener(_onAskContextChanged);
    _shareSub?.cancel();
    super.dispose();
  }

  void _onAskContextChanged() {
    if (mounted) setState(() {});
  }

  void _openCamera() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraPage()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const CollectionPage(),
      AskPage(painting: AskContext.current.value, embedded: true),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomBar(currentIndex: _index, onTabSelected: (i) => setState(() => _index = i)),
      floatingActionButton: _ScanButton(onTap: _openCamera),
      floatingActionButtonLocation: const _ScanButtonLocation(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onTabSelected});

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  static const double barHeight = 64;
  static const double bottomGap = 12;
  static const double buttonSize = 56;
  static const double buttonTop = -34;
  static const double _notchRadius = 36;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomGap + MediaQuery.of(context).padding.bottom),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            ClipPath(
              clipper: const _NotchedBarClipper(radius: 32, notchRadius: _notchRadius),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: AppColors.ink.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      selected: currentIndex == 0,
                      onTap: () => onTabSelected(0),
                    ),
                    _NavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Collection',
                      selected: currentIndex == 1,
                      onTap: () => onTabSelected(1),
                    ),
                    const Expanded(child: SizedBox()),
                    _NavItem(
                      icon: Icons.chat_bubble_outline,
                      activeIcon: Icons.chat_bubble,
                      label: 'Ask',
                      selected: currentIndex == 2,
                      onTap: () => onTabSelected(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profile',
                      selected: currentIndex == 3,
                      onTap: () => onTabSelected(3),
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

/// The raised scan button. It lives in the Scaffold's floating-button slot
/// rather than inside [_BottomBar]: it pokes above the bar, and taps outside
/// a widget's own bounds are dropped, so only its lower edge used to respond.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Shadow on the outer box so the tap ripple's clip can't cut it square.
    return Container(
      width: _BottomBar.buttonSize,
      height: _BottomBar.buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.amber.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: AppColors.amber,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Icon(Icons.camera_alt, color: Colors.white),
        ),
      ),
    );
  }
}

/// Centers the scan button over the bar's notch, from the bar's own fixed
/// geometry — so it sits in the same place it did inside the bar, and slides
/// out of view with the bar when the keyboard opens instead of riding on it.
class _ScanButtonLocation extends FloatingActionButtonLocation {
  const _ScanButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final barTop =
        geometry.scaffoldSize.height - geometry.minViewPadding.bottom - _BottomBar.bottomGap - _BottomBar.barHeight;
    return Offset(
      (geometry.scaffoldSize.width - geometry.floatingActionButtonSize.width) / 2,
      barTop + _BottomBar.buttonTop,
    );
  }
}

/// Cuts a circular notch out of the top-center of an otherwise fully rounded
/// bar, so the raised scan button nests into it instead of floating
/// disconnected above the bar with nothing behind it.
class _NotchedBarClipper extends CustomClipper<Path> {
  const _NotchedBarClipper({required this.radius, required this.notchRadius});

  final double radius;
  final double notchRadius;

  @override
  Path getClip(Size size) {
    final base = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final notch = Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, 0), radius: notchRadius));
    return Path.combine(PathOperation.difference, base, notch);
  }

  @override
  bool shouldReclip(covariant _NotchedBarClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.notchRadius != notchRadius;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.amber : AppColors.inkSoft;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
