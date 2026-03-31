import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const PaginationControls({
    super.key,
    required this.page,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final displayedPage = totalPages == 0
        ? 0
        : page + 1; // convert from 0-based for display
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        SizedBox(
          height: 36,
          width: 36,
          child: FilledButton.tonal(
            onPressed: page > 0 ? onPrev : null,
            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
            child: const Icon(Icons.chevron_left, size: 18),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$displayedPage / $totalPages',
            style: theme.textTheme.labelSmall,
          ),
        ),
        SizedBox(
          height: 36,
          width: 36,
          child: FilledButton.tonal(
            onPressed: page < (totalPages - 1) ? onNext : null,
            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
            child: const Icon(Icons.chevron_right, size: 18),
          ),
        ),
      ],
    );
  }
}
