import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:musee/core/sync/domain/repository/sync_repository.dart';
import 'package:musee/core/sync/models/sync_device.dart';
import 'package:musee/core/sync/models/sync_message.dart';
import 'package:musee/core/sync/models/sync_session.dart';

part 'sync_state.dart';

/// SyncCubit manages device synchronization state and logic
/// Implements drift correction and playback synchronization
class SyncCubit extends Cubit<SyncState> {
  final SyncRepository _repository;

  StreamSubscription<List<SyncDevice>>? _discoveredDevicesSub;
  StreamSubscription<SyncMessage>? _incomingMessagesSub;

  /// Drift correction parameters
  static const int driftThresholdMs = 200; // Tolerance before correction
  static const int minDriftSampleSize = 5; // Samples before applying correction
  static const double speedAdjustmentFactor = 1.05; // Speed up/down factor

  /// Running drift samples for statistical analysis
  final List<int> _driftSamples = [];

  SyncCubit(this._repository) : super(const SyncState.initial()) {
    _init();
  }

  void _init() {
    // Listen to device discoveries
    _discoveredDevicesSub = _repository.discoveredDevices.listen((devices) {
      emit(state.copyWith(discoveredDevices: devices));
    });

    // Listen to incoming messages
    _incomingMessagesSub = _repository.incomingMessages.listen((message) {
      _handleIncomingMessage(message);
    });
  }

