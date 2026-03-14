import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
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
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  PlayerCubit({
    TrackCacheService? trackCache,
    AudioCacheService? audioCache,
    ImageCacheService? imageCache,
    MusicProviderRegistry? musicProviderRegistry,
  }) : _player = AudioPlayer(),
       _trackCache = trackCache,
       _audioCache = audioCache,
       _imageCache = imageCache,
       _musicProviderRegistry = musicProviderRegistry,
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
    emit(state.copyWith(track: track, buffering: true));

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

  // Queue APIs — local-only management

  Future<void> addToQueue(List<QueueItem> items) async {
    emit(state.copyWith(queue: [...state.queue, ...items]));
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
  }

  Future<void> clearQueue() async {
    emit(state.copyWith(queue: const <QueueItem>[], currentIndex: -1));
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

  /// Auto-fill queue with recommendations when running low.
  /// Uses JioSaavn search to find similar tracks.
  Future<void> _refreshQueueIfNeeded() async {
    final remaining = state.queue.length - (state.currentIndex + 1);

    if (remaining < 3 &&
        state.queue.isNotEmpty &&
        _musicProviderRegistry != null) {
      try {
        final seed = state.queue.last;
        final seedQuery = seed.artist.split(',').first.trim();
        if (seedQuery.isNotEmpty && seedQuery != 'Unknown Artist') {
          final results = await _musicProviderRegistry.search(
            seedQuery,
            limitPerProvider: 5,
          );

          // Filter duplicates (already in queue)
          final existingIds = state.queue.map((q) => q.trackId).toSet();
          final newTracks = results.tracks
              .where((t) => !existingIds.contains(t.prefixedId))
              .take(5)
              .toList();

          if (newTracks.isNotEmpty) {
            final newItems = newTracks
                .map(
                  (track) => QueueItem(
                    trackId: track.prefixedId,
                    title: track.title,
                    artist: track.artistName,
                    imageUrl: track.imageUrl,
                  ),
                )
                .toList();

            emit(state.copyWith(queue: [...state.queue, ...newItems]));
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PlayerCubit] Smart auto-fill failed: $e');
      }
    }
  }

  @override
  Future<void> close() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playerStateSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
