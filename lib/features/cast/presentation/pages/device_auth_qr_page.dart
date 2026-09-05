import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:musee/features/cast/presentation/bloc/cast_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_event.dart';
import 'package:musee/features/cast/presentation/bloc/cast_state.dart';
import 'cast_receiver_page.dart';

class DeviceAuthQrPage extends StatefulWidget {
  final String? deviceName;

  const DeviceAuthQrPage({
    super.key,
    this.deviceName = 'Smart TV / Car Display',
  });

  @override
  State<DeviceAuthQrPage> createState() => _DeviceAuthQrPageState();
}

class _DeviceAuthQrPageState extends State<DeviceAuthQrPage> {
  @override
  void initState() {
    super.initState();
    context.read<CastBloc>().add(
          CreateDeviceAuthTokenEvent(deviceName: widget.deviceName),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Connect with Phone'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<CastBloc, CastState>(
        listener: (context, state) {
          if (state is CastActive && state.isReceiver) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => CastReceiverPage(sessionId: state.session.id),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CastLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CastAwaitingDeviceAuth) {
            final token = state.authToken;
            final deepLink = 'musee://auth/device?token=${token.token}';

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv_rounded, size: 48, color: cs.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Scan to Connect',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open the Musee app on your phone, tap the Cast icon, and select "Scan TV / Car QR Code".',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: QrImageView(
                          data: deepLink,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Waiting indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Waiting for phone confirmation...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state is CastError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to initialize connection: ${state.message}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<CastBloc>().add(
                            CreateDeviceAuthTokenEvent(deviceName: widget.deviceName),
                          );
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
