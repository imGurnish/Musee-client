part of 'sync_cubit.dart';

/// Connection state of the sync
enum SyncConnectionState {
  idle,
  initializing,
  ready,
  discovering,
  connecting,
  connected,
  syncing,
  error,
}

/// Mode of the sync session
enum SyncMode { none, host, client }

/// Remote playback state from the host
class SyncPlaybackState {
  final bool isPlaying;
  final String? currentTrackId;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackAlbum;
  final String? trackImageUrl;
  final Duration position;
  final Duration duration;
  final DateTime receivedAt; // When this state was received locally

  SyncPlaybackState({
    required this.isPlaying,
    this.currentTrackId,
    this.trackTitle,
    this.trackArtist,
    this.trackAlbum,
    this.trackImageUrl,
    required this.position,
    required this.duration,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Get estimated current position accounting for time since received
  Duration get estimatedPosition {
    if (!isPlaying) return position;
    final elapsed = DateTime.now().difference(receivedAt);
    return position + elapsed;
  }
}

/// Playback command received from host
class SyncPlaybackCommand {
  final String command;
  final Duration? seekPosition;

  const SyncPlaybackCommand({required this.command, this.seekPosition});
}

/// Drift correction information
class SyncDriftCorrection {
  final int correctionDeltaMs;
  final String strategy;
  final DateTime appliedAt;

  const SyncDriftCorrection({
    required this.correctionDeltaMs,
    required this.strategy,
    required this.appliedAt,
  });
}

/// Main state class for SyncCubit
class SyncState extends Equatable {
  final SyncMode syncMode;
  final SyncConnectionState connectionState;
  final SyncDevice? localDevice;
  final SyncDevice? hostDevice;
  final List<SyncDevice> discoveredDevices;
  final List<SyncDevice> connectedDevices;
  final SyncSession? currentSession;
  final String? hostQrCode;
  final String? errorMessage;
  final SyncPlaybackState? remotePlaybackState;
  final SyncPlaybackCommand? lastPlaybackCommand;
  final SyncDriftCorrection? lastDriftCorrection;
  final int currentDriftMs;
  final int averageDriftMs;
  final List<String>? pendingJoinRequests;

  const SyncState({
    required this.syncMode,
    required this.connectionState,
    this.localDevice,
    this.hostDevice,
    this.discoveredDevices = const [],
    this.connectedDevices = const [],
    this.currentSession,
    this.hostQrCode,
    this.errorMessage,
    this.remotePlaybackState,
    this.lastPlaybackCommand,
    this.lastDriftCorrection,
    this.currentDriftMs = 0,
    this.averageDriftMs = 0,
    this.pendingJoinRequests,
  });

  /// Initial state
  const SyncState.initial()
    : syncMode = SyncMode.none,
      connectionState = SyncConnectionState.idle,
      localDevice = null,
      hostDevice = null,
      discoveredDevices = const [],
      connectedDevices = const [],
      currentSession = null,
      hostQrCode = null,
      errorMessage = null,
      remotePlaybackState = null,
      lastPlaybackCommand = null,
      lastDriftCorrection = null,
      currentDriftMs = 0,
      averageDriftMs = 0,
      pendingJoinRequests = null;

  SyncState copyWith({
    SyncMode? syncMode,
    SyncConnectionState? connectionState,
    SyncDevice? localDevice,
    SyncDevice? hostDevice,
    List<SyncDevice>? discoveredDevices,
    List<SyncDevice>? connectedDevices,
    SyncSession? currentSession,
    String? hostQrCode,
    String? errorMessage,
    SyncPlaybackState? remotePlaybackState,
    SyncPlaybackCommand? lastPlaybackCommand,
    SyncDriftCorrection? lastDriftCorrection,
    int? currentDriftMs,
    int? averageDriftMs,
    List<String>? pendingJoinRequests,
  }) {
    return SyncState(
      syncMode: syncMode ?? this.syncMode,
      connectionState: connectionState ?? this.connectionState,
      localDevice: localDevice ?? this.localDevice,
      hostDevice: hostDevice ?? this.hostDevice,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      currentSession: currentSession ?? this.currentSession,
      hostQrCode: hostQrCode ?? this.hostQrCode,
      errorMessage: errorMessage ?? this.errorMessage,
      remotePlaybackState: remotePlaybackState ?? this.remotePlaybackState,
      lastPlaybackCommand: lastPlaybackCommand ?? this.lastPlaybackCommand,
      lastDriftCorrection: lastDriftCorrection ?? this.lastDriftCorrection,
      currentDriftMs: currentDriftMs ?? this.currentDriftMs,
      averageDriftMs: averageDriftMs ?? this.averageDriftMs,
      pendingJoinRequests: pendingJoinRequests ?? this.pendingJoinRequests,
    );
  }

  /// Is the session currently syncing?
  bool get isSyncing => connectionState == SyncConnectionState.syncing;

  /// Is this device the host?
  bool get isHost => syncMode == SyncMode.host;

  /// Is this device a client?
  bool get isClient => syncMode == SyncMode.client;

  /// Is connected to a sync session?
  bool get isConnected =>
      connectionState == SyncConnectionState.connected ||
      connectionState == SyncConnectionState.syncing;

  /// Has a significant drift that needs attention
  bool get hasSignificantDrift => averageDriftMs.abs() > 200;

  @override
  List<Object?> get props => [
    syncMode,
    connectionState,
    localDevice,
    hostDevice,
    discoveredDevices,
    connectedDevices,
    currentSession,
    hostQrCode,
    errorMessage,
    remotePlaybackState,
    lastPlaybackCommand,
    lastDriftCorrection,
    currentDriftMs,
    averageDriftMs,
    pendingJoinRequests,
  ];
}
