/// Pull-to-refresh and auto-refresh mixin for pages.
/// Provides common refresh functionality with connectivity awareness.

library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:musee/core/common/services/connectivity_service.dart';

/// Mixin providing pull-to-refresh and auto-refresh functionality.
///
/// Usage:
/// ```dart
/// class MyPageState extends State<MyPage>
///     with RefreshablePageMixin<MyPage> {
///
///   @override
///   Future<void> onRefresh() async {
///     // Your refresh logic here
///   }
/// }
/// ```
mixin RefreshablePageMixin<T extends StatefulWidget> on State<T> {
  /// Override this to provide the refresh logic
  Future<void> onRefresh();

  /// Optional connectivity service for auto-refresh on reconnect
  ConnectivityService? get connectivityService => null;

  /// Whether a refresh is currently in progress
  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// Last refresh time for debouncing
  DateTime? _lastRefreshTime;

  /// Minimum time between refreshes (debounce)
  Duration get minRefreshInterval => const Duration(seconds: 2);

  /// Subscription to connectivity changes
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  /// Whether to auto-refresh when coming back online
  bool get autoRefreshOnReconnect => true;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    final service = connectivityService;
    if (service == null || !autoRefreshOnReconnect) return;

    _connectivitySubscription = service.statusStream.listen((status) {
      if (status == ConnectivityStatus.online && mounted) {
        // Debounce to avoid rapid refreshes
        final now = DateTime.now();
        if (_lastRefreshTime == null ||
            now.difference(_lastRefreshTime!) > minRefreshInterval) {
          triggerRefresh();
        }
      }
    });
  }

  /// Trigger a refresh with debouncing
  Future<void> triggerRefresh() async {
    if (_isRefreshing) return;

    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < minRefreshInterval) {
      return; // Debounce
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await onRefresh();
      _lastRefreshTime = DateTime.now();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Build a RefreshIndicator wrapper
  Widget buildRefreshable({required Widget child}) {
    return RefreshIndicator(onRefresh: triggerRefresh, child: child);
  }
}

/// Retry configuration for failed operations
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  static const standard = RetryConfig();
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
  );
}

/// Utility for retrying failed operations with exponential backoff
class RetryHelper {
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    RetryConfig config = RetryConfig.standard,
    bool Function(Object error)? shouldRetry,
  }) async {
    var attempt = 0;
    var delay = config.initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= config.maxAttempts) {
          rethrow;
        }

        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffMultiplier)
              .clamp(0, config.maxDelay.inMilliseconds)
              .toInt(),
        );
      }
    }
  }
}
