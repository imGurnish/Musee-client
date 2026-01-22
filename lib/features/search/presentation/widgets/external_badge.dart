import 'package:flutter/material.dart';

/// A badge widget that indicates content is from an external source.
/// Shows a purple-colored badge with "External" text or icon.
class ExternalBadge extends StatelessWidget {
  /// Whether to show a compact version (icon only).
  final bool compact;

  /// Size of the badge (affects icon and text size).
  final double size;

  const ExternalBadge({super.key, this.compact = false, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final color = Colors.purpleAccent;

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.public, size: size, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, size: size, color: color),
          const SizedBox(width: 4),
          Text(
            'External',
            style: TextStyle(
              fontSize: size * 0.75,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline badge for use in list tiles.
class ExternalInlineBadge extends StatelessWidget {
  const ExternalInlineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Colors.purpleAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            'Web',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
