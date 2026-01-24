import 'package:flutter/material.dart';

/// Widget for selecting sync mode (Host or Client)
/// Displays two cards for user to choose their role
class SyncModeSelector extends StatelessWidget {
  final bool isWide;
  final VoidCallback onHostSelected;
  final VoidCallback onClientSelected;

  const SyncModeSelector({
    super.key,
    required this.isWide,
    required this.onHostSelected,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = [
      _buildModeCard(
        context: context,
        icon: Icons.cast_connected,
        title: 'Start as Host',
        description:
            'Create a sync session for other devices to join. '
            'You\'ll control the playback.',
        color: colorScheme.primary,
        onTap: onHostSelected,
      ),
      SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 16),
      _buildModeCard(
        context: context,
        icon: Icons.devices,
        title: 'Join as Client',
        description:
            'Find and connect to a host device. '
            'Your audio will sync with theirs.',
        color: colorScheme.secondary,
        onTap: onClientSelected,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Icon(Icons.cloud_sync_outlined, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Multi-Device Sync',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect multiple devices for perfectly synchronized audio playback',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 40),

          // Mode selection cards
          isWide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: content
                      .map((child) => Expanded(child: child))
                      .toList(),
                )
              : Column(children: content),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
