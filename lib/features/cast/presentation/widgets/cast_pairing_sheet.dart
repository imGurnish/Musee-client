import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/cast/presentation/bloc/cast_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_event.dart';
import 'package:musee/features/cast/presentation/bloc/cast_state.dart';
import 'device_auth_confirm_sheet.dart';
import 'remote_eq_panel.dart';

class CastPairingSheet extends StatefulWidget {
  const CastPairingSheet({super.key});

  @override
  State<CastPairingSheet> createState() => _CastPairingSheetState();
}

class _CastPairingSheetState extends State<CastPairingSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isScanning = false;
  bool _showEq = false;
  double? _draggedVolume;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleQrScanned(String rawValue) {
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    // Can be: "musee://auth/device?token=<UUID>" or raw token or URL
    String token = rawValue.trim();
    final uri = Uri.tryParse(token);
    if (uri != null) {
      if (uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token']!;
      } else if (uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code']!;
        context.read<CastBloc>().add(JoinCastSessionByCodeEvent(sessionCode: code));
        return;
      }
    }

    if (token.isNotEmpty && mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => DeviceAuthConfirmSheet(token: token),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: BlocBuilder<CastBloc, CastState>(
        builder: (context, state) {
          final isCasting = state is CastActive;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Icon(
                      isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                      color: isCasting ? cs.primary : cs.onSurface,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isCasting ? 'Connected Cast Session' : 'Cast & Sync Playback',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (state is CastLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (isCasting)
                  _buildActiveSessionView(context, cs, state)
                else if (_isScanning)
                  _buildScannerView(context, cs)
                else
                  _buildConnectOptionsView(context, cs, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveSessionView(
    BuildContext context,
    ColorScheme cs,
    CastActive state,
  ) {
    final session = state.session;
    final code = session.sessionCode ?? '';
    final receivers = state.receivers;

    return BlocBuilder<PlayerCubit, PlayerViewState>(
      builder: (context, playerState) {
        final currentVolume = _draggedVolume ??
            state.remoteState?.volume ??
            playerState.volume;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session Code Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SESSION CODE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code.isNotEmpty ? code : session.id.substring(0, 6).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Connected Devices Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        receivers.isNotEmpty
                            ? Icons.tv_rounded
                            : Icons.devices_rounded,
                        size: 18,
                        color: receivers.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CONNECTED RECEIVERS (${receivers.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: receivers.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (receivers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: Colors.green,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (receivers.isNotEmpty)
                    ...receivers.map((device) {
                      final isCar = device.deviceName.toLowerCase().contains('car');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCar ? Icons.directions_car_rounded : Icons.tv_rounded,
                              size: 22,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.deviceName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Connected · Synchronized audio & EQ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waiting for TV or car browser to connect with code "$code"...',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Volume Control Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentVolume <= 0
                            ? Icons.volume_off_rounded
                            : currentVolume < 0.5
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RECEIVER VOLUME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: cs.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(currentVolume * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: currentVolume.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _draggedVolume = val);
                        context.read<CastBloc>().add(RemoteSetVolumeEvent(volume: val));
                      },
                      onChangeEnd: (val) {
                        setState(() => _draggedVolume = null);
                        context.read<CastBloc>().add(RemoteSetVolumeEvent(volume: val));
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Remote Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: () => context.read<CastBloc>().add(const RemotePreviousEvent()),
                ),
                IconButton.filled(
                  iconSize: 32,
                  icon: Icon(
                    playerState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: () {
                    if (playerState.playing) {
                      context.read<CastBloc>().add(const RemotePauseEvent());
                    } else {
                      context.read<CastBloc>().add(const RemotePlayEvent());
                    }
                  },
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: () => context.read<CastBloc>().add(const RemoteNextEvent()),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Remote EQ Toggle Button
            OutlinedButton.icon(
              icon: Icon(_showEq ? Icons.expand_less_rounded : Icons.tune_rounded),
              label: Text(_showEq ? 'Hide Equalizer' : 'Remote Equalizer & Audio'),
              onPressed: () => setState(() => _showEq = !_showEq),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            if (_showEq) ...[
              const SizedBox(height: 12),
              const RemoteEqPanel(),
            ],

            const SizedBox(height: 20),

            // Disconnect
            FilledButton.tonalIcon(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              label: const Text('Disconnect / End Cast', style: TextStyle(color: Colors.redAccent)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                context.read<CastBloc>().add(const EndCastSessionEvent());
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectOptionsView(
    BuildContext context,
    ColorScheme cs,
    CastState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state is CastError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 1. Cast from this phone
        FilledButton.icon(
          icon: const Icon(Icons.wifi_tethering_rounded),
          label: const Text('Start Cast Session'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            context.read<CastBloc>().add(const StartCastSessionEvent());
          },
        ),
        const SizedBox(height: 16),

        // 2. Scan TV / Car QR Code
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan TV / Car QR Code'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => setState(() => _isScanning = true),
        ),
        const SizedBox(height: 20),

        // Divider with OR
        Row(
          children: [
            Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR ENTER CODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3))),
          ],
        ),
        const SizedBox(height: 16),

        // Code Input Field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'e.g. JAZZ42',
                  prefixIcon: const Icon(Icons.pin_rounded),
                  filled: true,
                  fillColor: cs.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final code = _codeController.text
                    .trim()
                    .replaceAll(RegExp(r'[\s\-]'), '')
                    .toUpperCase();
                if (code.isNotEmpty) {
                  context.read<CastBloc>().add(JoinCastSessionByCodeEvent(sessionCode: code));
                }
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScannerView(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Point camera at TV or Car display',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _isScanning = false),
              child: const Text('Cancel'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 260,
            child: MobileScanner(
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.no_photography_rounded, size: 36, color: cs.error),
                        const SizedBox(height: 8),
                        Text(
                          'Camera unavailable on this device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please use the session code above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  _handleQrScanned(barcodes.first.rawValue!);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
