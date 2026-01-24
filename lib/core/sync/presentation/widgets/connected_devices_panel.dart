import 'package:flutter/material.dart';
import 'package:musee/core/sync/models/sync_device.dart';

/// Panel showing connected devices in a sync session
class ConnectedDevicesPanel extends StatelessWidget {
  final List<SyncDevice> devices;
  final bool isHost;

  const ConnectedDevicesPanel({
    super.key,
    required this.devices,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.devices, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Connected Devices (${devices.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 48,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isHost
                          ? 'Waiting for devices to connect...'
                          : 'No other devices connected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: device.isHost
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                    child: Icon(
                      device.isHost ? Icons.cast_connected : Icons.devices,
                      color: device.isHost
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(device.deviceName),
                      if (device.isHost)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'HOST',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(device.ipAddress),
                  trailing: _buildSignalIndicator(device, colorScheme),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator(SyncDevice device, ColorScheme colorScheme) {
    // Signal strength indicator
    final strength = device.signalStrength ?? -50;
    final bars = _calculateBars(strength);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 4; i++)
          Container(
            width: 4,
            height: 8.0 + (i * 4.0),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < bars
                  ? _getSignalColor(bars)
                  : colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }

  int _calculateBars(int signalStrength) {
    // Signal strength ranges from -100 (weak) to 0 (strong)
    if (signalStrength > -50) return 4;
    if (signalStrength > -60) return 3;
    if (signalStrength > -70) return 2;
    return 1;
  }

  Color _getSignalColor(int bars) {
    switch (bars) {
      case 4:
        return Colors.green;
      case 3:
        return Colors.lightGreen;
      case 2:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}
