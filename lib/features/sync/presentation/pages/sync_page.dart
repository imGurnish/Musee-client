import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';
import 'package:musee/core/sync/presentation/cubit/sync_cubit.dart';
import 'package:musee/core/sync/presentation/widgets/host_view.dart';
import 'package:musee/core/sync/presentation/widgets/client_view.dart';
import 'package:musee/core/sync/presentation/widgets/sync_mode_selector.dart';
import 'package:musee/core/sync/presentation/widgets/connected_devices_panel.dart';
import 'package:musee/core/sync/presentation/widgets/drift_indicator.dart';

/// Main Sync Page for multi-device audio synchronization
/// Supports both host and client modes with responsive layout
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Uses the global SyncCubit from MultiBlocProvider in main.dart
    return const _SyncPageContent();
  }
}

class _SyncPageContent extends StatefulWidget {
  const _SyncPageContent();

  @override
  State<_SyncPageContent> createState() => _SyncPageContentState();
}

class _SyncPageContentState extends State<_SyncPageContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Sync'),
        centerTitle: true,
        actions: [
          BlocBuilder<SyncCubit, SyncState>(
            buildWhen: (prev, curr) =>
                prev.connectionState != curr.connectionState,
            builder: (context, state) {
              if (state.isConnected) {
                return IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Disconnect',
                  onPressed: () {
                    context.read<SyncCubit>().disconnect();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 3),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: BlocBuilder<SyncCubit, SyncState>(
            builder: (context, state) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;

                  return CustomScrollView(
                    slivers: [
                      // Connection status
                      SliverToBoxAdapter(
                        child: _buildConnectionStatus(
                          context,
                          state,
                          colorScheme,
                        ),
                      ),

                      // Main content based on mode
                      if (state.syncMode == SyncMode.none)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: SyncModeSelector(
                            isWide: isWide,
                            onHostSelected: () {
                              context.read<SyncCubit>().startAsHost();
                            },
                            onClientSelected: () {
                              context.read<SyncCubit>().startDiscovering();
                            },
                          ),
                        )
                      else if (state.isHost)
                        SliverToBoxAdapter(
                          child: HostView(state: state, isWide: isWide),
                        )
                      else if (state.isClient)
                        SliverToBoxAdapter(
                          child: ClientView(state: state, isWide: isWide),
                        ),

                      // Drift indicator (when connected)
                      if (state.isConnected)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: DriftIndicator(
                              currentDriftMs: state.currentDriftMs,
                              averageDriftMs: state.averageDriftMs,
                            ),
                          ),
                        ),

                      // Connected devices panel (when connected)
                      if (state.isConnected)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ConnectedDevicesPanel(
                              devices: state.connectedDevices,
                              isHost: state.isHost,
                            ),
                          ),
                        ),

                      // Spacing at bottom
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(
    BuildContext context,
    SyncState state,
    ColorScheme colorScheme,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state.connectionState) {
      case SyncConnectionState.idle:
        statusColor = colorScheme.surfaceContainerHighest;
        statusText = 'Not connected';
        statusIcon = Icons.cloud_off_outlined;
        break;
      case SyncConnectionState.initializing:
        statusColor = colorScheme.tertiary;
        statusText = 'Initializing...';
        statusIcon = Icons.sync;
        break;
      case SyncConnectionState.ready:
        statusColor = colorScheme.primary;
        statusText = 'Ready to connect';
        statusIcon = Icons.check_circle_outline;
        break;
      case SyncConnectionState.discovering:
        statusColor = colorScheme.secondary;
        statusText = 'Discovering devices...';
        statusIcon = Icons.search;
        break;
      case SyncConnectionState.connecting:
        statusColor = colorScheme.secondary;
        statusText = 'Connecting...';
        statusIcon = Icons.link;
        break;
      case SyncConnectionState.connected:
        statusColor = colorScheme.primary;
        statusText = 'Connected';
        statusIcon = Icons.link;
        break;
      case SyncConnectionState.syncing:
        statusColor = Colors.green;
        statusText = 'Syncing playback';
        statusIcon = Icons.cloud_sync;
        break;
      case SyncConnectionState.error:
        statusColor = colorScheme.error;
        statusText = state.errorMessage ?? 'Error';
        statusIcon = Icons.error_outline;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
