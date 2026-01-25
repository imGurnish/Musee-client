import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/core/sync/presentation/cubit/sync_cubit.dart';

/// Service that bridges PlayerCubit and SyncCubit for synchronized playback
/// Implements drift correction and playback command forwarding
class SyncPlayerService {
  final PlayerCubit _playerCubit;
  final SyncCubit _syncCubit;

  StreamSubscription<PlayerViewState>? _playerSubscription;
  StreamSubscription<SyncState>? _syncSubscription;

  /// Timer for periodic sync signals (when acting as host)
  Timer? _syncTimer;

  /// Timer for drift correction checks (when acting as client)
  Timer? _driftCorrectionTimer;

  /// Large drift threshold - seek directly (ms)
  static const int _seekThresholdMs = 300;

  /// Small drift threshold - use speed adjustment (ms)
  static const int _speedAdjustThresholdMs = 50;

  /// Speed adjustment factors for gradual drift correction
  static const double _speedUpFactor = 1.03;
  static const double _speedDownFactor = 0.97;

  /// Current playback speed (for drift correction)
  double _currentSpeed = 1.0;

  /// Whether this service is active
  bool _isActive = false;

  /// Track ID that's currently being loaded (to avoid duplicate loads)
  String? _loadingTrackId;

  /// Running drift samples for smoothing
  final List<int> _driftSamples = [];
  static const int _maxDriftSamples = 5;

  /// Last broadcast state to avoid redundant broadcasts
  bool? _lastBroadcastPlaying;
  String? _lastBroadcastTrackId;

  SyncPlayerService({
    required PlayerCubit playerCubit,
    required SyncCubit syncCubit,
  }) : _playerCubit = playerCubit,
       _syncCubit = syncCubit;

  /// Start synchronization
  void start() {
    if (_isActive) return;
    _isActive = true;

    // Listen to player state changes
    _playerSubscription = _playerCubit.stream.listen(_onPlayerStateChanged);

    // Listen to sync state changes
    _syncSubscription = _syncCubit.stream.listen(_onSyncStateChanged);

    // If host, start periodic sync signal broadcast
    if (_syncCubit.state.isHost) {
      _startSyncSignalBroadcast();
    }

    if (kDebugMode) {
      debugPrint('[SyncPlayerService] Started');
    }
  }

  /// Stop synchronization
  void stop() {
    if (!_isActive) return;
    _isActive = false;

    _playerSubscription?.cancel();
    _syncSubscription?.cancel();
    _syncTimer?.cancel();
    _driftCorrectionTimer?.cancel();
    _syncTimer = null;
    _driftCorrectionTimer = null;

    // Reset playback speed
    _resetPlaybackSpeed();
    _driftSamples.clear();
    _loadingTrackId = null;
    _lastBroadcastPlaying = null;
    _lastBroadcastTrackId = null;

    if (kDebugMode) {
      debugPrint('[SyncPlayerService] Stopped');
    }
  }

  /// Called when player state changes
  void _onPlayerStateChanged(PlayerViewState playerState) {
    if (!_isActive) return;

    final syncState = _syncCubit.state;

    // If host, broadcast only on meaningful state changes (play/pause/track change)
    if (syncState.isHost && syncState.isConnected) {
      final playingChanged = _lastBroadcastPlaying != playerState.playing;
      final trackChanged = _lastBroadcastTrackId != playerState.track?.trackId;

      // Only broadcast on play/pause toggle or track change
      if (playingChanged || trackChanged) {
        _lastBroadcastPlaying = playerState.playing;
        _lastBroadcastTrackId = playerState.track?.trackId;

        _syncCubit.broadcastPlaybackState(
          isPlaying: playerState.playing,
          trackId: playerState.track?.trackId,
          trackTitle: playerState.track?.title,
          trackArtist: playerState.track?.artist,
          trackAlbum: playerState.track?.album,
          trackImageUrl: playerState.track?.imageUrl,
          position: playerState.position,
          duration: playerState.duration,
        );
      }
    }

    // If client and track just loaded, sync to host position
    if (syncState.isClient &&
        syncState.isConnected &&
        _loadingTrackId == playerState.track?.trackId) {
      _loadingTrackId = null;
      _syncToHostPosition();
    }
  }

