import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/sync/presentation/cubit/sync_cubit.dart';
import 'package:musee/core/sync/presentation/widgets/qr_code_display.dart';

/// Host view for managing sync session
/// Displays QR code for sharing and list of pending requests
class HostView extends StatelessWidget {
  final SyncState state;
  final bool isWide;

  const HostView({super.key, required this.state, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QR Code section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.cast_connected,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You are the Host',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Other devices can scan this QR code to join your sync session',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QR Code
                  if (state.hostQrCode != null)
                    QrCodeDisplay(data: state.hostQrCode!)
                  else
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  const SizedBox(height: 16),

                  // Copy link button
                  if (state.hostQrCode != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: state.hostQrCode!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Connection Link'),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pending join requests
          if (state.pendingJoinRequests?.isNotEmpty == true)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Requests',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...state.pendingJoinRequests!.map((deviceId) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.device_unknown,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text('Device: ${deviceId.substring(0, 8)}...'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () {
                                context.read<SyncCubit>().approveJoinRequest(
                                  deviceId,
                                );
                              },
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                context.read<SyncCubit>().rejectJoinRequest(
                                  deviceId,
                                );
                              },
                              tooltip: 'Reject',
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Info card
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Music playback on your device will be synchronized to all connected clients.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Host sync status card
          _buildSyncStatusCard(context, theme, colorScheme),

          const SizedBox(height: 16),

          // Cancel button to go back to mode selection
          if (!state.isConnected)
            TextButton.icon(
              onPressed: () {
                context.read<SyncCubit>().cancelSync();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Mode Selection'),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final connectedCount = state.connectedDevices.length;
    final isActive = connectedCount > 0;

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
                Icon(
                  Icons.sync,
                  color: isActive ? Colors.green : colorScheme.outline,
                  size: 24,
                ),
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
                    color: (isActive ? Colors.green : colorScheme.outline)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Broadcasting' : 'Waiting',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isActive ? Colors.green : colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Connected',
                  '$connectedCount',
                  connectedCount > 0 ? Colors.green : colorScheme.outline,
                  Icons.devices,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
                _buildStatItem(
                  context,
                  'Latency',
                  '${state.networkLatencyMs}ms',
                  _getLatencyColor(state.networkLatencyMs),
                  Icons.network_ping,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
                _buildStatItem(
                  context,
                  'Status',
                  state.connectionState.name,
                  isActive ? Colors.green : Colors.orange,
                  Icons.signal_cellular_alt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Color _getLatencyColor(int latencyMs) {
    if (latencyMs < 50) return Colors.green;
    if (latencyMs < 100) return Colors.lightGreen;
    if (latencyMs < 200) return Colors.orange;
    return Colors.red;
  }
}
