import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HotspotDot extends StatefulWidget {
  const HotspotDot({super.key, required this.number, required this.locked, required this.onTap});

  final int number;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<HotspotDot> createState() => _HotspotDotState();
}

class _HotspotDotState extends State<HotspotDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glow = 10 + _controller.value * 8;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 32 + glow,
                height: 32 + glow,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (widget.locked ? AppColors.ink : AppColors.gold).withValues(alpha: 0.22 * (1 - _controller.value * 0.6)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.locked ? Colors.white.withValues(alpha: 0.85) : AppColors.gold,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: widget.locked
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                    child: Text(
                      '${widget.number}',
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  )
                : Text(
                    '${widget.number}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
          ),
        ),
      ),
    );
  }
}
