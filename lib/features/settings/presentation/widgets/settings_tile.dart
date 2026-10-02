import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.subtitle,
    this.trailing,
    this.labelAction,
    this.onTap,
    this.showDivider = true,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// A second line under [label], e.g. the signed-in account's name.
  final String? subtitle;

  /// Replaces the default value text / chevron on the right.
  final Widget? trailing;

  /// Sits at the right end of the [label] line itself — unlike [trailing],
  /// which is centered between the label and [subtitle].
  final Widget? labelAction;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Overrides the icon/label color — used for destructive actions like
  /// "Delete account".
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          leading: Icon(icon, color: color ?? AppColors.ink, size: 24),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17, color: color),
                ),
              ),
              ?labelAction,
            ],
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft, fontSize: 15),
                ),
          trailing: labelAction != null ? null : trailing ?? (value != null
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
              : const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 22)),
        ),
        if (showDivider) const Divider(height: 1, indent: 56),
      ],
    );
  }
}
