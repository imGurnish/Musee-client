import 'package:flutter/material.dart';

/// Visual indicator showing audio sync drift between devices
/// Displays both instantaneous and average drift
class DriftIndicator extends StatelessWidget {
  final int currentDriftMs;
  final int averageDriftMs;

  const DriftIndicator({
    super.key,
    required this.currentDriftMs,
    required this.averageDriftMs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine drift status
    final status = _getDriftStatus(averageDriftMs.abs());

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, color: status.color, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Sync Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Drift visualization
            _buildDriftVisualization(context, colorScheme),

            const SizedBox(height: 16),

            // Drift values
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDriftValue(
                  context,
                  'Current',
                  '${currentDriftMs}ms',
                  _getDriftColor(currentDriftMs.abs()),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
                _buildDriftValue(
                  context,
                  'Average',
                  '${averageDriftMs}ms',
                  _getDriftColor(averageDriftMs.abs()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriftVisualization(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    // Map drift to visualization (centered at 0, showing -500 to +500 ms range)
    final normalizedDrift = (currentDriftMs / 500.0).clamp(-1.0, 1.0);
    final indicatorPosition = (normalizedDrift + 1) / 2; // 0 to 1

    return Column(
      children: [
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Behind',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              'Synced',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              'Ahead',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Drift bar
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.green, Colors.orange],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Center line
                  Positioned(
                    left: constraints.maxWidth / 2 - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white),
                  ),
                  // Indicator
                  Positioned(
                    left: (constraints.maxWidth * indicatorPosition) - 8,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDriftValue(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  _DriftStatus _getDriftStatus(int absDriftMs) {
    if (absDriftMs < 50) {
      return _DriftStatus(label: 'Perfect', color: Colors.green);
    } else if (absDriftMs < 150) {
      return _DriftStatus(label: 'Good', color: Colors.lightGreen);
    } else if (absDriftMs < 300) {
      return _DriftStatus(label: 'Adjusting', color: Colors.orange);
    } else {
      return _DriftStatus(label: 'Out of Sync', color: Colors.red);
    }
  }

  Color _getDriftColor(int absDriftMs) {
    if (absDriftMs < 50) return Colors.green;
    if (absDriftMs < 150) return Colors.lightGreen;
    if (absDriftMs < 300) return Colors.orange;
    return Colors.red;
  }
}

class _DriftStatus {
  final String label;
  final Color color;

  _DriftStatus({required this.label, required this.color});
}