  /// Called when sync state changes
  void _onSyncStateChanged(SyncState syncState) {
    if (!_isActive) return;

    // If host just became connected, start the sync broadcast timer
    if (syncState.isHost && syncState.isConnected && _syncTimer == null) {
      _startSyncSignalBroadcast();
    }

    // If client just became connected, start drift correction timer
    if (syncState.isClient &&
        syncState.isConnected &&
        _driftCorrectionTimer == null) {
      _startDriftCorrectionTimer();
    }

    // Handle playback commands (for clients)
    if (syncState.isClient && syncState.lastPlaybackCommand != null) {
      _handlePlaybackCommand(syncState.lastPlaybackCommand!);
    }

    // Handle remote playback state (for clients)
    if (syncState.isClient && syncState.remotePlaybackState != null) {
      _handleRemotePlaybackState(syncState.remotePlaybackState!);
    }
  }

  /// Start periodic sync signal broadcast (host only)
  void _startSyncSignalBroadcast() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 1), // Periodic position sync while playing
      (_) => _broadcastSyncSignal(),
    );
    if (kDebugMode) {
      debugPrint('[SyncPlayerService] Started host sync broadcast');
    }
  }

  /// Start drift correction timer (client only)
  void _startDriftCorrectionTimer() {
    _driftCorrectionTimer?.cancel();
    _driftCorrectionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _performDriftCorrection(),
    );
    if (kDebugMode) {
      debugPrint('[SyncPlayerService] Started client drift correction');
    }
  }

  /// Broadcast current playback position for sync (only when playing)
  void _broadcastSyncSignal() {
    final playerState = _playerCubit.state;
    if (playerState.track == null) return;
    // Only broadcast periodic updates when playing
    if (!playerState.playing) return;

    _syncCubit.broadcastPlaybackState(
      isPlaying: playerState.playing,
      trackId: playerState.track?.trackId,
      trackTitle: playerState.track?.title,
      trackArtist: playerState.track?.artist,
      trackAlbum: playerState.track?.album,
      trackImageUrl: playerState.track?.imageUrl,
      position: playerState.position,
      duration: playerState.duration,
    );
  }

  /// Sync client to host's current position
  void _syncToHostPosition() {
    final syncState = _syncCubit.state;
    if (!syncState.isClient || syncState.remotePlaybackState == null) return;

    // Use the estimated position which accounts for time since received
    final targetPosition = syncState.remotePlaybackState!.estimatedPosition;

    if (kDebugMode) {
      debugPrint(
        '[SyncPlayerService] Initial sync: seeking to ${targetPosition.inMilliseconds}ms',
      );
    }

    _playerCubit.seek(targetPosition);
  }

  /// Perform drift correction
  void _performDriftCorrection() {
    if (!_isActive) return;

    final syncState = _syncCubit.state;
    if (!syncState.isClient || !syncState.isConnected) return;
    if (syncState.remotePlaybackState == null) return;

    final localState = _playerCubit.state;

    // Only correct drift when both are playing the same track
    if (localState.track?.trackId !=
        syncState.remotePlaybackState!.currentTrackId) {
      return;
    }

    // Only correct when playing
    if (!localState.playing || !syncState.remotePlaybackState!.isPlaying) {
      _resetPlaybackSpeed();
      return;
    }

    // Use the estimated position from SyncPlaybackState
    final estimatedHostPosition =
        syncState.remotePlaybackState!.estimatedPosition;

    // Calculate drift (positive = we're behind, negative = we're ahead)
    final driftMs =
        estimatedHostPosition.inMilliseconds -
        localState.position.inMilliseconds;

    // Add to drift samples for smoothing
    _driftSamples.add(driftMs);
    if (_driftSamples.length > _maxDriftSamples) {
      _driftSamples.removeAt(0);
    }

    // Calculate average drift
    final avgDrift =
        _driftSamples.reduce((a, b) => a + b) ~/ _driftSamples.length;

    if (kDebugMode) {
      debugPrint(
        '[SyncPlayerService] Drift: ${driftMs}ms (avg: ${avgDrift}ms)',
      );
    }

    // Large drift - seek directly
    if (avgDrift.abs() > _seekThresholdMs) {
      if (kDebugMode) {
        debugPrint('[SyncPlayerService] Large drift, seeking to host position');
      }
      _playerCubit.seek(estimatedHostPosition);
      _driftSamples.clear();
      _resetPlaybackSpeed();
      return;
    }

    // Medium drift - adjust playback speed
    if (avgDrift > _speedAdjustThresholdMs) {
      // We're behind - speed up
      _setPlaybackSpeed(_speedUpFactor);
    } else if (avgDrift < -_speedAdjustThresholdMs) {
      // We're ahead - slow down
      _setPlaybackSpeed(_speedDownFactor);
    } else {
      // Within tolerance - normal speed
      _resetPlaybackSpeed();
    }
  }

  /// Handle playback command from host
  void _handlePlaybackCommand(SyncPlaybackCommand command) {
    switch (command.command) {
      case 'play':
        if (!_playerCubit.state.playing) {
          _playerCubit.togglePlayPause();
        }
        break;
      case 'pause':
        if (_playerCubit.state.playing) {
          _playerCubit.togglePlayPause();
        }
        break;
      case 'seek':
        if (command.seekPosition != null) {
          _playerCubit.seek(command.seekPosition!);
        }
        break;
    }
  }

  /// Handle remote playback state from host
  void _handleRemotePlaybackState(SyncPlaybackState remoteState) {
    final localState = _playerCubit.state;

    // Check if we need to load the same track
    if (remoteState.currentTrackId != null &&
        remoteState.currentTrackId != localState.track?.trackId &&
        remoteState.currentTrackId != _loadingTrackId) {
      if (kDebugMode) {
        debugPrint(
          '[SyncPlayerService] Loading track from host: ${remoteState.currentTrackId}',
        );
      }
      _loadingTrackId = remoteState.currentTrackId;
      _driftSamples.clear();

      // Load the same track with full metadata
      _playerCubit.playTrackById(
        trackId: remoteState.currentTrackId!,
        title: remoteState.trackTitle,
        artist: remoteState.trackArtist,
        album: remoteState.trackAlbum,
        imageUrl: remoteState.trackImageUrl,
      );
      return;
    }

    // Sync play/pause state
    if (remoteState.currentTrackId == localState.track?.trackId) {
      if (remoteState.isPlaying && !localState.playing) {
        if (kDebugMode) {
          debugPrint('[SyncPlayerService] Starting playback to match host');
        }
        _playerCubit.togglePlayPause();
      } else if (!remoteState.isPlaying && localState.playing) {
        if (kDebugMode) {
          debugPrint('[SyncPlayerService] Pausing to match host');
        }
        _playerCubit.togglePlayPause();
      }
    }
  }

  /// Set playback speed for drift correction
  void _setPlaybackSpeed(double speed) {
    if (_currentSpeed == speed) return;
    _currentSpeed = speed;
    _playerCubit.setSpeed(speed);
    if (kDebugMode) {
      debugPrint('[SyncPlayerService] Setting playback speed to $speed');
    }
  }

  /// Reset playback speed to normal
  void _resetPlaybackSpeed() {
    if (_currentSpeed == 1.0) return;
    _currentSpeed = 1.0;
    _playerCubit.setSpeed(1.0);
    if (kDebugMode) {
      debugPrint('[SyncPlayerService] Reset playback speed to 1.0');
    }
  }

  void dispose() {
    stop();
  }
}
