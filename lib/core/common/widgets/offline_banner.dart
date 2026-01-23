/// Offline banner and connectivity-aware widgets.
/// Shows persistent offline status and allows interaction with cached content.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:musee/core/common/services/connectivity_service.dart';

/// Banner displayed when the app is offline.
/// Shows a persistent message with optional retry action.
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? customMessage;

  const OfflineBanner({super.key, this.onRetry, this.customMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customMessage ?? 'No internet connection. Playing from cache.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper widget that shows content with offline banner when disconnected.
/// Uses a ConnectivityService to monitor status.
class ConnectivityAwareWidget extends StatefulWidget {
  /// The main content to display
  final Widget child;

  /// Connectivity service to monitor
  final ConnectivityService connectivityService;

  /// Optional callback when connectivity is restored
  final VoidCallback? onReconnect;

  /// Whether to show the offline banner
  final bool showBanner;

  const ConnectivityAwareWidget({
    super.key,
    required this.child,
    required this.connectivityService,
    this.onReconnect,
    this.showBanner = true,
  });

  @override
  State<ConnectivityAwareWidget> createState() =>
      _ConnectivityAwareWidgetState();
}

class _ConnectivityAwareWidgetState extends State<ConnectivityAwareWidget> {
  StreamSubscription<ConnectivityStatus>? _subscription;
  ConnectivityStatus _status = ConnectivityStatus.unknown;

  @override
  void initState() {
    super.initState();
    _status = widget.connectivityService.currentStatus;
    _subscription = widget.connectivityService.statusStream.listen((status) {
      final wasOffline = _status == ConnectivityStatus.offline;
      setState(() {
        _status = status;
      });

      // Trigger reconnect callback if coming back online
      if (wasOffline && status == ConnectivityStatus.online) {
        widget.onReconnect?.call();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = _status == ConnectivityStatus.offline;

    return Column(
      children: [
        if (isOffline && widget.showBanner)
          OfflineBanner(
            onRetry: () async {
              await widget.connectivityService.checkConnectivity();
            },
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Simple connectivity indicator icon for app bars
class ConnectivityIndicator extends StatelessWidget {
  final ConnectivityStatus status;
  final double size;

  const ConnectivityIndicator({
    super.key,
    required this.status,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (status) {
      case ConnectivityStatus.online:
        return Icon(Icons.wifi, size: size, color: Colors.green);
      case ConnectivityStatus.offline:
        return Icon(Icons.wifi_off, size: size, color: theme.colorScheme.error);
      case ConnectivityStatus.unknown:
        return Icon(
          Icons.wifi_find,
          size: size,
          color: theme.colorScheme.outline,
        );
    }
  }
}
