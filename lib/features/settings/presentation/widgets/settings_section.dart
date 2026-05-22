import 'package:flutter/material.dart';

/// Reusable section header + card container for settings groups
class SettingsSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: _buildDivided(children, colorScheme),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDivided(List<Widget> items, ColorScheme colorScheme) {
    if (items.isEmpty) return [];
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(Divider(
          height: 1,
          thickness: 1,
          indent: 54,
          endIndent: 0,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ));
      }
    }
    return result;
  }
}
