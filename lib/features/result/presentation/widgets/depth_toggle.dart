import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class DepthToggle extends StatelessWidget {
  const DepthToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.badged = const {},
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Set<String> badged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final active = option == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: option == options.last ? 0 : 10),
            child: GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active ? AppColors.ink : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: active ? Colors.white : AppColors.ink,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                    if (badged.contains(option)) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.workspace_premium, size: 14, color: AppColors.gold),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
