import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/user_data_repository.dart';
import '../../../../core/widgets/scanned_image.dart';
import '../widgets/detail_sheet.dart';
import '../widgets/hotspot_dot.dart';

class HiddenDetailsPage extends StatefulWidget {
  const HiddenDetailsPage({super.key, required this.painting});

  final Painting painting;

  @override
  State<HiddenDetailsPage> createState() => _HiddenDetailsPageState();
}

class _HiddenDetailsPageState extends State<HiddenDetailsPage> {
  bool _isPro = false;

  Painting get _painting => widget.painting;

  @override
  void initState() {
    super.initState();
    _loadIsPro();
  }

  Future<void> _loadIsPro() async {
    final isPro = await UserDataRepository.isPro();
    if (mounted) setState(() => _isPro = isPro);
  }

  Future<void> _select(BuildContext context, int index) async {
    await showDetailSheet(context, _painting, _painting.details[index], isPro: _isPro);
    _loadIsPro();
  }

  @override
  Widget build(BuildContext context) {
    final details = _painting.details;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ScannedImage(
            seed: _painting.imageSeed,
            imagePath: _painting.scannedImagePath,
            assetPath: _painting.assetImagePath,
            showFrame: false,
            borderRadius: 0,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  for (var i = 0; i < details.length; i++)
                    Positioned(
                      left: details[i].x * constraints.maxWidth - 16,
                      top: details[i].y * constraints.maxHeight - 16,
                      child: HotspotDot(
                        number: i + 1,
                        locked: details[i].locked && !_isPro,
                        onTap: () => _select(context, i),
                      ),
                    ),
                ],
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
