import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../scan/presentation/pages/camera_page.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_how_it_works_view.dart';
import '../widgets/onboarding_permissions_view.dart';
import '../widgets/onboarding_pick_level_view.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_welcome_view.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;
  String? _selectedLevel = 'Simple';

  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _controller.animateToPage(index, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _finish() {
    AppPreferences.setCompletedOnboarding();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraPage()));
  }

  Future<void> _persistSelectedDepth() async {
    if (_selectedLevel != null) {
      await UserDataRepository.setDefaultDepth(_selectedLevel!);
    }
  }

  Future<void> _requestCameraAccess() async {
    await _persistSelectedDepth();
    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera access is off. You can enable it later in Settings.')),
        );
      }
    }
    if (!mounted) return;
    _finish();
  }

  Future<void> _skipCameraAccess() async {
    await _persistSelectedDepth();
    if (!mounted) return;
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final canGoNext = _index != 2 || _selectedLevel != null;

    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          OnboardingScaffold(
            pageCount: _pageCount,
            pageIndex: _index,
            onSkip: _finish,
            backgroundColor: AppColors.ink,
            skipColor: Colors.white,
            dotsActiveColor: Colors.white,
            dotsInactiveColor: Colors.white24,
            bottomActions: OnboardingPrimaryButton(
              label: 'Get started',
              onPressed: () => _goTo(1),
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.ink,
            ),
            child: const OnboardingWelcomeView(),
          ),
          OnboardingScaffold(
            pageCount: _pageCount,
            pageIndex: _index,
            onSkip: _finish,
            bottomActions: OnboardingPrimaryButton(label: 'Next', onPressed: () => _goTo(2)),
            child: const OnboardingHowItWorksView(),
          ),
          OnboardingScaffold(
            pageCount: _pageCount,
            pageIndex: _index,
            onSkip: _finish,
            bottomActions: OnboardingPrimaryButton(
              label: 'Next',
              onPressed: canGoNext ? () => _goTo(3) : null,
            ),
            child: OnboardingPickLevelView(
              selected: _selectedLevel,
              onSelected: (v) => setState(() => _selectedLevel = v),
            ),
          ),
          OnboardingScaffold(
            pageCount: _pageCount,
            pageIndex: _index,
            showSkip: false,
            bottomActions: Column(
              children: [
                OnboardingPrimaryButton(label: 'Allow camera', onPressed: _requestCameraAccess, showArrow: false),
                const SizedBox(height: 12),
                OnboardingSecondaryButton(label: 'Not now', onPressed: _skipCameraAccess),
              ],
            ),
            child: const OnboardingPermissionsView(),
          ),
        ],
      ),
    );
  }
}
