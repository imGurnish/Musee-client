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
}
