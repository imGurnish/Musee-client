import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/domain/entities/cast_session_state.dart';
import 'package:musee/features/cast/domain/usecases/approve_device_auth.dart';
import 'package:musee/features/cast/domain/usecases/create_cast_session.dart';
import 'package:musee/features/cast/domain/usecases/create_device_auth_token.dart';
import 'package:musee/features/cast/domain/usecases/end_cast_session.dart';
import 'package:musee/features/cast/domain/usecases/join_cast_session.dart';
import 'package:musee/features/cast/domain/usecases/sync_playback_state.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';
import 'cast_event.dart';
import 'cast_state.dart';

class CastBloc extends Bloc<CastEvent, CastState> {
  final CreateCastSession _createCastSession;
  final JoinCastSession _joinCastSession;
  final EndCastSession _endCastSession;
  final SyncPlaybackState _syncPlaybackState;
  final CreateDeviceAuthToken _createDeviceAuthToken;
  final ApproveDeviceAuth _approveDeviceAuth;
  final CastRepository _castRepository;
  final PlayerCubit _playerCubit;
  final SettingsCubit _settingsCubit;

  StreamSubscription<PlayerViewState>? _playerSub;
  StreamSubscription<SettingsState>? _settingsSub;
  StreamSubscription<CastSessionState>? _remoteStateSub;
  StreamSubscription<Map<String, dynamic>>? _broadcastSub;
  StreamSubscription<dynamic>? _deviceAuthSub;
  StreamSubscription<List<CastReceiverDevice>>? _receiversSub;
  Timer? _positionTickTimer;

  String? _activeSessionId;
  String? _lastSyncedTrackId;

  CastBloc({
    required CreateCastSession createCastSession,
    required JoinCastSession joinCastSession,
    required EndCastSession endCastSession,
    required SyncPlaybackState syncPlaybackState,
    required CreateDeviceAuthToken createDeviceAuthToken,
    required ApproveDeviceAuth approveDeviceAuth,
    required CastRepository castRepository,
    required PlayerCubit playerCubit,
    required SettingsCubit settingsCubit,
  })  : _createCastSession = createCastSession,
        _joinCastSession = joinCastSession,
        _endCastSession = endCastSession,
        _syncPlaybackState = syncPlaybackState,
        _createDeviceAuthToken = createDeviceAuthToken,
        _approveDeviceAuth = approveDeviceAuth,
        _castRepository = castRepository,
        _playerCubit = playerCubit,
        _settingsCubit = settingsCubit,
        super(const CastIdle()) {
    on<StartCastSessionEvent>(_onStartCastSession);
    on<StartReceiverSessionEvent>(_onStartReceiverSession);
    on<JoinCastSessionByCodeEvent>(_onJoinByCode);
    on<EndCastSessionEvent>(_onEndSession);
    on<JoinAsReceiverEvent>(_onJoinAsReceiver);
    on<UpdateConnectedReceiversEvent>(_onUpdateConnectedReceivers);
    on<UpdateCastRemoteStateEvent>(_onUpdateCastRemoteState);
    on<SyncStateToReceiverEvent>(_onSyncState);
    on<BroadcastPositionTickEvent>(_onPositionTick);
    on<RemotePlayEvent>(_onRemotePlay);
    on<RemotePauseEvent>(_onRemotePause);
    on<RemoteSeekEvent>(_onRemoteSeek);
    on<RemoteNextEvent>(_onRemoteNext);
    on<RemotePreviousEvent>(_onRemotePrevious);
    on<RemoteSetVolumeEvent>(_onRemoteSetVolume);
    on<RemoteSetEqBandsEvent>(_onRemoteSetEqBands);
    on<RemoteSetBassEvent>(_onRemoteSetBass);
    on<RemoteSetSurroundEvent>(_onRemoteSetSurround);
    on<RemoteToggleEqEvent>(_onRemoteToggleEq);
    on<ApproveDeviceAuthEvent>(_onApproveDeviceAuth);
    on<CreateDeviceAuthTokenEvent>(_onCreateDeviceAuthToken);
  }

