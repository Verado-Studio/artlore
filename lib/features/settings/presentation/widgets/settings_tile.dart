import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          leading: Icon(icon, color: AppColors.ink, size: 24),
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17),
          ),
          trailing: value != null
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft, fontSize: 15),
                  ),
                )
              : const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 22),
        ),
        if (showDivider) const Divider(height: 1, indent: 56),
      ],
    );
  }
}
