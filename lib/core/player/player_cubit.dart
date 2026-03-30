import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/features/player/domain/repository/player_repository.dart';
import 'package:musee/features/listening_history/data/models/listening_history_models.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/core/cache/services/image_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:musee/core/player/media_controls_service.dart';
import 'package:musee/core/platform/platform_io_stub.dart'
  if (dart.library.io) 'package:musee/core/platform/platform_io_native.dart'
  as platform_io;

import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerViewState> {
  final AudioPlayer _player;
  final PlayerRepository? _repo; // optional to allow previous initialization
  final TrackCacheService? _trackCache;
  final AudioCacheService? _audioCache;
  final ImageCacheService? _imageCache;
  final MusicProviderRegistry? _musicProviderRegistry;
  final ListeningHistoryRepository? _listeningHistoryRepository;
  final SupabaseClient? _supabaseClient;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlayerViewState>? _viewStateSub;
  Timer? _snapshotLogTimer;
  Timer? _playbackReassertTimer;
  Timer? _switchFailSafeTimer;
  DateTime? _currentTrackStartedAt;
  String? _currentTrackIdForLogging;
  String? _lastPublishedTrackKey;
  bool _isTrackSwitchInProgress = false;
  bool _isAdvancingNext = false;
  bool _userPaused = false;
  int _trackSwitchToken = 0;

  bool get _isBusySwitching => _isTrackSwitchInProgress || _isAdvancingNext;
  bool get isUserPausedIntent => _userPaused;

  void _armSwitchFailSafe(int switchToken) {
    _switchFailSafeTimer?.cancel();
    _switchFailSafeTimer = Timer(const Duration(seconds: 12), () {
      if (switchToken != _trackSwitchToken) return;
      _isTrackSwitchInProgress = false;
      _isAdvancingNext = false;
      emit(
        state.copyWith(
          buffering: false,
          resolvingUrl: false,
          isTransitioning: false,
          playing: _player.playing,
          clearErrorMessage: true,
        ),
      );
    });
  }

  void _clearSwitchFailSafe() {
    _switchFailSafeTimer?.cancel();
    _switchFailSafeTimer = null;
  }

  int _sanitizeIndex(int index, int queueLength) {
    if (queueLength <= 0) return -1;
    if (index < 0) return 0;
    if (index >= queueLength) return queueLength - 1;
    return index;
  }

  void _emitPlaybackError(String message) {
    emit(
      state.copyWith(
        buffering: false,
        resolvingUrl: false,
        isTransitioning: false,
        playing: false,
        errorMessage: message,
      ),
    );
  }

  PlayerCubit({
    PlayerRepository? repository,
    TrackCacheService? trackCache,
    AudioCacheService? audioCache,
    ImageCacheService? imageCache,
    MusicProviderRegistry? musicProviderRegistry,
     ListeningHistoryRepository? listeningHistoryRepository,
     SupabaseClient? supabaseClient,
  }) : _player = AudioPlayer(),
       _repo = repository,
       _trackCache = trackCache,
       _audioCache = audioCache,
       _imageCache = imageCache,
       _musicProviderRegistry = musicProviderRegistry,
       _listeningHistoryRepository = listeningHistoryRepository,
       _supabaseClient = supabaseClient,
       super(const PlayerViewState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    await MediaControlsService.instance.initialize();
    MediaControlsService.instance.configureCallbacks(
      MediaControlCallbacks(
        onPlay: () async {
          try {
            await ensurePlaying(ignoreUserPause: true);
          } catch (e) {
            _emitPlaybackError('Unable to resume playback.');
            if (kDebugMode) {
              debugPrint('[PlayerCubit] Media onPlay callback failed: $e');
            }
          }
        },
        onPause: () async {
          try {
            _userPaused = true;
            _playbackReassertTimer?.cancel();
            await _player.pause();
          } catch (e) {
            _emitPlaybackError('Unable to pause playback.');
            if (kDebugMode) {
              debugPrint('[PlayerCubit] Media onPause callback failed: $e');
            }
          }
        },
        onNext: () async {
          try {
            await next(userInitiated: true);
          } catch (e) {
            _emitPlaybackError('Unable to skip to next track.');
            if (kDebugMode) {
              debugPrint('[PlayerCubit] Media onNext callback failed: $e');
            }
          }
        },
        onPrevious: () async {
          try {
            await previous();
          } catch (e) {
            _emitPlaybackError('Unable to go to previous track.');
            if (kDebugMode) {
              debugPrint('[PlayerCubit] Media onPrevious callback failed: $e');
            }
          }
        },
        onSeek: (position) async {
          try {
            await seek(position);
          } catch (e) {
            _emitPlaybackError('Unable to seek track.');
            if (kDebugMode) {
              debugPrint('[PlayerCubit] Media onSeek callback failed: $e');
            }
          }
        },
        onStop: () async {
          _userPaused = false;
          await _player.stop();
          emit(
            state.copyWith(
              playing: false,
              buffering: false,
              resolvingUrl: false,
              isTransitioning: false,
            ),
          );
        },
      ),
    );

    _positionSub = _player.positionStream.listen((pos) {
      emit(state.copyWith(position: pos));
    });
    _durationSub = _player.durationStream.listen((dur) {
      emit(state.copyWith(duration: dur ?? Duration.zero));
    });
    _playerStateSub = _player.playerStateStream.listen((ps) async {
      final playing = ps.playing;
      if (playing) {
        _userPaused = false;
      }
      final buffering =
          ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      emit(
        state.copyWith(
          playing: playing,
          buffering: buffering,
          isTransitioning: _isBusySwitching,
        ),
      );

      // Auto-advance when current track completes
      if (ps.processingState == ProcessingState.completed && !_isTrackSwitchInProgress && !_isAdvancingNext) {
        unawaited(_playNextInternal());
      }
    });

    _viewStateSub = stream.listen((viewState) {
      _publishNowPlaying(viewState);
    });

    _publishNowPlaying(state);

    // Load existing queue from backend if available
    final repo = _repo;
    if (repo != null) {
      unawaited(loadQueue());
    }
  }

  // Resolve playable URL with cache-first strategy
  Future<String?> _fetchPlayableUrl(String trackId, {bool forceRefresh = false}) async {
    // 1. Check local audio cache first (for offline playback)
    if (_audioCache != null && !kIsWeb) {
      final localPath = await _audioCache.getLocalAudioPath(trackId);
      if (localPath != null && await platform_io.fileExists(localPath)) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Playing from local cache: $localPath');
        }
        return localPath;
      }
    }

    // 2. Check if we have a cached streaming URL (avoids API call)
    final cachedTrack = await _trackCache?.getTrack(trackId);
    if (!forceRefresh &&
        cachedTrack?.streamingUrl != null &&
        cachedTrack!.streamingUrl!.trim().isNotEmpty) {
      // NOTE: We could add expiry check here if needed
      if (kDebugMode) {
        debugPrint(
          '[PlayerCubit] Using cached streaming URL for track: $trackId',
        );
      }
      return cachedTrack.streamingUrl;
    }

    // 3. Fetch from MusicProviderRegistry (Backend or External)
    if (_musicProviderRegistry != null) {
      try {
        final url = await _musicProviderRegistry
          .getStreamUrl(trackId)
          .timeout(const Duration(seconds: 8));

        if (url != null && url.trim().isNotEmpty) {
          // 4. Cache metadata and streaming URL (and download image)
          // Run in background so playback start is not blocked.
          unawaited(_cacheTrackMetadata(trackId, url));

          return url;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Error fetching stream URL: $e');
        }
      }
    }

    // Fallback if no provider registry (shouldn't happen in new setup)
    // or if provider failed and returning null
    return null;
  }

  /// Cache track metadata from MusicProvider
  Future<void> _cacheTrackMetadata(
    String trackId,
    String streamingUrl, {
    PlayerTrack? fallback,
  }) async {
    if (_trackCache == null || _musicProviderRegistry == null) return;

    try {
      var track = await _musicProviderRegistry.getTrack(trackId);

      // If remote fetch fails, try to use fallback data
      if (track == null && fallback != null) {
        if (kDebugMode) {
          debugPrint(
            '[PlayerCubit] getTrack failed, using fallback for $trackId',
          );
        }
        // Fallback available, will use it below
      } else if (track == null) {
        if (kDebugMode) {
          debugPrint(
            '[PlayerCubit] getTrack returned null for $trackId and no fallback',
          );
        }
        return;
      }

      if (kDebugMode && track != null) {
        debugPrint('[PlayerCubit] caching track: ${track.title}');
      }

      // Download album artwork (if we have a URL from track or fallback)
      String? imageUrl = track?.imageUrl ?? fallback?.imageUrl;
      String? localImagePath;
      if (_imageCache != null && imageUrl != null) {
        try {
          localImagePath = await _imageCache.cacheImage(imageUrl);
        } catch (_) {}
      }

      final existing = await _trackCache.getTrack(trackId);
      final playCount = existing?.playCount ?? 0;

      final cached = CachedTrack()
        ..trackId = trackId
        ..title = track?.title ?? fallback?.title ?? 'Unknown Title'
        ..albumId = track?.albumId
        ..albumTitle = track?.albumTitle ?? fallback?.album
        ..albumCoverUrl = imageUrl
        ..artistName =
            track?.artists.map((a) => a.name).join(', ') ??
            fallback?.artist ??
            'Unknown Artist'
        ..durationSeconds = track?.durationSeconds ?? 0
        ..isExplicit = track?.isExplicit ?? false
        ..streamingUrl = streamingUrl
        ..cachedAt = DateTime.now()
        ..lastPlayedAt = DateTime.now()
        ..sourceProvider = track?.source.name ?? 'musee'
        ..playCount = playCount
        ..localImagePath = localImagePath; // Save local path!

      if (existing != null) {
        // Preserve audio cache info
        cached.localAudioPath = existing.localAudioPath;
        cached.audioSizeBytes = existing.audioSizeBytes;
      }

      await _trackCache.cacheTrack(cached);
      if (kDebugMode) {
        print(
          '[PlayerCubit] Cached track metadata: $trackId (${cached.sourceProvider})',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PlayerCubit] Failed to cache track metadata: $e');
      }
    }
  }

  Future<void> playTrack(PlayerTrack track) async {
    _userPaused = false;
    if (track.trackId != null && state.track?.trackId != track.trackId) {
      unawaited(_logCurrentTrackPlay(wasSkipped: true));
    }

    final switchToken = ++_trackSwitchToken;
    _playbackReassertTimer?.cancel();
    _isTrackSwitchInProgress = true;
    _armSwitchFailSafe(switchToken);

    emit(
      state.copyWith(
        track: track,
        buffering: true,
        resolvingUrl: false,
        isTransitioning: true,
        playing: false,
        clearErrorMessage: true,
      ),
    );

    // Cache metadata if we have a track ID (e.g. from Search)
    if (track.trackId != null && track.url.isNotEmpty && _trackCache != null) {
      // Run in background to not block immediate playback
      unawaited(
        _cacheTrackMetadata(track.trackId!, track.url, fallback: track),
      );
    }

    try {
      final headers = track.headers ?? const <String, String>{};

      Uri toUri(String inputUrl) {
        if (inputUrl.startsWith('http') || inputUrl.startsWith('https')) {
          return Uri.parse(inputUrl);
        }
        return Uri.file(inputUrl);
      }

      await _player.setAudioSource(
        AudioSource.uri(
          toUri(track.url),
          headers: headers.isEmpty ? null : headers,
        ),
      );

      if (_userPaused) {
        await _player.pause();
        if (switchToken == _trackSwitchToken) {
          emit(
            state.copyWith(
              track: track,
              buffering: false,
              resolvingUrl: false,
              isTransitioning: false,
              playing: false,
              clearErrorMessage: true,
            ),
          );
        }
        return;
      }

      final started = await _ensurePlaybackStarted();
      if (!started) {
        if (_userPaused) {
          if (switchToken == _trackSwitchToken) {
            emit(
              state.copyWith(
                track: track,
                buffering: false,
                resolvingUrl: false,
                isTransitioning: false,
                playing: false,
                clearErrorMessage: true,
              ),
            );
          }
          return;
        }
        throw StateError('Playback did not start for selected track');
      }

      if (switchToken == _trackSwitchToken) {
        emit(
          state.copyWith(
            track: track,
            buffering: false,
            resolvingUrl: false,
            isTransitioning: false,
            playing: true,
            clearErrorMessage: true,
          ),
        );
        _schedulePlaybackReassertion(switchToken);
      }

      _markTrackSessionStart(track.trackId);
      unawaited(_refreshQueueIfNeeded());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PlayerCubit] Primary playTrack start failed: $e');
      }

      try {
        if (track.trackId == null) {
          throw StateError('Cannot refresh URL for ad-hoc track');
        }

        final refreshedUrl = await _fetchPlayableUrl(
          track.trackId!,
          forceRefresh: true,
        );

        if (refreshedUrl == null || refreshedUrl.trim().isEmpty) {
          throw StateError('Refreshed URL unavailable');
        }

        final refreshedTrack = track.copyWith(url: refreshedUrl);
        final headers = refreshedTrack.headers ?? const <String, String>{};

        Uri toUri(String inputUrl) {
          if (inputUrl.startsWith('http') || inputUrl.startsWith('https')) {
            return Uri.parse(inputUrl);
          }
          return Uri.file(inputUrl);
        }

        if (switchToken != _trackSwitchToken) return;

        emit(
          state.copyWith(
            track: refreshedTrack,
            buffering: true,
            resolvingUrl: false,
            isTransitioning: true,
            playing: false,
            clearErrorMessage: true,
          ),
        );

        await _player.setAudioSource(
          AudioSource.uri(
            toUri(refreshedTrack.url),
            headers: headers.isEmpty ? null : headers,
          ),
        );

        if (_userPaused) {
          await _player.pause();
          if (switchToken == _trackSwitchToken) {
            emit(
              state.copyWith(
                track: refreshedTrack,
                buffering: false,
                resolvingUrl: false,
                isTransitioning: false,
                playing: false,
                clearErrorMessage: true,
              ),
            );
          }
          return;
        }

        final started = await _ensurePlaybackStarted();
        if (!started) {
          if (_userPaused) {
            if (switchToken == _trackSwitchToken) {
              emit(
                state.copyWith(
                  track: refreshedTrack,
                  buffering: false,
                  resolvingUrl: false,
                  isTransitioning: false,
                  playing: false,
                  clearErrorMessage: true,
                ),
              );
            }
            return;
          }
          throw StateError('Playback did not start after URL refresh');
        }

        if (switchToken == _trackSwitchToken) {
          emit(
            state.copyWith(
              track: refreshedTrack,
              buffering: false,
              resolvingUrl: false,
              isTransitioning: false,
              playing: true,
              clearErrorMessage: true,
            ),
          );
          _schedulePlaybackReassertion(switchToken);
        }

        _markTrackSessionStart(refreshedTrack.trackId);
        unawaited(_refreshQueueIfNeeded());
      } catch (retryError) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Retry playTrack start failed: $retryError');
        }
        if (switchToken == _trackSwitchToken) {
          _emitPlaybackError('Unable to start this track. Please try again.');
        }
      }
    } finally {
      if (switchToken == _trackSwitchToken) {
        _isTrackSwitchInProgress = false;
        _clearSwitchFailSafe();
        emit(state.copyWith(isTransitioning: false));
      }
    }
  }

  /// Play a track by ID, resolving the URL via MusicProviderRegistry.
  /// This ensures metadata caching and proper offline support.
  Future<void> playTrackById({
    required String trackId,
    String? title,
    String? artist,
    String? album,
    String? imageUrl,
  }) async {
    _userPaused = false;
    if (state.track?.trackId != null && state.track?.trackId != trackId) {
      unawaited(_logCurrentTrackPlay(wasSkipped: true));
    }

    emit(
      state.copyWith(
        resolvingUrl: true,
        buffering: true,
        isTransitioning: true,
        playing: false,
        clearErrorMessage: true,
      ),
    );

    final repo = _repo;
    if (repo != null) {
      unawaited(() async {
        try {
          final expanded = await repo.playQueueFrom(
            trackId: trackId,
            expand: true,
            metadata: {
              if (title != null && title.isNotEmpty) 'title': title,
              if (artist != null && artist.isNotEmpty) 'artist': artist,
              if (imageUrl != null && imageUrl.isNotEmpty) 'cover_url': imageUrl,
            },
          );
          final items = await _mapToQueueItems(expanded);
          int newIndex = items.indexWhere((q) => q.trackId == trackId);
          if (newIndex < 0 && items.isNotEmpty) {
            final fallback = QueueItem(
              trackId: trackId,
              title: title ?? 'Unknown Title',
              artist: artist ?? 'Unknown Artist',
              album: album,
              imageUrl: imageUrl,
              uid: const Uuid().v4(),
            );
            items.insert(0, fallback);
            newIndex = 0;
          }
          emit(
            state.copyWith(
              queue: items,
              currentIndex: _sanitizeIndex(newIndex, items.length),
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PlayerCubit] playQueueFrom failed (background sync): $e');
          }
        }
      }());
    }

    final url = await _fetchPlayableUrl(trackId);
    if (url == null) {
      emit(
        state.copyWith(
          buffering: false,
          resolvingUrl: false,
          isTransitioning: false,
          playing: false,
        ),
      );
      return;
    }

    // Metadata will be cached by _fetchPlayableUrl (which calls _cacheTrackMetadata internally)
    // But we also need to pass initial display metadata to PlayerTrack

    final track = PlayerTrack(
      trackId: trackId,
      url: url,
      title: title ?? 'Unknown Title',
      artist: artist ?? 'Unknown Artist',
      album: album,
      imageUrl: imageUrl,
    );

    await playTrack(track);
  }

  // Queue APIs
  Future<List<QueueItem>> _mapToQueueItems(List<dynamic> expanded) async {
    if (_trackCache == null) {
      return expanded.map((m) => QueueItem.fromExpandedJson(m)).toList();
    }
    final futures = expanded.map((m) async {
      var item = QueueItem.fromExpandedJson(m);
      try {
        final cached = await _trackCache.getTrack(item.trackId);
        if (cached?.localImagePath != null) {
          item = item.copyWith(localImagePath: cached!.localImagePath);
        }
      } catch (_) {}
      return item;
    });
    return Future.wait(futures);
  }

  Future<void> loadQueue() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final expanded = await repo.getQueueExpanded();
      final items = await _mapToQueueItems(expanded);
      emit(
        state.copyWith(
          queue: items,
          currentIndex: _sanitizeIndex(state.currentIndex, items.length),
        ),
      );
      await _refreshQueueIfNeeded();
    } catch (_) {}
  }

  Future<void> playFromQueueTrackId(String trackId) async {
    if (state.track?.trackId != null && state.track?.trackId != trackId) {
      unawaited(_logCurrentTrackPlay(wasSkipped: true));
    }

    final localIdx = state.queue.indexWhere((q) => q.trackId == trackId);
    if (localIdx >= 0) {
      await _playAtIndex(localIdx);
      unawaited(_refreshQueueIfNeeded());
    }

    final repo = _repo;
    if (repo != null) {
      unawaited(() async {
        try {
          final expanded = await repo.playQueueFrom(
            trackId: trackId,
            expand: true,
          );
          final items = await _mapToQueueItems(expanded);
          final currentTrackId = state.track?.trackId;
          final syncedIndex = currentTrackId == null
              ? -1
              : items.indexWhere((q) => q.trackId == currentTrackId);
          final safeSyncedIndex = syncedIndex >= 0
              ? syncedIndex
              : _sanitizeIndex(state.currentIndex, items.length);
          emit(state.copyWith(queue: items, currentIndex: safeSyncedIndex));
        } catch (_) {}
      }());
    }

    if (localIdx < 0) {
      // Fallback: play single by resolving URL
      final url = await _fetchPlayableUrl(trackId);
      if (url != null) {
        await playTrack(
          PlayerTrack(trackId: trackId, url: url, title: 'Unknown', artist: 'Unknown'),
        );
      } else {
        _emitPlaybackError('Unable to load selected track from queue.');
      }
    }
  }

  Future<void> addToQueue(List<QueueItem> items) async {
    emit(state.copyWith(queue: [...state.queue, ...items]));
    final repo = _repo;
    if (repo != null) {
      unawaited(
        repo.addToQueue(trackIds: items.map((e) => e.trackId).toList()),
      );
    }
  }

  Future<void> removeFromQueue(String uid) async {
    final removedIndex = state.queue.indexWhere((e) => e.uid == uid);
    if (removedIndex < 0) return;

    final item = state.queue[removedIndex];
    final newList = [...state.queue]..removeAt(removedIndex);

    // Calculate new index correctly:
    // - If removed item is before current: shift index back by 1
    // - If removed item IS current: keep same index (next item slides in)
    // - If removed item is after current: no change
    int newIndex = state.currentIndex;
    if (removedIndex < state.currentIndex) {
      newIndex = state.currentIndex - 1;
    } else if (removedIndex == state.currentIndex) {
      // Current track was removed; clamp to valid range
      newIndex = newIndex.clamp(-1, newList.length - 1);
    }
    // If newList is empty, reset to -1
    if (newList.isEmpty) newIndex = -1;

    emit(
      state.copyWith(
        queue: newList,
        currentIndex: _sanitizeIndex(newIndex, newList.length),
      ),
    );

    final repo = _repo;
    if (repo != null) {
      unawaited(repo.removeFromQueue(trackId: item.trackId));
    }
  }

  Future<void> reorderQueue(int from, int to) async {
    final list = [...state.queue];
    if (from < 0 || from >= list.length || to < 0 || to >= list.length) return;
    if (from == to) return; // No-op

    final item = list.removeAt(from);
    list.insert(to, item);

    // Adjust current index based on the move
    int newIndex = state.currentIndex;
    if (state.currentIndex == from) {
      // Moving the currently playing track
      newIndex = to;
    } else if (from < state.currentIndex && to >= state.currentIndex) {
      // Moved something from before current to at/after current
      newIndex = state.currentIndex - 1;
    } else if (from > state.currentIndex && to <= state.currentIndex) {
      // Moved something from after current to at/before current
      newIndex = state.currentIndex + 1;
    }

    emit(
      state.copyWith(
        queue: list,
        currentIndex: _sanitizeIndex(newIndex, list.length),
      ),
    );

    final repo = _repo;
    if (repo != null) {
      unawaited(repo.reorderQueue(fromIndex: from, toIndex: to));
    }
  }

  Future<void> clearQueue() async {
    emit(
      state.copyWith(
        queue: const <QueueItem>[],
        currentIndex: -1,
        isTransitioning: false,
        resolvingUrl: false,
      ),
    );
    final repo = _repo;
    if (repo != null) {
      unawaited(repo.clearQueue());
    }
  }

  Future<void> next({bool userInitiated = true}) async {
    // userInitiated true when tapped button; false when auto-advance
    if (_isBusySwitching) return;
    await _playNextInternal(userInitiated: userInitiated);
  }

  Future<void> previous() async {
    if (_isBusySwitching) return;
    final idx = state.currentIndex;
    if (idx > 0) {
      await _playAtIndex(idx - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> _playNextInternal({bool userInitiated = false}) async {
    _userPaused = false;
    if (_isAdvancingNext) return;
    _isAdvancingNext = true;
    emit(
      state.copyWith(
        isTransitioning: true,
        resolvingUrl: true,
        clearErrorMessage: true,
      ),
    );
    unawaited(_logCurrentTrackPlay(wasSkipped: userInitiated));

    try {
      final currentIdx = state.currentIndex;

      // Check if there's a next track
      if (currentIdx + 1 < state.queue.length) {
        // Simply advance to next track - don't remove current
        // This is cleaner and avoids index confusion
        final nextIndex = currentIdx + 1;
        await _playAtIndex(nextIndex);
        unawaited(_refreshQueueIfNeeded());
      } else {
        // End of queue - stop playback
        await _player.stop();
        emit(
          state.copyWith(
            playing: false,
            buffering: false,
            resolvingUrl: false,
            isTransitioning: false,
          ),
        );
        unawaited(_refreshQueueIfNeeded());
      }
    } finally {
      _isAdvancingNext = false;
      emit(state.copyWith(isTransitioning: _isTrackSwitchInProgress));
    }
  }

  Future<void> _playAtIndex(int index) async {
    _userPaused = false;
    if (index < 0 || index >= state.queue.length) return;
    if (_isTrackSwitchInProgress) return;

    _isTrackSwitchInProgress = true;
    final switchToken = ++_trackSwitchToken;
    _playbackReassertTimer?.cancel();
    _armSwitchFailSafe(switchToken);

    final item = state.queue[index];

    final existingUrl = state.track?.url;
    final canUseProvisionalUrl = existingUrl != null && existingUrl.trim().isNotEmpty;
    final provisionalTrack = canUseProvisionalUrl
        ? PlayerTrack(
            trackId: item.trackId,
            url: existingUrl,
            title: item.title.isEmpty ? 'Unknown Title' : item.title,
            artist: item.artist.isEmpty ? 'Unknown Artist' : item.artist,
            album: item.album,
            imageUrl: item.imageUrl,
            localImagePath: item.localImagePath,
          )
        : null;
    emit(
      state.copyWith(
        track: provisionalTrack ?? state.track,
        buffering: true,
        resolvingUrl: true,
        isTransitioning: true,
        currentIndex: index,
        playing: false,
        clearErrorMessage: true,
      ),
    );

    final url = await _fetchPlayableUrl(item.trackId);
    if (url == null || url.trim().isEmpty) {
      if (switchToken == _trackSwitchToken) {
        _clearSwitchFailSafe();
        emit(
          state.copyWith(
            buffering: false,
            resolvingUrl: false,
            isTransitioning: false,
            playing: false,
          ),
        );
        _isTrackSwitchInProgress = false;
      }
      return;
    }

    if (switchToken != _trackSwitchToken) {
      _clearSwitchFailSafe();
      _isTrackSwitchInProgress = false;
      return;
    }

    final track = PlayerTrack(
      trackId: item.trackId,
      url: url,
      title: item.title.isEmpty ? 'Unknown Title' : item.title,
      artist: item.artist.isEmpty ? 'Unknown Artist' : item.artist,
      album: item.album,
      imageUrl: item.imageUrl,
      localImagePath: item.localImagePath,
    );

    try {
      final uri = url.startsWith('http') || url.startsWith('https')
          ? Uri.parse(url)
          : Uri.file(url);

      await _player.setAudioSource(AudioSource.uri(uri));

      if (_userPaused) {
        await _player.pause();
        if (switchToken == _trackSwitchToken) {
          emit(
            state.copyWith(
              track: track,
              buffering: false,
              resolvingUrl: false,
              isTransitioning: false,
              playing: false,
              currentIndex: index,
              clearErrorMessage: true,
            ),
          );
        }
        return;
      }

      final started = await _ensurePlaybackStarted();
      if (!started) {
        if (_userPaused) {
          if (switchToken == _trackSwitchToken) {
            emit(
              state.copyWith(
                track: track,
                buffering: false,
                resolvingUrl: false,
                isTransitioning: false,
                playing: false,
                currentIndex: index,
                clearErrorMessage: true,
              ),
            );
          }
          return;
        }
        throw StateError('Playback did not start after source switch');
      }
      if (switchToken == _trackSwitchToken) {
        emit(
          state.copyWith(
            track: track,
            buffering: false,
            resolvingUrl: false,
            isTransitioning: false,
            playing: true,
            currentIndex: index,
            clearErrorMessage: true,
          ),
        );
        _schedulePlaybackReassertion(switchToken);
      }
      _markTrackSessionStart(item.trackId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PlayerCubit] Primary play failed for ${item.trackId}: $e');
      }

      try {
        final refreshedUrl = await _fetchPlayableUrl(item.trackId, forceRefresh: true);
        if (refreshedUrl == null || refreshedUrl.trim().isEmpty) {
          _emitPlaybackError('Unable to refresh stream URL for this track.');
          return;
        }

        final refreshedTrack = track.copyWith(url: refreshedUrl);
        if (switchToken != _trackSwitchToken) {
          _isTrackSwitchInProgress = false;
          return;
        }
        emit(
          state.copyWith(
            track: refreshedTrack,
            buffering: true,
            resolvingUrl: false,
            isTransitioning: true,
            currentIndex: index,
            playing: false,
            clearErrorMessage: true,
          ),
        );

        final refreshedUri = refreshedUrl.startsWith('http') || refreshedUrl.startsWith('https')
            ? Uri.parse(refreshedUrl)
            : Uri.file(refreshedUrl);

        await _player.setAudioSource(AudioSource.uri(refreshedUri));

        if (_userPaused) {
          await _player.pause();
          if (switchToken == _trackSwitchToken) {
            emit(
              state.copyWith(
                track: refreshedTrack,
                buffering: false,
                resolvingUrl: false,
                isTransitioning: false,
                playing: false,
                currentIndex: index,
                clearErrorMessage: true,
              ),
            );
          }
          return;
        }

        final started = await _ensurePlaybackStarted();
        if (!started) {
          if (_userPaused) {
            if (switchToken == _trackSwitchToken) {
              emit(
                state.copyWith(
                  track: refreshedTrack,
                  buffering: false,
                  resolvingUrl: false,
                  isTransitioning: false,
                  playing: false,
                  currentIndex: index,
                  clearErrorMessage: true,
                ),
              );
            }
            return;
          }
          throw StateError('Playback did not start after retry source switch');
        }
        if (switchToken == _trackSwitchToken) {
          emit(
            state.copyWith(
              track: refreshedTrack,
              buffering: false,
              resolvingUrl: false,
              isTransitioning: false,
              playing: true,
              currentIndex: index,
              clearErrorMessage: true,
            ),
          );
          _schedulePlaybackReassertion(switchToken);
        }
        _markTrackSessionStart(item.trackId);
      } catch (retryError) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Retry play failed for ${item.trackId}: $retryError');
        }
        if (switchToken == _trackSwitchToken) {
          _emitPlaybackError('Unable to play this track. Please try again.');
        }
      }
    } finally {
      if (switchToken == _trackSwitchToken) {
        _isTrackSwitchInProgress = false;
        _clearSwitchFailSafe();
        emit(state.copyWith(isTransitioning: false, resolvingUrl: false));
      }
    }
  }

  Future<bool> _ensurePlaybackStarted({
    int maxAttempts = 5,
    Duration perAttemptTimeout = const Duration(milliseconds: 900),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      if (_userPaused) return false;
      if (_player.playing) return true;

      await _player.play();

      if (_userPaused) {
        await _player.pause();
        return false;
      }

      if (_player.playing) return true;

      try {
        await _player.playerStateStream
            .firstWhere((state) => state.playing)
            .timeout(perAttemptTimeout);

        if (_player.playing) return true;
      } catch (_) {
        // Continue retry loop.
      }
    }

    return _player.playing;
  }

  void _schedulePlaybackReassertion(int switchToken) {
    _playbackReassertTimer?.cancel();
    _playbackReassertTimer = Timer(const Duration(milliseconds: 900), () async {
      if (switchToken != _trackSwitchToken) return;
      if (_isTrackSwitchInProgress) return;
      if (_userPaused) return;

      final current = _player.playerState;
      if (!current.playing && current.processingState != ProcessingState.completed) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Reasserting playback after switch token=$switchToken');
        }
        try {
          await _player.play();
          emit(state.copyWith(playing: _player.playing, buffering: false));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PlayerCubit] Reassert play failed: $e');
          }
        }
      }
    });
  }

  void _markTrackSessionStart(String? trackId) {
    if (trackId == null || trackId.isEmpty) return;
    _snapshotLogTimer?.cancel();
    _currentTrackIdForLogging = trackId;
    _currentTrackStartedAt = DateTime.now();
    unawaited(_trackCache?.updateLastPlayed(trackId));

    _snapshotLogTimer = Timer(const Duration(seconds: 12), () async {
      if (state.track?.trackId == trackId && _player.playing) {
        await _logCurrentTrackPlay(wasSkipped: false, preserveSession: true);
      }
    });
  }

  Future<void> _logCurrentTrackPlay({
    required bool wasSkipped,
    bool preserveSession = false,
  }) async {
    final listeningRepo = _listeningHistoryRepository;
    final supabase = _supabaseClient;
    final trackId = _currentTrackIdForLogging ?? state.track?.trackId;

    if (listeningRepo == null || supabase == null || trackId == null) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    final startedAt = _currentTrackStartedAt;
    final playerPositionSeconds = _player.position.inSeconds;
    final fallbackElapsedSeconds = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inSeconds;
    final timeListenedSeconds = playerPositionSeconds > 0
        ? playerPositionSeconds
        : fallbackElapsedSeconds;

    if (timeListenedSeconds < 3) {
      if (!preserveSession) {
        _currentTrackStartedAt = null;
        _currentTrackIdForLogging = null;
      }
      return;
    }

    final currentQueueItem = (state.currentIndex >= 0 && state.currentIndex < state.queue.length)
        ? state.queue[state.currentIndex]
        : null;

    final totalDurationSeconds = state.duration.inSeconds > 0
        ? state.duration.inSeconds
        : (currentQueueItem?.durationSeconds ?? 0);
    final completionPercentage = totalDurationSeconds > 0
        ? ((timeListenedSeconds / totalDurationSeconds) * 100).clamp(0, 100).toDouble()
        : 0.0;

    final deviceType = kIsWeb
      ? 'web'
      : (platform_io.isAndroidOrIOS ? 'mobile' : 'desktop');

    final listeningContext = state.currentIndex >= 0 ? 'playlist' : 'library';

    try {
      await listeningRepo.logTrackPlay(
        TrackPlayData(
          userId: userId,
          trackId: trackId,
          timeListenedSeconds: timeListenedSeconds,
          totalDurationSeconds: totalDurationSeconds,
          completionPercentage: completionPercentage,
          wasSkipped: wasSkipped,
          skipAtSeconds: wasSkipped ? timeListenedSeconds : null,
          listeningContext: listeningContext,
          contextId: null,
          deviceType: deviceType,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PlayerCubit] Failed to log track play: $e');
      }
    } finally {
      if (!preserveSession) {
        _snapshotLogTimer?.cancel();
        _snapshotLogTimer = null;
        _currentTrackStartedAt = null;
        _currentTrackIdForLogging = null;
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      _userPaused = true;
      _playbackReassertTimer?.cancel();
      await _player.pause();
      return;
    } else {
      if (_isTrackSwitchInProgress) {
        _userPaused = true;
        _playbackReassertTimer?.cancel();
        return;
      }
      if (state.track == null) return;
      _userPaused = false;
      await _player.play();
    }
  }

  Future<void> ensurePlaying({bool ignoreUserPause = false}) async {
    if (_isTrackSwitchInProgress) return;
    if (!ignoreUserPause && _userPaused) return;
    if (state.track == null) return;
    if (_player.playing) return;
    _userPaused = false;
    await _player.play();
  }

  Future<void> seek(Duration position) async {
    final maxDuration = state.duration;
    if (maxDuration > Duration.zero && position > maxDuration) {
      await _player.seek(maxDuration);
      return;
    }
    if (position < Duration.zero) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    final safeVolume = volume.clamp(0.0, 1.0).toDouble();
    await _player.setVolume(safeVolume);
    emit(state.copyWith(volume: safeVolume));
  }

  Future<void> _refreshQueueIfNeeded() async {
    // 1. If no queue exists but a track is currently playing, seed queue from that track
    if (state.queue.isEmpty && state.track?.trackId != null && _repo != null) {
      try {
        final expanded = await _repo.playQueueFrom(
          trackId: state.track!.trackId!,
          expand: true,
          metadata: {
            'title': state.track!.title,
            'artist': state.track!.artist,
            if (state.track!.imageUrl != null) 'cover_url': state.track!.imageUrl,
          },
        );
        final items = await _mapToQueueItems(expanded);
        final seededIndex = items.indexWhere((q) => q.trackId == state.track!.trackId);
        emit(state.copyWith(queue: items, currentIndex: seededIndex >= 0 ? seededIndex : 0));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Queue seed failed: $e');
        }
      }
    }

    final refreshedRemaining = state.queue.length - (state.currentIndex + 1);
    final refreshedNeeded = 10 - refreshedRemaining;

    // 2. Recommendation-based smart fill to always keep next 10 ready
    if (refreshedNeeded > 0 && state.queue.isNotEmpty && _repo != null) {
      final existingIds = state.queue.map((q) => q.trackId).toSet();
      int remainingNeeded = refreshedNeeded;

      if (_listeningHistoryRepository != null) {
        try {
          final recommendation = await _listeningHistoryRepository.getRecommendations(
            limit: refreshedNeeded * 3,
            type: 'discovery',
            includeReasons: false,
          );

          final recommendedTrackIds = recommendation.trackIds
              .where((id) => id.isNotEmpty && !existingIds.contains(id))
              .take(remainingNeeded)
              .toList();

          if (recommendedTrackIds.isNotEmpty) {
            await _repo.addToQueue(trackIds: recommendedTrackIds);
            existingIds.addAll(recommendedTrackIds);
            remainingNeeded -= recommendedTrackIds.length;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PlayerCubit] Recommendation fill failed: $e');
          }
        }
      }

      // 3. Fallback smart fill from provider search if recommendations are insufficient
      if (remainingNeeded > 0 && _musicProviderRegistry != null) {
      try {
        final seed = state.queue.last;
        // Use artist as seed for recommendations
        final seedQuery = seed.artist.split(',').first.trim();
        if (seedQuery.isNotEmpty && seedQuery != 'Unknown Artist') {
          // Search for similar tracks
          final results = await _musicProviderRegistry.search(
            seedQuery,
            limitPerProvider: remainingNeeded + 3,
          );

          // Filter duplicates (already in queue)
          final newTracks = results.tracks
              .where((t) => !existingIds.contains(t.prefixedId))
              .take(remainingNeeded)
              .toList();

          if (newTracks.isNotEmpty) {
            final trackIds = <String>[];
            final metadataList = <Map<String, dynamic>>[];

            for (final track in newTracks) {
              trackIds.add(track.prefixedId);
              metadataList.add({
                'title': track.title,
                'artist': track.artistName,
                'cover_url': track.imageUrl,
                'duration': track.durationSeconds,
                'source': track.source.name,
              });
            }

            // Bulk add with metadata
            await _repo.addToQueue(
              trackIds: trackIds,
              metadataList: metadataList,
            );
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PlayerCubit] Smart auto-fill failed: $e');
      }
      }
    }

    // 4. Sync with Backend
    final repo = _repo;
    if (repo == null) return;
    try {
      final expanded = await repo.getQueueExpanded();
      final items = await _mapToQueueItems(expanded);
      // Preserve current track: find same trackId in new list to set index.
      int newIndex = -1;
      if (state.track?.trackId != null) {
        newIndex = items.indexWhere((q) => q.trackId == state.track!.trackId);
      }
      final safeIndex = newIndex >= 0
          ? newIndex
          : _sanitizeIndex(state.currentIndex, items.length);
      emit(state.copyWith(queue: items, currentIndex: safeIndex));
    } catch (_) {}
  }

  void _publishNowPlaying(PlayerViewState viewState) {
    final hasTrack = viewState.track != null;
    final hasValidIndex = viewState.currentIndex >= 0 &&
        viewState.currentIndex < viewState.queue.length;
    final hasPrevious = hasValidIndex && viewState.currentIndex > 0;
    final hasNext = hasValidIndex &&
        viewState.currentIndex + 1 < viewState.queue.length;

    if (!hasTrack) {
      if (_lastPublishedTrackKey != null) {
        MediaControlsService.instance.clearMediaItem();
        _lastPublishedTrackKey = null;
      }
      MediaControlsService.instance.updatePlaybackState(
        playing: false,
        buffering: false,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        hasPrevious: false,
        hasNext: false,
        duration: Duration.zero,
        queueIndex: null,
      );
      return;
    }

    final track = viewState.track!;
    final trackKey = '${track.trackId ?? track.url}|${track.title}|${track.artist}';
    if (trackKey != _lastPublishedTrackKey) {
      Uri? artUri;
      final artPath = track.localImagePath ?? track.imageUrl;
      if (artPath != null && artPath.trim().isNotEmpty) {
        if (artPath.startsWith('http://') || artPath.startsWith('https://')) {
          artUri = Uri.tryParse(artPath);
        } else {
          artUri = Uri.file(artPath);
        }
      }

      MediaControlsService.instance.updateMediaItem(
        id: track.trackId ?? track.url,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri: artUri,
        duration: viewState.duration,
      );
      _lastPublishedTrackKey = trackKey;
    }

    MediaControlsService.instance.updatePlaybackState(
      playing: viewState.playing,
      buffering: viewState.buffering,
      position: viewState.position,
      bufferedPosition: _player.bufferedPosition,
      hasPrevious: hasPrevious,
      hasNext: hasNext,
      duration: viewState.duration,
      queueIndex: viewState.currentIndex >= 0 ? viewState.currentIndex : null,
    );
  }

  @override
  Future<void> close() async {
    await _logCurrentTrackPlay(wasSkipped: true);
    _snapshotLogTimer?.cancel();
    _playbackReassertTimer?.cancel();
    _switchFailSafeTimer?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playerStateSub?.cancel();
    await _viewStateSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
