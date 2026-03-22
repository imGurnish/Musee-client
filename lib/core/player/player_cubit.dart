import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/queue_persistence_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/core/cache/services/image_cache_service.dart';

import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerViewState> {
  final AudioPlayer _player;
  final TrackCacheService? _trackCache;
  final AudioCacheService? _audioCache;
  final ImageCacheService? _imageCache;
  final MusicProviderRegistry? _musicProviderRegistry;
  final QueuePersistenceService? _queuePersistence;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  /// Tracks the last saved position to avoid redundant saves
  Duration _lastSavedPosition = Duration.zero;

  PlayerCubit({
    TrackCacheService? trackCache,
    AudioCacheService? audioCache,
    ImageCacheService? imageCache,
    MusicProviderRegistry? musicProviderRegistry,
    QueuePersistenceService? queuePersistence,
  }) : _player = AudioPlayer(),
       _trackCache = trackCache,
       _audioCache = audioCache,
       _imageCache = imageCache,
       _musicProviderRegistry = musicProviderRegistry,
       _queuePersistence = queuePersistence,
       super(const PlayerViewState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    _positionSub = _player.positionStream.listen((pos) {
      emit(state.copyWith(position: pos));

      // Debounced position persistence (save every 5 seconds of change)
      if (_queuePersistence != null &&
          (pos - _lastSavedPosition).inSeconds.abs() >= 5) {
        _lastSavedPosition = pos;
        _queuePersistence.savePosition(pos);
      }
    });
    _durationSub = _player.durationStream.listen((dur) {
      emit(state.copyWith(duration: dur ?? Duration.zero));
    });
    _playerStateSub = _player.playerStateStream.listen((ps) async {
      final playing = ps.playing;
      final buffering =
          ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      emit(state.copyWith(playing: playing, buffering: buffering));

      // Auto-advance when current track completes
      if (ps.processingState == ProcessingState.completed) {
        await _playNextInternal();
      }
    });

    // Restore persisted queue on startup
    await _restorePersistedQueue();
  }

  /// Restore queue, current index, and position from Hive persistence.
  Future<void> _restorePersistedQueue() async {
    if (_queuePersistence == null) return;

    try {
      final snapshot = await _queuePersistence.loadQueue();
      if (snapshot.isEmpty) return;

      emit(state.copyWith(
        queue: snapshot.queue,
        currentIndex: snapshot.currentIndex,
      ));

      // If there was a current track, prepare it (but don't auto-play)
      if (snapshot.currentIndex >= 0 &&
          snapshot.currentIndex < snapshot.queue.length) {
        final item = snapshot.queue[snapshot.currentIndex];
        final url = await _fetchPlayableUrl(item.trackId);
        if (url != null) {
          final track = PlayerTrack(
            trackId: item.trackId,
            url: url,
            title: item.title.isEmpty ? 'Unknown Title' : item.title,
            artist: item.artist.isEmpty ? 'Unknown Artist' : item.artist,
            album: item.album,
            imageUrl: item.imageUrl,
            localImagePath: item.localImagePath,
          );
          emit(state.copyWith(track: track));

          // Seek to last known position
          try {
            await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
            if (snapshot.position > Duration.zero) {
              await _player.seek(snapshot.position);
            }
            // Don't auto-play — user must tap play
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[PlayerCubit] Error restoring playback state: $e');
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[PlayerCubit] Restored queue: ${snapshot.queue.length} items, '
          'index=${snapshot.currentIndex}, position=${snapshot.position}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PlayerCubit] Error restoring persisted queue: $e');
      }
    }
  }

  // Resolve playable URL with cache-first strategy
  Future<String?> _fetchPlayableUrl(String trackId) async {
    // 1. Check local audio cache first (for offline playback)
    if (_audioCache != null && !kIsWeb) {
      final localPath = await _audioCache.getLocalAudioPath(trackId);
      if (localPath != null && await File(localPath).exists()) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Playing from local cache: $localPath');
        }
        // Update last played timestamp for LRU
        _trackCache?.updateLastPlayed(trackId);
        return localPath;
      }
    }

    // 2. Check if we have a cached streaming URL (avoids API call)
    final cachedTrack = await _trackCache?.getTrack(trackId);
    if (cachedTrack?.streamingUrl != null) {
      if (kDebugMode) {
        debugPrint(
          '[PlayerCubit] Using cached streaming URL for track: $trackId',
        );
      }
      return cachedTrack!.streamingUrl;
    }

    // 3. Fetch from MusicProviderRegistry (JioSaavn)
    if (_musicProviderRegistry != null) {
      try {
        final url = await _musicProviderRegistry.getStreamUrl(trackId);

        if (url != null) {
          // 4. Cache metadata and streaming URL
          await _cacheTrackMetadata(trackId, url);
          return url;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PlayerCubit] Error fetching stream URL: $e');
        }
      }
    }

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

      if (track == null && fallback != null) {
        if (kDebugMode) {
          debugPrint(
            '[PlayerCubit] getTrack failed, using fallback for $trackId',
          );
        }
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

      // Download album artwork
      String? imageUrl = track?.imageUrl ?? fallback?.imageUrl;
      String? localImagePath;
      if (_imageCache != null && imageUrl != null) {
        try {
          localImagePath = await _imageCache.cacheImage(imageUrl);
        } catch (_) {}
      }

      final existing = await _trackCache.getTrack(trackId);
      int playCount = existing?.playCount ?? 0;
      playCount += 1;

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
        ..sourceProvider = track?.source.name ?? 'external'
        ..playCount = playCount
        ..localImagePath = localImagePath;

      if (existing != null) {
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
    // Auto-add to queue if not already present
    int queueIndex = state.currentIndex;
    if (track.trackId != null) {
      final existingIdx =
          state.queue.indexWhere((q) => q.trackId == track.trackId);
      if (existingIdx >= 0) {
        // Already in queue — just update current index
        queueIndex = existingIdx;
      } else {
        // Add to end of queue
        final newItem = QueueItem(
          trackId: track.trackId!,
          title: track.title,
          artist: track.artist,
          album: track.album,
          imageUrl: track.imageUrl,
          localImagePath: track.localImagePath,
        );
        final updatedQueue = [...state.queue, newItem];
        queueIndex = updatedQueue.length - 1;
        emit(state.copyWith(queue: updatedQueue, currentIndex: queueIndex));
      }
    }

    emit(state.copyWith(
      track: track,
      buffering: true,
      currentIndex: queueIndex,
    ));

    // Cache metadata if we have a track ID
    if (track.trackId != null && track.url.isNotEmpty && _trackCache != null) {
      unawaited(
        _cacheTrackMetadata(track.trackId!, track.url, fallback: track),
      );
    }

    try {
      final headers = track.headers ?? const <String, String>{};

      Uri uri;
      if (track.url.startsWith('http') || track.url.startsWith('https')) {
        uri = Uri.parse(track.url);
      } else {
        // Local file path
        uri = Uri.file(track.url);
      }

      await _player.setAudioSource(
        AudioSource.uri(uri, headers: headers.isEmpty ? null : headers),
      );
      await _player.play();

      // Persist queue and fetch recommendations
      _persistQueue();
      unawaited(_refreshQueueIfNeeded());
    } catch (e) {
      emit(state.copyWith(buffering: false, playing: false));
    }
  }

  /// Play a track by ID, resolving the URL via MusicProviderRegistry.
  Future<void> playTrackById({
    required String trackId,
    String? title,
    String? artist,
    String? album,
    String? imageUrl,
  }) async {
    final url = await _fetchPlayableUrl(trackId);
    if (url == null) return;

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

  // Queue APIs — local management with persistence

  Future<void> addToQueue(List<QueueItem> items) async {
    final newQueue = [...state.queue, ...items];
    emit(state.copyWith(queue: newQueue));
    _persistQueue();
  }

  Future<void> removeFromQueue(String uid) async {
    final removedIndex = state.queue.indexWhere((e) => e.uid == uid);
    if (removedIndex < 0) return;

    final newList = [...state.queue]..removeAt(removedIndex);

    int newIndex = state.currentIndex;
    if (removedIndex < state.currentIndex) {
      newIndex = state.currentIndex - 1;
    } else if (removedIndex == state.currentIndex) {
      newIndex = newIndex.clamp(-1, newList.length - 1);
    }
    if (newList.isEmpty) newIndex = -1;

    emit(state.copyWith(queue: newList, currentIndex: newIndex));
    _persistQueue();
  }

  Future<void> reorderQueue(int from, int to) async {
    final list = [...state.queue];
    if (from < 0 || from >= list.length || to < 0 || to >= list.length) return;
    if (from == to) return;

    final item = list.removeAt(from);
    list.insert(to, item);

    int newIndex = state.currentIndex;
    if (state.currentIndex == from) {
      newIndex = to;
    } else if (from < state.currentIndex && to >= state.currentIndex) {
      newIndex = state.currentIndex - 1;
    } else if (from > state.currentIndex && to <= state.currentIndex) {
      newIndex = state.currentIndex + 1;
    }

    emit(state.copyWith(queue: list, currentIndex: newIndex));
    _persistQueue();
  }

  Future<void> clearQueue() async {
    emit(state.copyWith(queue: const <QueueItem>[], currentIndex: -1));
    _queuePersistence?.clearQueue();
  }

  Future<void> playFromQueueTrackId(String trackId) async {
    // Find index locally
    final idx = state.queue.indexWhere((q) => q.trackId == trackId);
    if (idx >= 0) {
      await _playAtIndex(idx);
      await _refreshQueueIfNeeded();
    } else {
      // Fallback: play single by resolving URL
      final url = await _fetchPlayableUrl(trackId);
      if (url != null) {
        await playTrack(
          PlayerTrack(url: url, title: 'Unknown', artist: 'Unknown'),
        );
      }
    }
  }

  Future<void> next({bool userInitiated = true}) async {
    await _playNextInternal(userInitiated: userInitiated);
  }

  Future<void> previous() async {
    final idx = state.currentIndex;
    if (idx > 0) {
      await _playAtIndex(idx - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> _playNextInternal({bool userInitiated = false}) async {
    final currentIdx = state.currentIndex;

    if (currentIdx + 1 < state.queue.length) {
      final nextIndex = currentIdx + 1;
      await _playAtIndex(nextIndex);
      await _refreshQueueIfNeeded();
    } else {
      // End of queue - stop playback
      await _player.stop();
      emit(state.copyWith(playing: false));
      await _refreshQueueIfNeeded();
    }
  }

  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final item = state.queue[index];
    final url = await _fetchPlayableUrl(item.trackId);
    if (url == null) return;
    final track = PlayerTrack(
      trackId: item.trackId,
      url: url,
      title: item.title.isEmpty ? 'Unknown Title' : item.title,
      artist: item.artist.isEmpty ? 'Unknown Artist' : item.artist,
      album: item.album,
      imageUrl: item.imageUrl,
      localImagePath: item.localImagePath,
    );
    emit(state.copyWith(track: track, buffering: true, currentIndex: index));
    _persistQueue();
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();
    } catch (_) {
      emit(state.copyWith(buffering: false, playing: false));
    }
  }

  Future<void> togglePlayPause() async {
    if (state.buffering) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
    emit(state.copyWith(volume: volume));
  }

  /// Persist the current queue and index to Hive.
  void _persistQueue() {
    _queuePersistence?.saveQueue(state.queue, state.currentIndex);
  }

  /// Auto-fill queue with recommendations when running low.
  /// Uses JioSaavn's reco.getreco for song-based suggestions (preferred),
  /// falling back to artist-name search if suggestions unavailable.
  Future<void> _refreshQueueIfNeeded() async {
    final remaining = state.queue.length - (state.currentIndex + 1);

    if (remaining < 3 &&
        state.queue.isNotEmpty &&
        _musicProviderRegistry != null) {
      try {
        // Prefer song-based suggestions via reco.getreco
        final currentTrack = state.queue.isNotEmpty
            ? state.queue[state.currentIndex.clamp(0, state.queue.length - 1)]
            : null;

        List<QueueItem> newItems = [];

        if (currentTrack != null) {
          final suggestions = await _musicProviderRegistry.getSongSuggestions(
            currentTrack.trackId,
            limit: 10,
          );

          // Filter duplicates (already in queue)
          final existingIds = state.queue.map((q) => q.trackId).toSet();
          final filtered = suggestions
              .where((t) => !existingIds.contains(t.prefixedId))
              .take(5)
              .toList();

          if (filtered.isNotEmpty) {
            newItems = filtered
                .map(
                  (track) => QueueItem(
                    trackId: track.prefixedId,
                    title: track.title,
                    artist: track.artistName,
                    imageUrl: track.imageUrl,
                    durationSeconds: track.durationSeconds,
                  ),
                )
                .toList();
          }
        }

        // Fallback: search by artist name if no song suggestions
        if (newItems.isEmpty && currentTrack != null) {
          final seedQuery = currentTrack.artist.split(',').first.trim();
          if (seedQuery.isNotEmpty && seedQuery != 'Unknown Artist') {
            final results = await _musicProviderRegistry.search(
              seedQuery,
              limitPerProvider: 5,
            );

            final existingIds = state.queue.map((q) => q.trackId).toSet();
            final newTracks = results.tracks
                .where((t) => !existingIds.contains(t.prefixedId))
                .take(5)
                .toList();

            if (newTracks.isNotEmpty) {
              newItems = newTracks
                  .map(
                    (track) => QueueItem(
                      trackId: track.prefixedId,
                      title: track.title,
                      artist: track.artistName,
                      imageUrl: track.imageUrl,
                    ),
                  )
                  .toList();
            }
          }
        }

        if (newItems.isNotEmpty) {
          final updatedQueue = [...state.queue, ...newItems];
          emit(state.copyWith(queue: updatedQueue));
          _persistQueue();

          if (kDebugMode) {
            debugPrint(
              '[PlayerCubit] Auto-filled ${newItems.length} tracks via '
              'recommendations',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PlayerCubit] Smart auto-fill failed: $e');
      }
    }
  }

  @override
  Future<void> close() async {
    // Save final position before closing
    if (_queuePersistence != null && state.position > Duration.zero) {
      await _queuePersistence.savePositionImmediate(state.position);
    }
    _queuePersistence?.dispose();

    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playerStateSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
