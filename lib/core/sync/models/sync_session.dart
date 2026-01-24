import 'package:equatable/equatable.dart';

/// Represents the state of a sync session
enum SyncSessionState {
  idle,
  discovering,
  connecting,
  connected,
  syncing,
  paused,
  error,
  disconnected,
}

/// Represents a sync session between devices
class SyncSession extends Equatable {
  final String sessionId;
  final String hostDeviceId;
  final List<String> clientDeviceIds;
  final SyncSessionState state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? errorMessage;

  const SyncSession({
    required this.sessionId,
    required this.hostDeviceId,
    required this.clientDeviceIds,
    this.state = SyncSessionState.idle,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.errorMessage,
  });

  /// Create a copy with modifications
  SyncSession copyWith({
    String? sessionId,
    String? hostDeviceId,
    List<String>? clientDeviceIds,
    SyncSessionState? state,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? errorMessage,
  }) {
    return SyncSession(
      sessionId: sessionId ?? this.sessionId,
      hostDeviceId: hostDeviceId ?? this.hostDeviceId,
      clientDeviceIds: clientDeviceIds ?? this.clientDeviceIds,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    hostDeviceId,
    clientDeviceIds,
    state,
    createdAt,
    startedAt,
    endedAt,
    errorMessage,
  ];
}