  // ---------------------------------------------------------------------------
  // Controller Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onStartCastSession(
    StartCastSessionEvent event,
    Emitter<CastState> emit,
  ) async {
    emit(const CastLoading());
    final res = await _createCastSession(
      CreateCastSessionParams(deviceName: event.deviceName),
    );

    await res.fold(
      (failure) async => emit(CastError(message: failure.message)),
      (session) async {
        _activeSessionId = session.id;
        emit(CastActive(session: session, role: CastRole.controller));
        _startControllerSync(session.id);
      },
    );
  }

  Future<void> _onJoinByCode(
    JoinCastSessionByCodeEvent event,
    Emitter<CastState> emit,
  ) async {
    emit(const CastLoading());
    final res = await _joinCastSession(
      JoinCastSessionParams(sessionCode: event.sessionCode),
    );

    await res.fold(
      (failure) async => emit(CastError(message: failure.message)),
      (session) async {
        _activeSessionId = session.id;
        emit(CastActive(session: session, role: CastRole.controller));
        _startControllerSync(session.id);
      },
    );
  }

  Future<void> _onEndSession(
    EndCastSessionEvent event,
    Emitter<CastState> emit,
  ) async {
    _cancelSubs();
    if (_activeSessionId != null) {
      await _endCastSession(EndCastSessionParams(sessionId: _activeSessionId!));
      _activeSessionId = null;
    }
    emit(const CastIdle());
  }

  void _onUpdateConnectedReceivers(
    UpdateConnectedReceiversEvent event,
    Emitter<CastState> emit,
  ) {
    if (state is CastActive) {
      emit((state as CastActive).copyWith(receivers: event.receivers));
    }
  }

  void _onUpdateCastRemoteState(
    UpdateCastRemoteStateEvent event,
    Emitter<CastState> emit,
  ) {
    if (state is CastActive) {
      emit((state as CastActive).copyWith(remoteState: event.remoteState));
    }
  }

  void _startControllerSync(String sessionId) {
    _cancelSubs();

    // Push initial state immediately
    _pushCurrentStateToSession(sessionId);

    // 1. Listen to PlayerCubit state changes
    _playerSub = _playerCubit.stream.listen((playerState) {
      final currentTrackId = playerState.track?.trackId;
      final isPlaying = playerState.playing;

      // Track or play state changed -> update DB state
      if (currentTrackId != _lastSyncedTrackId) {
        _lastSyncedTrackId = currentTrackId;
        _pushCurrentStateToSession(sessionId);
      } else {
        // Just broadcast ephemeral play/pause
        _castRepository.broadcastEvent(
          sessionId: sessionId,
          event: isPlaying ? 'play' : 'pause',
          payload: {
            'position_ms': playerState.position.inMilliseconds,
            'is_playing': isPlaying,
          },
        );
      }
    });

    // 2. Listen to SettingsCubit for EQ / sound changes
    _settingsSub = _settingsCubit.stream.listen((settings) {
      _castRepository.broadcastEvent(
        sessionId: sessionId,
        event: 'eq_update',
        payload: {
          'eq_enabled': settings.equalizerEnabled,
          'eq_preset': settings.equalizerPreset,
          'eq_bands': settings.equalizerBands,
          'bass_level': settings.bassLevel,
          'surround_level': settings.surroundLevel,
          'crossfade_enabled': settings.crossfadeEnabled,
          'normalize_volume': settings.normalizeVolume,
        },
      );

      // Commit to DB state as well
      add(SyncStateToReceiverEvent(
        eqEnabled: settings.equalizerEnabled,
        eqPreset: settings.equalizerPreset,
        eqBands: settings.equalizerBands,
        bassLevel: settings.bassLevel,
        surroundLevel: settings.surroundLevel,
        crossfadeEnabled: settings.crossfadeEnabled,
        normalizeVolume: settings.normalizeVolume,
      ));
    });

    // 3. Periodic position tick every 2s
    _positionTickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final pos = _playerCubit.state.position.inMilliseconds;
      if (_playerCubit.state.playing) {
        _castRepository.broadcastEvent(
          sessionId: sessionId,
          event: 'position_tick',
          payload: {'position_ms': pos},
        );
      }
    });

    // 4. Watch Connected Receivers on Controller
    _startWatchingReceivers(sessionId);

    // 5. Watch broadcast events on Controller (e.g. instant receiver joins)
    _broadcastSub = _castRepository
        .watchBroadcastEvents(sessionId)
        .listen((eventData) {
      final event = eventData['event'] as String? ?? '';
      if (event == 'receiver_joined' || event == 'receiver_left') {
        _refreshReceivers(sessionId);
      }
    });
  }

  void _startWatchingReceivers(String sessionId) {
    _receiversSub?.cancel();
    _receiversSub = _castRepository
        .watchConnectedReceivers(sessionId)
        .listen((receivers) {
      add(UpdateConnectedReceiversEvent(receivers: receivers));
    });
    _refreshReceivers(sessionId);
  }

  void _refreshReceivers(String sessionId) async {
    final res = await _castRepository.getConnectedReceivers(sessionId);
    res.fold((_) {}, (receivers) {
      add(UpdateConnectedReceiversEvent(receivers: receivers));
    });
  }

  void _pushCurrentStateToSession(String sessionId) {
    final playerState = _playerCubit.state;
    final settings = _settingsCubit.state;
    final queueIds = playerState.queue.map((item) => item.trackId).toList();
    final track = playerState.track;

    final durationMs = playerState.duration.inMilliseconds > 0
        ? playerState.duration.inMilliseconds
        : ((track?.durationSeconds ?? 0) * 1000);

    // 1. Broadcast instant track_change for 0-latency UI update on receiver
    if (track?.trackId != null) {
      _castRepository.broadcastEvent(
        sessionId: sessionId,
        event: 'track_change',
        payload: {
          'track_id': track!.trackId,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'image_url': track.imageUrl,
          'duration_ms': durationMs,
          'position_ms': playerState.position.inMilliseconds,
          'is_playing': playerState.playing,
        },
      );
    }

    // 2. Commit to database session state
    _syncPlaybackState(SyncPlaybackStateParams(
      sessionId: sessionId,
      currentTrackId: track?.trackId,
      currentTrackTitle: track?.title,
      currentTrackArtist: track?.artist,
      currentTrackAlbum: track?.album,
      currentTrackImageUrl: track?.imageUrl,
      currentTrackDurationMs: durationMs,
      queue: queueIds,
      queueIndex: playerState.currentIndex,
      positionMs: playerState.position.inMilliseconds,
      isPlaying: playerState.playing,
      volume: playerState.volume,
      shuffle: playerState.shuffleEnabled,
      repeatMode: playerState.repeatMode.name,
      eqEnabled: settings.equalizerEnabled,
      eqPreset: settings.equalizerPreset,
      eqBands: settings.equalizerBands,
      bassLevel: settings.bassLevel,
      surroundLevel: settings.surroundLevel,
      crossfadeEnabled: settings.crossfadeEnabled,
      normalizeVolume: settings.normalizeVolume,
    ));
  }

  Future<void> _onSyncState(
    SyncStateToReceiverEvent event,
    Emitter<CastState> emit,
  ) async {
    if (_activeSessionId == null) return;
    await _syncPlaybackState(SyncPlaybackStateParams(
      sessionId: _activeSessionId!,
      currentTrackId: event.currentTrackId,
      currentTrackTitle: event.currentTrackTitle,
      currentTrackArtist: event.currentTrackArtist,
      currentTrackAlbum: event.currentTrackAlbum,
      currentTrackImageUrl: event.currentTrackImageUrl,
      currentTrackDurationMs: event.currentTrackDurationMs,
      queue: event.queue,
      queueIndex: event.queueIndex,
      positionMs: event.positionMs,
      isPlaying: event.isPlaying,
      volume: event.volume,
      shuffle: event.shuffle,
      repeatMode: event.repeatMode,
      eqEnabled: event.eqEnabled,
      eqPreset: event.eqPreset,
      eqBands: event.eqBands,
      bassLevel: event.bassLevel,
      surroundLevel: event.surroundLevel,
      crossfadeEnabled: event.crossfadeEnabled,
      normalizeVolume: event.normalizeVolume,
    ));
  }

  Future<void> _onPositionTick(
    BroadcastPositionTickEvent event,
    Emitter<CastState> emit,
  ) async {
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'position_tick',
      payload: {'position_ms': event.positionMs},
    );
  }

  // ---------------------------------------------------------------------------
  // Remote Control Event Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onRemotePlay(RemotePlayEvent event, Emitter<CastState> emit) async {
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'play',
      payload: {'position_ms': _playerCubit.state.position.inMilliseconds},
    );
  }

  Future<void> _onRemotePause(RemotePauseEvent event, Emitter<CastState> emit) async {
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'pause',
      payload: {'position_ms': _playerCubit.state.position.inMilliseconds},
    );
  }

  Future<void> _onRemoteSeek(RemoteSeekEvent event, Emitter<CastState> emit) async {
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'seek',
      payload: {'position_ms': event.positionMs},
    );
  }

  Future<void> _onRemoteNext(RemoteNextEvent event, Emitter<CastState> emit) async {
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'next',
      payload: {},
    );
  }

  Future<void> _onRemotePrevious(RemotePreviousEvent event, Emitter<CastState> emit) async {
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'previous',
      payload: {},
    );
  }

  Future<void> _onRemoteSetVolume(RemoteSetVolumeEvent event, Emitter<CastState> emit) async {
    await _playerCubit.setVolume(event.volume);
    if (_activeSessionId == null) return;

    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'volume_change',
      payload: {'volume': event.volume},
    );

    if (state is CastActive) {
      final cur = state as CastActive;
      final updatedRemote = (cur.remoteState ?? CastSessionState(sessionId: cur.session.id)).copyWith(
        volume: event.volume,
      );
      emit(cur.copyWith(remoteState: updatedRemote));
    }

    unawaited(_castRepository.updateSessionState(
      sessionId: _activeSessionId!,
      volume: event.volume,
    ));
  }

  Future<void> _onRemoteSetEqBands(RemoteSetEqBandsEvent event, Emitter<CastState> emit) async {
    _settingsCubit.setEqualizerBands(event.bands);
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'eq_bands_change',
      payload: {'bands': event.bands},
    );
  }

  Future<void> _onRemoteSetBass(RemoteSetBassEvent event, Emitter<CastState> emit) async {
    _settingsCubit.setBassLevel(event.level);
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'bass_change',
      payload: {'level': event.level},
    );
  }

  Future<void> _onRemoteSetSurround(RemoteSetSurroundEvent event, Emitter<CastState> emit) async {
    _settingsCubit.setSurroundLevel(event.level);
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'surround_change',
      payload: {'level': event.level},
    );
  }

  Future<void> _onRemoteToggleEq(RemoteToggleEqEvent event, Emitter<CastState> emit) async {
    _settingsCubit.setEqualizerEnabled(event.enabled);
    if (_activeSessionId == null) return;
    await _castRepository.broadcastEvent(
      sessionId: _activeSessionId!,
      event: 'eq_toggle',
      payload: {'enabled': event.enabled},
    );
  }

  // ---------------------------------------------------------------------------
  // Receiver Handlers (TV / Car display)
  // ---------------------------------------------------------------------------

  Future<void> _onStartReceiverSession(
    StartReceiverSessionEvent event,
    Emitter<CastState> emit,
  ) async {
    emit(const CastLoading());
    final res = await _createCastSession(
      CreateCastSessionParams(deviceName: event.deviceName),
    );

    await res.fold(
      (failure) async => emit(CastError(message: failure.message)),
      (session) async {
        _activeSessionId = session.id;
        add(JoinAsReceiverEvent(
          sessionId: session.id,
          deviceName: event.deviceName,
        ));
      },
    );
  }

  Future<void> _onJoinAsReceiver(
    JoinAsReceiverEvent event,
    Emitter<CastState> emit,
  ) async {
    emit(const CastLoading());
    _activeSessionId = event.sessionId;

    await _castRepository.registerReceiver(
      sessionId: event.sessionId,
      deviceName: event.deviceName,
    );

    // Fetch actual session row so sessionCode (e.g. JAZZ42) is always available
    final sessionRes = await _castRepository.getSession(event.sessionId);
    final activeSession = sessionRes.getOrElse(
      (_) => CastSession(
        id: event.sessionId,
        ownerId: '',
        deviceName: event.deviceName,
        createdAt: DateTime.now(),
      ),
    );

    emit(CastActive(session: activeSession, role: CastRole.receiver));

    // 1. Fetch initial DB state
    final stateRes = await _castRepository.getSessionState(event.sessionId);
    stateRes.fold((_) {}, (initialState) {
      _applyFullStateToReceiver(initialState);
      add(UpdateCastRemoteStateEvent(remoteState: initialState));
    });

    // 2. Watch DB changes (track changes, queue updates)
    _remoteStateSub = _castRepository
        .watchSessionState(event.sessionId)
        .listen((updatedState) {
      _applyFullStateToReceiver(updatedState);
      add(UpdateCastRemoteStateEvent(remoteState: updatedState));
    });

    // 3. Watch Broadcast events (position ticks, play/pause, live EQ sliders, volume)
    _broadcastSub = _castRepository
        .watchBroadcastEvents(event.sessionId)
        .listen((eventData) {
      _handleIncomingBroadcastOnReceiver(eventData);
    });
  }

  void _applyFullStateToReceiver(CastSessionState remote) {
    // 1. Apply track if changed
    if (remote.currentTrackId != null &&
        remote.currentTrackId != _playerCubit.state.track?.trackId) {
      _playerCubit.playTrackById(
        trackId: remote.currentTrackId!,
        title: remote.currentTrackTitle,
        artist: remote.currentTrackArtist,
        album: remote.currentTrackAlbum,
        imageUrl: remote.currentTrackImageUrl,
      );
    }

    // 2. Apply volume
    _playerCubit.setVolume(remote.volume);

    // 3. Apply EQ & audio controls
    _settingsCubit.setEqualizerEnabled(remote.eqEnabled);
    if (remote.eqBands.isNotEmpty) {
      _settingsCubit.setEqualizerBands(remote.eqBands);
    }
    _settingsCubit.setBassLevel(remote.bassLevel);
    _settingsCubit.setSurroundLevel(remote.surroundLevel);
    _settingsCubit.setCrossfade(remote.crossfadeEnabled);
    _settingsCubit.setNormalizeVolume(remote.normalizeVolume);
  }

  void _handleIncomingBroadcastOnReceiver(Map<String, dynamic> data) {
    final event = data['event'] as String? ?? '';
    final payload = data['payload'] as Map<String, dynamic>? ?? data;

    switch (event) {
      case 'track_change':
        final trackId = payload['track_id'] as String?;
        final title = payload['title'] as String?;
        final artist = payload['artist'] as String?;
        final album = payload['album'] as String?;
        final imageUrl = payload['image_url'] as String?;
        final isPlaying = payload['is_playing'] as bool? ?? true;
        final durationMs = (payload['duration_ms'] as num?)?.toInt() ?? 0;

        if (trackId != null && trackId.isNotEmpty) {
          _playerCubit.playTrackById(
            trackId: trackId,
            title: title,
            artist: artist,
            album: album,
            imageUrl: imageUrl,
          );
        }

        if (state is CastActive) {
          final cur = state as CastActive;
          final updatedRemote = (cur.remoteState ?? CastSessionState(sessionId: cur.session.id)).copyWith(
            currentTrackId: trackId,
            currentTrackTitle: title,
            currentTrackArtist: artist,
            currentTrackAlbum: album,
            currentTrackImageUrl: imageUrl,
            currentTrackDurationMs: durationMs,
            isPlaying: isPlaying,
          );
          add(UpdateCastRemoteStateEvent(remoteState: updatedRemote));
        }
        break;

      case 'volume_change':
        final vol = (payload['volume'] as num?)?.toDouble() ?? 1.0;
        _playerCubit.setVolume(vol);
        if (state is CastActive) {
          final cur = state as CastActive;
          final updatedRemote = (cur.remoteState ?? CastSessionState(sessionId: cur.session.id)).copyWith(
            volume: vol,
          );
          add(UpdateCastRemoteStateEvent(remoteState: updatedRemote));
        }
        break;

      case 'position_tick':
        final targetMs = (payload['position_ms'] as num?)?.toInt() ?? 0;
        final currentMs = _playerCubit.state.position.inMilliseconds;
        // Only seek if drift exceeds 2 seconds
        if ((targetMs - currentMs).abs() > 2000) {
          _playerCubit.seek(Duration(milliseconds: targetMs));
        }
        break;

      case 'play':
        _playerCubit.ensurePlaying(ignoreUserPause: true);
        break;

      case 'pause':
        _playerCubit.togglePlayPause();
        break;

      case 'seek':
        final targetMs = (payload['position_ms'] as num?)?.toInt() ?? 0;
        _playerCubit.seek(Duration(milliseconds: targetMs));
        break;

      case 'next':
        _playerCubit.next(userInitiated: true);
        break;

      case 'previous':
        _playerCubit.previous();
        break;

      case 'eq_bands_change':
        final raw = payload['bands'];
        if (raw is List) {
          final bands = raw.map((e) => (e as num).toDouble()).toList();
          _settingsCubit.setEqualizerBands(bands);
        }
        break;

      case 'bass_change':
        final level = (payload['level'] as num?)?.toInt() ?? 0;
        _settingsCubit.setBassLevel(level);
        break;

      case 'surround_change':
        final level = (payload['level'] as num?)?.toInt() ?? 0;
        _settingsCubit.setSurroundLevel(level);
        break;

      case 'eq_toggle':
        final enabled = payload['enabled'] as bool? ?? true;
        _settingsCubit.setEqualizerEnabled(enabled);
        break;

      case 'session_ended':
        _cancelSubs();
        add(const EndCastSessionEvent());
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Device Auth (QR Sign-in Flow)
  // ---------------------------------------------------------------------------

  Future<void> _onCreateDeviceAuthToken(
    CreateDeviceAuthTokenEvent event,
    Emitter<CastState> emit,
  ) async {
    emit(const CastLoading());
    final res = await _createDeviceAuthToken(
      CreateDeviceAuthTokenParams(deviceName: event.deviceName),
    );

    await res.fold(
      (failure) async => emit(CastError(message: failure.message)),
      (token) async {
        emit(CastAwaitingDeviceAuth(authToken: token));

        _deviceAuthSub?.cancel();
        _deviceAuthSub = _castRepository
            .watchDeviceAuthToken(token.token)
            .listen((updatedToken) {
          if (updatedToken.isApproved) {
            _deviceAuthSub?.cancel();
          }
        });
      },
    );
  }

  Future<void> _onApproveDeviceAuth(
    ApproveDeviceAuthEvent event,
    Emitter<CastState> emit,
  ) async {
    final res = await _approveDeviceAuth(
      ApproveDeviceAuthParams(token: event.token),
    );
    res.fold(
      (failure) => emit(CastError(message: failure.message)),
      (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void _cancelSubs() {
    _playerSub?.cancel();
    _playerSub = null;
    _settingsSub?.cancel();
    _settingsSub = null;
    _remoteStateSub?.cancel();
    _remoteStateSub = null;
    _broadcastSub?.cancel();
    _broadcastSub = null;
    _positionTickTimer?.cancel();
    _positionTickTimer = null;
    _deviceAuthSub?.cancel();
    _deviceAuthSub = null;
    _receiversSub?.cancel();
    _receiversSub = null;
  }

  @override
  Future<void> close() {
    _cancelSubs();
    return super.close();
  }
}
