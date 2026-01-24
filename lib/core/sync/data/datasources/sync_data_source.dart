import 'dart:async';
import 'package:musee/core/sync/models/sync_device.dart';

/// Data source for local network sync operations
/// Abstracts low-level networking (WebSocket, UDP, mDNS)
abstract class SyncDataSource {
  /// Initialize local device information
  Future<void> initialize();

  /// Start discovering devices via mDNS/Bonjour or broadcast
  Future<void> startDeviceDiscovery();

  /// Stop discovery
  Future<void> stopDeviceDiscovery();

  /// Stream of discovered devices
  Stream<SyncDevice> get discoveredDevicesStream;

  /// Establish WebSocket connection to host
  Future<bool> connectToHost(SyncDevice host);

  /// Close all connections
  Future<void> closeConnections();

  /// Send data to peer
  Future<void> sendToPeer(String peerId, Map<String, dynamic> data);

  /// Broadcast data to all peers
  Future<void> broadcastToPeers(Map<String, dynamic> data);

  /// Stream of incoming data from peers
  Stream<Map<String, dynamic>> get incomingDataStream;

  /// Get local IP address
  Future<String?> getLocalIpAddress();

  /// Get a free port on the device
  Future<int> getAvailablePort();

  /// Listen for incoming connections
  Future<void> listenForConnections(int port);

  /// Get network interface information
  Future<Map<String, String>> getNetworkInfo();
}
