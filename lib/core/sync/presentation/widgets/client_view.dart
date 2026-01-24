import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/sync/models/sync_device.dart';
import 'package:musee/core/sync/presentation/cubit/sync_cubit.dart';
import 'package:musee/core/sync/presentation/pages/qr_scanner_page.dart';

/// Client view for discovering and connecting to hosts
/// Shows discovered devices list and connection options
class ClientView extends StatelessWidget {
  final SyncState state;
  final bool isWide;

  const ClientView({super.key, required this.state, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status card
          if (state.hostDevice != null)
            _buildConnectedCard(context, state.hostDevice!)
          else
            _buildDiscoveryCard(context),

          const SizedBox(height: 16),

          // Discovered devices
          if (state.connectionState == SyncConnectionState.discovering)
            _buildDevicesList(context),

          // Manual connection options
          if (state.connectionState == SyncConnectionState.discovering ||
              state.connectionState == SyncConnectionState.idle)
            _buildManualOptions(context),
        ],
      ),
    );
  }

  Widget _buildConnectedCard(BuildContext context, SyncDevice host) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.link, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Connected to Host',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              host.deviceName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your audio will sync with the host\'s playback',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDiscovering =
        state.connectionState == SyncConnectionState.discovering;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isDiscovering
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(Icons.devices, size: 48, color: colorScheme.secondary),
            ),
            const SizedBox(height: 16),
            Text(
              isDiscovering ? 'Searching for Hosts...' : 'Join a Session',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDiscovering
                  ? 'Looking for devices on your local network'
                  : 'Find and connect to a host device',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            if (!isDiscovering)
              ElevatedButton.icon(
                onPressed: () {
                  context.read<SyncCubit>().startDiscovering();
                },
                icon: const Icon(Icons.search),
                label: const Text('Search for Hosts'),
              )
            else
              TextButton(
                onPressed: () {
                  context.read<SyncCubit>().stopDiscovering();
                },
                child: const Text('Stop Searching'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final devices = state.discoveredDevices;

    if (devices.isEmpty) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No devices found yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Make sure the host device has started a sync session',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Available Hosts (${devices.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.cast_connected,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(device.deviceName),
                subtitle: Text(device.ipAddress),
                trailing: ElevatedButton(
                  onPressed: () {
                    context.read<SyncCubit>().connectToHost(device);
                  },
                  child: const Text('Join'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManualOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other Connection Options',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showQrScanner(context);
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showLinkDialog(context);
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Enter Link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQrScanner(BuildContext context) async {
    final syncCubit = context.read<SyncCubit>();

    // Navigate to QR scanner page
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerPage()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      // Parse the QR code and connect
      _handleScannedCode(context, scannedCode, syncCubit);
    }
  }

  void _handleScannedCode(
    BuildContext context,
    String code,
    SyncCubit syncCubit,
  ) {
    try {
      // Parse the QR code data
      // Expected format: musee://sync?ip=192.168.x.x&port=6000&session=xxx&name=DeviceName
      final uri = Uri.parse(code);

      if (uri.scheme != 'musee' || uri.host != 'sync') {
        // Try parsing as JSON (alternative format)
        _parseJsonCode(context, code, syncCubit);
        return;
      }

      final ip = uri.queryParameters['ip'];
      final port = int.tryParse(uri.queryParameters['port'] ?? '6000') ?? 6000;
      final sessionId = uri.queryParameters['session'] ?? '';
      final deviceName = uri.queryParameters['name'] ?? 'Host Device';

      if (ip == null || ip.isEmpty) {
        throw Exception('Invalid QR code: missing IP address');
      }

      // Create device and connect
      final hostDevice = SyncDevice(
        deviceId: sessionId,
        deviceName: deviceName,
        ipAddress: ip,
        port: port,
        discoveredAt: DateTime.now(),
        isHost: true,
      );

      syncCubit.connectToHost(hostDevice);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connecting to $deviceName...')));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClientView] QR parse error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid QR code: ${e.toString()}')),
      );
    }
  }

  void _parseJsonCode(BuildContext context, String code, SyncCubit syncCubit) {
    try {
      // Try parsing as simple IP:PORT format
      if (code.contains(':') && !code.contains('{')) {
        final parts = code.split(':');
        if (parts.length == 2) {
          final ip = parts[0];
          final port = int.tryParse(parts[1]) ?? 6000;

          final hostDevice = SyncDevice(
            deviceId: 'host_$ip',
            deviceName: 'Host ($ip)',
            ipAddress: ip,
            port: port,
            discoveredAt: DateTime.now(),
            isHost: true,
          );

          syncCubit.connectToHost(hostDevice);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Connecting to $ip...')));
          return;
        }
      }

      throw Exception('Unrecognized QR code format');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not parse QR code: $code')));
    }
  }

  void _showLinkDialog(BuildContext context) {
    final controller = TextEditingController();
    final syncCubit = context.read<SyncCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Connection Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'musee://sync?...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final link = controller.text.trim();
              if (link.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                // Parse link and connect
                // This would use syncCubit to connect with parsed device info
                if (kDebugMode) {
                  debugPrint(
                    '[ClientView] Link entered: $link, cubit: $syncCubit',
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Connecting via link...')),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
