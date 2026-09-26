import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/painting_identifier_service.dart';
import '../../../../core/services/scanned_image_store.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/scanned_image.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../result/presentation/pages/result_page.dart';

const _funArtFacts = [
  "Van Gogh sold only one painting during his lifetime.",
  "The Mona Lisa has no eyebrows — it was fashionable to shave them off.",
  "A Jackson Pollock painting once sold for over \$200 million.",
  "Leonardo da Vinci was left-handed and wrote in mirror script.",
  "The paint on Rembrandt's canvases is sometimes inches thick.",
  "Edvard Munch's 'The Scream' has been stolen twice — and recovered twice.",
];

class AnalysingPage extends StatefulWidget {
  const AnalysingPage({super.key, this.image});

  final XFile? image;

  @override
  State<AnalysingPage> createState() => _AnalysingPageState();
}

class _AnalysingPageState extends State<AnalysingPage> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  Timer? _factTimer;
  int _factIndex = math.Random().nextInt(_funArtFacts.length);
  String? _error;

  @override
  void initState() {
    super.initState();
    _identify();
    _factTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _factIndex = (_factIndex + 1) % _funArtFacts.length);
    });
  }

  Future<void> _identify() async {
    final image = widget.image;
    if (image == null) {
      if (mounted) setState(() => _error = 'No photo to analyse.');
      return;
    }
    try {
      final painting = await PaintingIdentifierService.identify(image);
      final persistedPath = await ScannedImageStore.persist(image.path);
      final withImage = painting.withScannedImagePath(persistedPath);
      await UserDataRepository.recordScan(withImage);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultPage(painting: withImage)),
      );
    } on PaintingQuotaExceededException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
      showPaywallSheet(context, subtitle: e.message);
    } on PaintingIdentificationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't identify the painting — please try again.");
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _factTimer?.cancel();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ScannedImage(
                        seed: 0,
                        imagePath: widget.image?.path,
                        icon: error == null ? Icons.auto_awesome : Icons.error_outline,
                        showFrame: false,
                        borderRadius: 0,
                      ),
                      if (error == null)
                        AnimatedBuilder(
                          animation: _shimmer,
                          builder: (context, child) {
                            return ShaderMask(
                              blendMode: BlendMode.srcATop,
                              shaderCallback: (rect) {
                                final sweep = _shimmer.value * (rect.width + rect.height) * 2 - rect.height;
                                return LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.28),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0.35, 0.5, 0.65],
                                  transform: _SweepGradientTransform(sweep),
                                ).createShader(rect);
                              },
                              child: Container(color: Colors.black.withValues(alpha: 0.15)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                error ?? 'Analysing your artwork…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 14),
              if (error == null)
                SizedBox(
                  height: 44,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _funArtFacts[_factIndex],
                      key: ValueKey(_factIndex),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ),
                ),
              const Spacer(),
              if (error != null)
                ElevatedButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _identify();
                  },
                  child: const Text('Try again'),
                ),
              if (error != null) const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _goHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 1.4),
                ),
                child: Text(error == null ? 'Cancel' : 'Back home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SweepGradientTransform extends GradientTransform {
  const _SweepGradientTransform(this.offset);

  final double offset;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset, 0, 0);
  }
}
