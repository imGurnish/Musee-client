/// Stream-based connectivity monitoring service.
/// Provides real-time network status updates and connectivity checks.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connectivity status
enum ConnectivityStatus { online, offline, unknown }

/// Abstract connectivity service interface
abstract class ConnectivityService {
  /// Stream of connectivity status changes
  Stream<ConnectivityStatus> get statusStream;

  /// Current connectivity status
  ConnectivityStatus get currentStatus;

  /// Check if currently online
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  /// Manually check connectivity
  Future<bool> checkConnectivity();

  /// Dispose resources
  void dispose();
}

/// Implementation using connectivity_plus package
class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;

  ConnectivityServiceImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  @override
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  void _init() {
    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final status = _mapResults(results);
        if (status != _currentStatus) {
          _currentStatus = status;
          _statusController.add(status);

          if (kDebugMode) {
            print('[ConnectivityService] Status changed: $status');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('[ConnectivityService] Error: $error');
        }
      },
    );

    // Initial check
    checkConnectivity();
  }

  @override
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  @override
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final status = _mapResults(results);

      if (status != _currentStatus) {
        _currentStatus = status;
        _statusController.add(status);
      }

      return status == ConnectivityStatus.online;
    } catch (e) {
      if (kDebugMode) {
        print('[ConnectivityService] Check error: $e');
      }
      return false;
    }
  }

  ConnectivityStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityStatus.offline;

    // If any connection is available, consider online
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return ConnectivityStatus.online;
      }
    }

    return ConnectivityStatus.offline;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

/// Stub implementation for platforms without connectivity_plus support
class StubConnectivityService implements ConnectivityService {
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  @override
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  @override
  ConnectivityStatus get currentStatus => ConnectivityStatus.online;

  @override
  bool get isOnline => true;

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void dispose() {
    _statusController.close();
  }
}
