import 'package:flutter/material.dart';

import '../../features/collection/presentation/pages/collection_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/result/presentation/pages/ask_page.dart';
import '../../features/scan/presentation/pages/camera_page.dart';
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

  @override
  void initState() {
    super.initState();
    AskContext.current.addListener(_onAskContextChanged);
  }

  @override
  void dispose() {
    AskContext.current.removeListener(_onAskContextChanged);
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
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTabSelected: (i) => setState(() => _index = i),
        onScanTap: _openCamera,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onTabSelected, required this.onScanTap});

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.background,
      height: 76,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', selected: currentIndex == 0, onTap: () => onTabSelected(0)),
          _NavItem(
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Collection',
            selected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: InkWell(
                onTap: onScanTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.amber.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.ink),
                ),
              ),
            ),
          ),
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
    );
  }
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
    final color = selected ? AppColors.clay : AppColors.inkSoft;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
