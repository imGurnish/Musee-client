import 'dart:async';
import 'package:musee/core/sync/models/sync_device.dart';
import 'package:musee/core/sync/models/sync_message.dart';
import 'package:musee/core/sync/models/sync_session.dart';

/// Abstract repository for device sync operations
/// Follows the Repository Pattern for clean separation of concerns
abstract class SyncRepository {
  /// Get the current device ID
  Future<String> getLocalDeviceId();

  /// Get the device name
  Future<String> getLocalDeviceName();

  /// Start discovering devices on the local network
  Future<void> startDiscovery();

  /// Stop device discovery
  Future<void> stopDiscovery();

  /// Stream of discovered devices
  Stream<List<SyncDevice>> get discoveredDevices;

  /// Connect to a host device
  Future<bool> connectToHost(SyncDevice host);

  /// Disconnect from sync session
  Future<void> disconnect();

  /// Create and host a sync session
  Future<SyncSession> createSyncSession();

  /// Get current sync session
  Future<SyncSession?> getCurrentSession();

  /// Send a message to peers
  Future<void> sendMessage(SyncMessage message);

  /// Stream of incoming messages
  Stream<SyncMessage> get incomingMessages;

  /// Join a sync session
  Future<bool> joinSession({
    required String sessionId,
    required SyncDevice host,
  });

  /// Get list of connected devices
  Future<List<SyncDevice>> getConnectedDevices();

  /// Generate QR code data for sharing
  Future<String> generateQrCodeData();

  /// Parse QR code connection string
  Future<SyncDevice?> parseQrCode(String qrData);

  /// Generate shareable link
  Future<String> generateShareLink();
}
