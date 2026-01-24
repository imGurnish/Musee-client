import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:musee/core/sync/data/datasources/sync_data_source.dart';
import 'package:musee/core/sync/models/sync_device.dart';
import 'package:uuid/uuid.dart';

/// Implementation of SyncDataSource using WebSocket and UDP
/// Supports local network communication with drift correction
class SyncDataSourceImpl implements SyncDataSource {
  String? _localDeviceId;
  String? _localIpAddress;
  String? _localDeviceName;
  WebSocket? _wsConnection;

  final _discoveredDevicesController = StreamController<SyncDevice>.broadcast();
  final _incomingDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const int _discoveryPort = 5353;
  static const int _defaultSyncPort = 6000;

  HttpServer? _httpServer;
  RawDatagramSocket? _discoverySocket;
  RawDatagramSocket? _discoveryListenerSocket;
  Timer? _discoveryBroadcastTimer;
  final Map<String, WebSocket> _peerConnections = {};

  bool _isHost = false;
  int _serverPort = _defaultSyncPort;

  @override
  Future<void> initialize() async {
    try {
      _localDeviceId ??= const Uuid().v4();
      _localIpAddress = await getLocalIpAddress();
      _localDeviceName = _generateDeviceName();

      if (kDebugMode) {
        debugPrint(
          '[SyncDataSource] Initialized - ID: $_localDeviceId, IP: $_localIpAddress',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Init error: $e');
      }
      rethrow;
    }
  }

  String _generateDeviceName() {
    const devices = ['Harmony', 'Rhythm', 'Echo', 'Pulse', 'Wave'];
    final index = (_localDeviceId?.hashCode ?? 0).abs() % devices.length;
    final number = ((_localDeviceId?.hashCode ?? 0).abs() % 999) + 1;
    return '${devices[index]}-$number';
  }

  // ==================== HOST MODE ====================

  /// Start WebSocket server for host mode
  Future<void> startServer(int port) async {
    try {
      // Ensure we're initialized
      if (_localDeviceId == null) {
        await initialize();
      }

      _isHost = true;
      _serverPort = port;

      // Start HTTP server that handles WebSocket upgrades
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port);

      if (kDebugMode) {
        debugPrint('[SyncDataSource] WebSocket server started on port $port');
        debugPrint('[SyncDataSource] Server URL: ws://$_localIpAddress:$port');
      }

      _httpServer!.listen((HttpRequest request) {
        _handleHttpRequest(request);
      });

      // Start listening for discovery requests and respond
      await _startDiscoveryResponder();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Server start error: $e');
      }
      rethrow;
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[SyncDataSource] Incoming HTTP request: ${request.uri.path}',
        );
      }

      // Check if this is a WebSocket upgrade request
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocketConnection(socket);
      } else {
        // Return simple info for non-WebSocket requests
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'type': 'musee_sync_host',
              'deviceId': _localDeviceId,
              'deviceName': _localDeviceName,
              'port': _serverPort,
            }),
          )
          ..close();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] HTTP request error: $e');
      }
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      } catch (_) {}
    }
  }

  void _handleWebSocketConnection(WebSocket socket) {
    final connectionId = const Uuid().v4();
    _peerConnections[connectionId] = socket;

    if (kDebugMode) {
      debugPrint('[SyncDataSource] New WebSocket connection: $connectionId');
    }

    socket.listen(
      (data) {
        try {
          final jsonData = jsonDecode(data as String) as Map<String, dynamic>;
          jsonData['_connectionId'] = connectionId;
          _incomingDataController.add(jsonData);

          if (kDebugMode) {
            debugPrint(
              '[SyncDataSource] Received from $connectionId: ${jsonData['type']}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[SyncDataSource] Parse error: $e');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[SyncDataSource] WebSocket error: $error');
        }
        _peerConnections.remove(connectionId);
      },
      onDone: () {
        if (kDebugMode) {
          debugPrint('[SyncDataSource] Client disconnected: $connectionId');
        }
        _peerConnections.remove(connectionId);
      },
    );

    // Send welcome message
    socket.add(
      jsonEncode({
        'type': 'connected',
        'hostId': _localDeviceId,
        'hostName': _localDeviceName,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> _startDiscoveryResponder() async {
    try {
      _discoveryListenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );

      _discoveryListenerSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoveryListenerSocket!.receive();
          if (datagram != null) {
            try {
              final data = jsonDecode(String.fromCharCodes(datagram.data));
              if (data['type'] == 'discovery') {
                // Respond to discovery request
                final response = jsonEncode({
                  'type': 'discovery_response',
                  'deviceId': _localDeviceId,
                  'deviceName': _localDeviceName,
                  'port': _serverPort,
                  'isHost': true,
                  'ip': _localIpAddress,
                });

                _discoveryListenerSocket!.send(
                  response.codeUnits,
                  datagram.address,
                  datagram.port,
                );

                if (kDebugMode) {
                  debugPrint(
                    '[SyncDataSource] Responded to discovery from ${datagram.address.address}',
                  );
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[SyncDataSource] Discovery parse error: $e');
              }
            }
          }
        }
      });

      if (kDebugMode) {
        debugPrint(
          '[SyncDataSource] Discovery responder started on port $_discoveryPort',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Discovery responder error: $e');
      }
    }
  }

  // ==================== CLIENT MODE ====================

  @override
  Future<void> startDeviceDiscovery() async {
    try {
      // Ensure we're initialized first
      if (_localDeviceId == null) {
        await initialize();
      }

      _discoverySocket?.close();

      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // Random port for sending
        reuseAddress: true,
      );
      _discoverySocket!.broadcastEnabled = true;

      // Listen for responses
      _discoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket!.receive();
          if (datagram != null) {
            try {
              final data = jsonDecode(String.fromCharCodes(datagram.data));
              if (data['type'] == 'discovery_response') {
                final deviceId = data['deviceId'] as String?;
                if (deviceId == null || deviceId.isEmpty) {
                  if (kDebugMode) {
                    debugPrint(
                      '[SyncDataSource] Ignoring discovery response with null deviceId',
                    );
                  }
                  return;
                }
                final device = SyncDevice(
                  deviceId: deviceId,
                  deviceName: data['deviceName'] as String? ?? 'Unknown Host',
                  ipAddress: data['ip'] as String? ?? datagram.address.address,
                  port: data['port'] as int? ?? _defaultSyncPort,
                  discoveredAt: DateTime.now(),
                  isHost: true,
                );
                _discoveredDevicesController.add(device);

                if (kDebugMode) {
                  debugPrint(
                    '[SyncDataSource] Discovered: ${device.deviceName} at ${device.ipAddress}:${device.port}',
                  );
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                  '[SyncDataSource] Discovery response parse error: $e',
                );
              }
            }
          }
        }
      });

      // Send discovery broadcasts periodically
      _sendDiscoveryBroadcast();
      _discoveryBroadcastTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _sendDiscoveryBroadcast(),
      );

      if (kDebugMode) {
        debugPrint('[SyncDataSource] Started device discovery');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Start discovery error: $e');
      }
      rethrow;
    }
  }

  void _sendDiscoveryBroadcast() {
    try {
      final discoveryData = jsonEncode({
        'type': 'discovery',
        'deviceId': _localDeviceId,
        'deviceName': _localDeviceName,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Broadcast to common subnet ranges
      final broadcastAddresses = [
        '255.255.255.255',
        '192.168.137.255', // Windows hotspot
        '192.168.1.255',
        '192.168.0.255',
        '10.0.0.255',
      ];

      for (final addr in broadcastAddresses) {
        try {
          _discoverySocket?.send(
            discoveryData.codeUnits,
            InternetAddress(addr),
            _discoveryPort,
          );
        } catch (_) {}
      }

      if (kDebugMode) {
        debugPrint('[SyncDataSource] Sent discovery broadcast');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Broadcast error: $e');
      }
    }
  }

  @override
  Future<void> stopDeviceDiscovery() async {
    _discoveryBroadcastTimer?.cancel();
    _discoveryBroadcastTimer = null;
    _discoverySocket?.close();
    _discoverySocket = null;

    if (kDebugMode) {
      debugPrint('[SyncDataSource] Stopped device discovery');
    }
  }

  @override
  Stream<SyncDevice> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  @override
  Future<bool> connectToHost(SyncDevice host) async {
    try {
      final wsUrl = 'ws://${host.ipAddress}:${host.port}';

      if (kDebugMode) {
        debugPrint('[SyncDataSource] Connecting to: $wsUrl');
      }

      _wsConnection = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      // Send join request
      _wsConnection!.add(
        jsonEncode({
          'type': 'join_request',
          'deviceId': _localDeviceId,
          'deviceName': _localDeviceName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // Listen for data
      _wsConnection!.listen(
        (data) {
          try {
            final jsonData = jsonDecode(data as String) as Map<String, dynamic>;
            _incomingDataController.add(jsonData);

            if (kDebugMode) {
              debugPrint('[SyncDataSource] Received: ${jsonData['type']}');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[SyncDataSource] Parse error: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('[SyncDataSource] WebSocket error: $error');
          }
          _incomingDataController.addError(error);
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('[SyncDataSource] Disconnected from host');
          }
        },
      );

      if (kDebugMode) {
        debugPrint('[SyncDataSource] Connected to host: ${host.deviceName}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Connection error: $e');
      }
      return false;
    }
  }

  // ==================== COMMON ====================

  @override
  Future<void> closeConnections() async {
    try {
      _discoveryBroadcastTimer?.cancel();
      _discoverySocket?.close();
      _discoveryListenerSocket?.close();

      await _wsConnection?.close();

      for (final connection in _peerConnections.values) {
        await connection.close();
      }
      _peerConnections.clear();

      await _httpServer?.close();
      _httpServer = null;
      _isHost = false;

      if (kDebugMode) {
        debugPrint('[SyncDataSource] Closed all connections');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Close error: $e');
      }
    }
  }

  @override
  Future<void> sendToPeer(String peerId, Map<String, dynamic> data) async {
    try {
      final connection = _peerConnections[peerId];
      if (connection != null && connection.readyState == WebSocket.open) {
        connection.add(jsonEncode(data));
      } else if (_wsConnection != null &&
          _wsConnection!.readyState == WebSocket.open) {
        data['targetPeerId'] = peerId;
        _wsConnection!.add(jsonEncode(data));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Send to peer error: $e');
      }
    }
  }

  @override
  Future<void> broadcastToPeers(Map<String, dynamic> data) async {
    try {
      final encoded = jsonEncode(data);

      if (_isHost) {
        // Host broadcasts to all connected clients
        if (kDebugMode) {
          debugPrint(
            '[SyncDataSource] Broadcasting to ${_peerConnections.length} peers: ${data['type']}',
          );
        }
        for (final connection in _peerConnections.values) {
          if (connection.readyState == WebSocket.open) {
            connection.add(encoded);
          }
        }
      } else {
        // Client sends to host
        if (_wsConnection != null &&
            _wsConnection!.readyState == WebSocket.open) {
          _wsConnection!.add(encoded);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Broadcast error: $e');
      }
    }
  }

  @override
  Stream<Map<String, dynamic>> get incomingDataStream =>
      _incomingDataController.stream;

  @override
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();

      String? hotspotIp;
      String? wifiIp;
      String? fallbackIp;

      for (final interface in interfaces) {
        final nameLower = interface.name.toLowerCase();

        if (nameLower.contains('loopback') ||
            nameLower.contains('docker') ||
            nameLower.contains('vmware') ||
            nameLower.contains('virtualbox')) {
          continue;
        }

        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final ip = address.address;

            if (ip.startsWith('192.168.137.')) {
              hotspotIp = ip;
            } else if (nameLower.contains('wi-fi') ||
                nameLower.contains('wifi') ||
                nameLower.contains('wlan') ||
                nameLower.contains('ethernet')) {
              wifiIp = ip;
            } else if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.')) {
              fallbackIp = ip;
            }
          }
        }
      }

      final result = hotspotIp ?? wifiIp ?? fallbackIp ?? '127.0.0.1';
      _localIpAddress = result;

      if (kDebugMode) {
        debugPrint(
          '[SyncDataSource] IP: $result (hotspot: $hotspotIp, wifi: $wifiIp)',
        );
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Error getting IP: $e');
      }
      return null;
    }
  }

  @override
  Future<int> getAvailablePort() async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncDataSource] Error getting port: $e');
      }
      return _defaultSyncPort;
    }
  }

  @override
  Future<void> listenForConnections(int port) async {
    // This is now handled by startServer
    await startServer(port);
  }

  @override
  Future<Map<String, String>> getNetworkInfo() async {
    final ip = await getLocalIpAddress();

    String networkType = 'unknown';
    if (ip != null) {
      if (ip.startsWith('192.168.137.')) {
        networkType = 'hotspot';
      } else if (ip.startsWith('192.168.') ||
          ip.startsWith('10.') ||
          ip.startsWith('172.')) {
        networkType = 'local';
      }
    }

    return {
      'ip': ip ?? 'unknown',
      'deviceId': _localDeviceId ?? 'unknown',
      'deviceName': _localDeviceName ?? 'unknown',
      'networkType': networkType,
      'isHost': _isHost.toString(),
      'serverPort': _serverPort.toString(),
    };
  }

  void dispose() {
    closeConnections();
    _discoveredDevicesController.close();
    _incomingDataController.close();
  }
}