  /// Start as a host device
  Future<void> startAsHost() async {
    try {
      emit(
        state.copyWith(
          syncMode: SyncMode.host,
          connectionState: SyncConnectionState.initializing,
        ),
      );

      final deviceId = await _repository.getLocalDeviceId();
      final deviceName = await _repository.getLocalDeviceName();

      // Create sync session
      final session = await _repository.createSyncSession();

      // Generate QR code for sharing
      final qrData = await _repository.generateQrCodeData();

      emit(
        state.copyWith(
          syncMode: SyncMode.host,
          connectionState: SyncConnectionState.ready,
          localDevice: SyncDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            ipAddress: '', // Will be populated by data source
            port: 6000,
            discoveredAt: DateTime.now(),
            isHost: true,
          ),
          currentSession: session,
          hostQrCode: qrData,
        ),
      );

      if (kDebugMode) {
        debugPrint('[SyncCubit] Started as host');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Host startup error: $e');
      }
      emit(
        state.copyWith(
          connectionState: SyncConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Start discovering devices
  Future<void> startDiscovering() async {
    try {
      emit(
        state.copyWith(
          syncMode: SyncMode.client,
          connectionState: SyncConnectionState.discovering,
        ),
      );
      await _repository.startDiscovery();
      if (kDebugMode) {
        debugPrint('[SyncCubit] Started discovering devices');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Discovery error: $e');
      }
      emit(
        state.copyWith(
          connectionState: SyncConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Stop discovering devices
  Future<void> stopDiscovering() async {
    try {
      await _repository.stopDiscovery();
      emit(state.copyWith(connectionState: SyncConnectionState.idle));
      if (kDebugMode) {
        debugPrint('[SyncCubit] Stopped discovering devices');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Stop discovery error: $e');
      }
    }
  }

  /// Connect to a host device
  Future<void> connectToHost(SyncDevice host) async {
    try {
      emit(state.copyWith(connectionState: SyncConnectionState.connecting));

      // Join the host's sync session
      // In real scenario, host would have created a session we're joining
      final sessionId = host.deviceId; // Use host ID as session ID
      final success = await _repository.joinSession(
        sessionId: sessionId,
        host: host,
      );

      if (!success) {
        throw Exception('Failed to connect to host');
      }

      final deviceId = await _repository.getLocalDeviceId();
      final deviceName = await _repository.getLocalDeviceName();

      emit(
        state.copyWith(
          syncMode: SyncMode.client,
          connectionState: SyncConnectionState.connected,
          localDevice: SyncDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            ipAddress: '', // Will be populated by data source
            port: 0,
            discoveredAt: DateTime.now(),
            isHost: false,
          ),
          hostDevice: host,
        ),
      );

      if (kDebugMode) {
        debugPrint('[SyncCubit] Connected to host: ${host.deviceName}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Connection error: $e');
      }
      emit(
        state.copyWith(
          connectionState: SyncConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Handle incoming sync messages
  void _handleIncomingMessage(SyncMessage message) {
    switch (message.type) {
      case SyncMessageType.playbackState:
        _handlePlaybackState(message);
        break;
      case SyncMessageType.playbackCommand:
        _handlePlaybackCommand(message);
        break;
      case SyncMessageType.syncSignal:
        _handleSyncSignal(message);
        break;
      case SyncMessageType.driftCorrection:
        _handleDriftCorrection(message);
        break;
      case SyncMessageType.joinApproved:
        _handleJoinApproved(message);
        break;
      case SyncMessageType.joinRequest:
        _handleJoinRequest(message);
        break;
      case SyncMessageType.clockPing:
        _handleClockPing(message);
        break;
      case SyncMessageType.clockPong:
        _handleClockPong(message);
        break;
      default:
        break;
    }
  }

  void _handlePlaybackState(SyncMessage message) {
    final isPlaying = message.payload['isPlaying'] as bool? ?? false;
    final trackId = message.payload['currentTrackId'] as String?;
    final trackTitle = message.payload['trackTitle'] as String?;
    final trackArtist = message.payload['trackArtist'] as String?;
    final trackAlbum = message.payload['trackAlbum'] as String?;
    final trackImageUrl = message.payload['trackImageUrl'] as String?;
    final posMs = message.payload['position'] as int? ?? 0;
    final durMs = message.payload['duration'] as int? ?? 0;

    // receivedAt is set automatically to DateTime.now() in the constructor
    emit(
      state.copyWith(
        remotePlaybackState: SyncPlaybackState(
          isPlaying: isPlaying,
          currentTrackId: trackId,
          trackTitle: trackTitle,
          trackArtist: trackArtist,
          trackAlbum: trackAlbum,
          trackImageUrl: trackImageUrl,
          position: Duration(milliseconds: posMs),
          duration: Duration(milliseconds: durMs),
        ),
      ),
    );
  }

  void _handlePlaybackCommand(SyncMessage message) {
    final command = message.payload['command'] as String;
    final seekMs = message.payload['seekPosition'] as int?;

    emit(
      state.copyWith(
        lastPlaybackCommand: SyncPlaybackCommand(
          command: command,
          seekPosition: seekMs != null ? Duration(milliseconds: seekMs) : null,
        ),
      ),
    );
  }

  void _handleSyncSignal(SyncMessage message) {
    // Measure drift between host and client
    final hostPosMs = message.payload['hostPosition'] as int? ?? 0;
    final clientPosMs = message.payload['clientPosition'] as int? ?? 0;

    // Calculate drift in milliseconds
    final driftMs = hostPosMs - clientPosMs;

    // Add to drift samples for statistical analysis
    _driftSamples.add(driftMs);
    if (_driftSamples.length > 20) {
      _driftSamples.removeAt(0);
    }

    // Calculate average drift
    final avgDrift = _driftSamples.isNotEmpty
        ? (_driftSamples.reduce((a, b) => a + b) / _driftSamples.length).toInt()
        : 0;

    // Update UI with drift information
    emit(state.copyWith(currentDriftMs: driftMs, averageDriftMs: avgDrift));

    // If drift exceeds threshold and we have enough samples, request correction
    if (avgDrift.abs() > driftThresholdMs &&
        _driftSamples.length >= minDriftSampleSize) {
      _requestDriftCorrection(avgDrift);
    }
  }

  void _handleDriftCorrection(SyncMessage message) {
    final correctionMs = message.payload['correctionDelta'] as int? ?? 0;
    final strategy = message.payload['strategy'] as String? ?? 'seek';

    emit(
      state.copyWith(
        lastDriftCorrection: SyncDriftCorrection(
          correctionDeltaMs: correctionMs,
          strategy: strategy,
          appliedAt: DateTime.now(),
        ),
      ),
    );

    // Clear drift samples after correction
    _driftSamples.clear();
  }

  void _handleJoinRequest(SyncMessage message) {
    if (state.syncMode == SyncMode.host) {
      final deviceId = message.senderId;
      final deviceName =
          message.payload['deviceName'] as String? ?? 'Unknown Device';

      // Create device object for the connected client
      final newDevice = SyncDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: '',
        port: 0,
        discoveredAt: DateTime.now(),
        isHost: false,
      );

      // Auto-approve and add to connected devices
      emit(
        state.copyWith(
          connectionState: SyncConnectionState.connected,
          connectedDevices: [...state.connectedDevices, newDevice],
        ),
      );

      // Send approval message
      _sendJoinApproval(deviceId);

      if (kDebugMode) {
        debugPrint('[SyncCubit] Client joined: $deviceName ($deviceId)');
      }
    }
  }

  Future<void> _sendJoinApproval(String targetDeviceId) async {
    try {
      final message = SyncMessage(
        type: SyncMessageType.joinApproved,
        senderId: state.localDevice?.deviceId ?? '',
        sessionId: state.currentSession?.sessionId ?? '',
        timestamp: DateTime.now(),
        payload: {
          'targetDeviceId': targetDeviceId,
          'approvedAt': DateTime.now().toIso8601String(),
        },
      );
      await _repository.sendMessage(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Send join approval error: $e');
      }
    }
  }

  void _handleJoinApproved(SyncMessage message) {
    if (kDebugMode) {
      debugPrint('[SyncCubit] Join approved by host');
    }
    emit(state.copyWith(connectionState: SyncConnectionState.connected));
  }

  /// Handle clock ping - just respond with pong (not used in simplified approach)
  void _handleClockPing(SyncMessage message) {
    // Simplified: we don't need clock sync, just track receivedAt locally
  }

  /// Handle clock pong - not used in simplified approach
  void _handleClockPong(SyncMessage message) {
    // Simplified: we don't need clock sync
  }

  /// Request drift correction from host
  void _requestDriftCorrection(int driftMs) {
    try {
      final correctionStrategy = driftMs.abs() < 500
          ? DriftCorrectionStrategy.microAdjustment
          : DriftCorrectionStrategy.seek;

      final message = DriftCorrectionMessage(
        senderId: state.localDevice?.deviceId ?? '',
        sessionId: state.currentSession?.sessionId ?? '',
        correctionDelta: Duration(milliseconds: driftMs),
        strategy: correctionStrategy,
      );

      unawaited(_repository.sendMessage(message));

      if (kDebugMode) {
        debugPrint('[SyncCubit] Requested drift correction: ${driftMs}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Drift correction request error: $e');
      }
    }
  }

  /// Send playback state to clients (for host)
  Future<void> broadcastPlaybackState({
    required bool isPlaying,
    required String? trackId,
    String? trackTitle,
    String? trackArtist,
    String? trackAlbum,
    String? trackImageUrl,
    required Duration position,
    required Duration duration,
  }) async {
    try {
      if (state.syncMode != SyncMode.host) {
        return;
      }

      if (state.connectedDevices.isEmpty) {
        return; // No clients to broadcast to
      }

      if (kDebugMode) {
        debugPrint(
          '[SyncCubit] Broadcasting: trackId=$trackId, playing=$isPlaying, to ${state.connectedDevices.length} clients',
        );
      }

      final message = PlaybackStateMessage(
        senderId: state.localDevice?.deviceId ?? '',
        sessionId: state.currentSession?.sessionId ?? '',
        isPlaying: isPlaying,
        currentTrackId: trackId,
        trackTitle: trackTitle,
        trackArtist: trackArtist,
        trackAlbum: trackAlbum,
        trackImageUrl: trackImageUrl,
        position: position,
        duration: duration,
      );

      // Fire-and-forget to avoid blocking host UI
      unawaited(_repository.sendMessage(message));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Broadcast playback state error: $e');
      }
    }
  }

  /// Approve a join request (for host)
  Future<void> approveJoinRequest(String deviceId) async {
    try {
      if (state.syncMode != SyncMode.host) {
        return;
      }

      // Remove from pending
      final updated = state.pendingJoinRequests
          ?.where((id) => id != deviceId)
          .toList();
      emit(state.copyWith(pendingJoinRequests: updated));

      // Send approval message
      final message = SyncMessage(
        type: SyncMessageType.joinApproved,
        senderId: state.localDevice?.deviceId ?? '',
        sessionId: state.currentSession?.sessionId ?? '',
        timestamp: DateTime.now(),
        payload: {
          'targetDeviceId': deviceId,
          'approvedAt': DateTime.now().toIso8601String(),
        },
      );

      await _repository.sendMessage(message);

      if (kDebugMode) {
        debugPrint('[SyncCubit] Approved join request from: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Approve join error: $e');
      }
    }
  }

  /// Reject a join request (for host)
  Future<void> rejectJoinRequest(String deviceId) async {
    try {
      if (state.syncMode != SyncMode.host) {
        return;
      }

      // Remove from pending
      final updated = state.pendingJoinRequests
          ?.where((id) => id != deviceId)
          .toList();
      emit(state.copyWith(pendingJoinRequests: updated));

      // Send rejection message
      final message = SyncMessage(
        type: SyncMessageType.joinRejected,
        senderId: state.localDevice?.deviceId ?? '',
        sessionId: state.currentSession?.sessionId ?? '',
        timestamp: DateTime.now(),
        payload: {'targetDeviceId': deviceId},
      );

      await _repository.sendMessage(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Reject join error: $e');
      }
    }
  }

  /// Disconnect from sync
  Future<void> disconnect() async {
    try {
      await _repository.disconnect();
      emit(const SyncState.initial());
      if (kDebugMode) {
        debugPrint('[SyncCubit] Disconnected');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncCubit] Disconnect error: $e');
      }
    }
  }

  @override
  Future<void> close() {
    _discoveredDevicesSub?.cancel();
    _incomingMessagesSub?.cancel();
    return super.close();
  }
}
