import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:musee/core/sync/data/datasources/sync_data_source.dart';
import 'package:musee/core/sync/domain/repository/sync_repository.dart';
import 'package:musee/core/sync/models/sync_device.dart';
import 'package:musee/core/sync/models/sync_message.dart';
import 'package:musee/core/sync/models/sync_session.dart';
import 'package:uuid/uuid.dart';

/// Implementation of SyncRepository
/// Mediates between the presentation layer and data sources
class SyncRepositoryImpl implements SyncRepository {
  final SyncDataSource _dataSource;

  late final StreamController<List<SyncDevice>> _discoveredDevicesController =
      StreamController<List<SyncDevice>>.broadcast();
  late final StreamController<SyncMessage> _incomingMessagesController =
      StreamController<SyncMessage>.broadcast();

  final Map<String, SyncDevice> _discoveredDevicesMap = {};
  final List<SyncDevice> _connectedDevices = [];

  String? _localDeviceId;
  String? _localDeviceName;
  SyncSession? _currentSession;

  SyncRepositoryImpl(this._dataSource) {
    _init();
  }

  void _init() {
    // Listen to discovered devices
    _dataSource.discoveredDevicesStream.listen((device) {
      _discoveredDevicesMap[device.deviceId] = device;
      _discoveredDevicesController.add(_discoveredDevicesMap.values.toList());
    });

    // Listen to incoming data and convert to messages
    _dataSource.incomingDataStream.listen((data) {
      try {
        final message = SyncMessage.fromJson(data);
        _incomingMessagesController.add(message);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SyncRepository] Error parsing message: $e');
        }
      }
    });
  }

  @override
  Future<String> getLocalDeviceId() async {
    if (_localDeviceId == null) {
      _localDeviceId = const Uuid().v4();
      if (kDebugMode) {
        debugPrint('[SyncRepository] Generated device ID: $_localDeviceId');
      }
    }
    return _localDeviceId!;
  }

  @override
  Future<String> getLocalDeviceName() async {
    if (_localDeviceName == null) {
      // Try to get device name from system
      try {
        final info = await _dataSource.getNetworkInfo();
        _localDeviceName = info['deviceName'] ?? _generateDeviceName();
      } catch (_) {
        _localDeviceName = _generateDeviceName();
      }
    }
    return _localDeviceName!;
  }

  String _generateDeviceName() {
    const devices = ['Harmony', 'Rhythm', 'Echo', 'Pulse', 'Wave'];
    final index = (_localDeviceId?.hashCode ?? 0).abs() % devices.length;
    final number = ((_localDeviceId?.hashCode ?? 0).abs() % 999) + 1;
    return '${devices[index]}-$number';
  }

  @override
  Future<void> startDiscovery() async {
    await _dataSource.startDeviceDiscovery();
    if (kDebugMode) {
      debugPrint('[SyncRepository] Started device discovery');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    await _dataSource.stopDeviceDiscovery();
    if (kDebugMode) {
      debugPrint('[SyncRepository] Stopped device discovery');
    }
  }

  @override
  Stream<List<SyncDevice>> get discoveredDevices =>
      _discoveredDevicesController.stream;

  @override
  Future<bool> connectToHost(SyncDevice host) async {
    try {
      final success = await _dataSource.connectToHost(host);
      if (success) {
        _connectedDevices.add(host);
        if (kDebugMode) {
          debugPrint('[SyncRepository] Connected to host: ${host.deviceName}');
        }
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncRepository] Connection failed: $e');
      }
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _dataSource.closeConnections();
    _connectedDevices.clear();
    _currentSession = null;
    if (kDebugMode) {
      debugPrint('[SyncRepository] Disconnected from sync');
    }
  }

  @override
  Future<SyncSession> createSyncSession() async {
    final deviceId = await getLocalDeviceId();
    final sessionId = const Uuid().v4();

    _currentSession = SyncSession(
      sessionId: sessionId,
      hostDeviceId: deviceId,
      clientDeviceIds: [],
      state: SyncSessionState.idle,
      createdAt: DateTime.now(),
    );

    // Listen for incoming connections
    final port = await _dataSource.getAvailablePort();
    await _dataSource.listenForConnections(port);

    if (kDebugMode) {
      debugPrint('[SyncRepository] Created session: $sessionId on port $port');
    }

    return _currentSession!;
  }

  @override
  Future<SyncSession?> getCurrentSession() async {
    return _currentSession;
  }

  @override
  Future<void> sendMessage(SyncMessage message) async {
    try {
      await _dataSource.broadcastToPeers(message.toJson());
      if (kDebugMode) {
        debugPrint('[SyncRepository] Sent message: ${message.type}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncRepository] Send message error: $e');
      }
      rethrow;
    }
  }

  @override
  Stream<SyncMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  @override
  Future<bool> joinSession({
    required String sessionId,
    required SyncDevice host,
  }) async {
    try {
      final deviceId = await getLocalDeviceId();

      // Connect to host
      final connected = await connectToHost(host);
      if (!connected) {
        return false;
      }

      // Update session with client device
      _currentSession = SyncSession(
        sessionId: sessionId,
        hostDeviceId: host.deviceId,
        clientDeviceIds: [deviceId],
        state: SyncSessionState.connecting,
        createdAt: DateTime.now(),
      );

      if (kDebugMode) {
        debugPrint('[SyncRepository] Joined session: $sessionId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncRepository] Join session error: $e');
      }
      return false;
    }
  }

  @override
  Future<List<SyncDevice>> getConnectedDevices() async {
    return List.from(_connectedDevices);
  }

  @override
  Future<String> generateQrCodeData() async {
    final deviceId = await getLocalDeviceId();
    final deviceName = await getLocalDeviceName();
    final networkInfo = await _dataSource.getNetworkInfo();
    final ipAddress = networkInfo['ip'] ?? '127.0.0.1';
    final port = networkInfo['serverPort'] ?? '6000';

    // QR data format: musee://sync?id=<id>&name=<name>&ip=<ip>&port=<port>
    final qrData =
        'musee://sync?id=$deviceId&name=${Uri.encodeComponent(deviceName)}&ip=$ipAddress&port=$port';

    if (kDebugMode) {
      debugPrint('[SyncRepository] Generated QR: $qrData');
    }

    return qrData;
  }

  @override
  Future<SyncDevice?> parseQrCode(String qrData) async {
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme != 'musee' || uri.host != 'sync') {
        return null;
      }

      final params = uri.queryParameters;
      return SyncDevice(
        deviceId: params['id'] ?? '',
        deviceName: params['name'] ?? 'Unknown',
        ipAddress: params['ip'] ?? '',
        port: int.tryParse(params['port'] ?? '6000') ?? 6000,
        discoveredAt: DateTime.now(),
        isHost: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncRepository] QR parse error: $e');
      }
      return null;
    }
  }

  @override
  Future<String> generateShareLink() async {
    return await generateQrCodeData();
  }

  void dispose() {
    _discoveredDevicesController.close();
    _incomingMessagesController.close();
  }
}
