import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ScansLeftPill extends StatelessWidget {
  const ScansLeftPill({super.key, required this.remaining, required this.total, this.isPro = false});

  final int remaining;
  final int total;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPro ? Icons.workspace_premium_outlined : Icons.local_fire_department_outlined,
            size: 18,
            color: AppColors.clay,
          ),
          const SizedBox(width: 8),
          Text(
            isPro ? 'Pro · Unlimited scans' : '$remaining of $total free scans left',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
