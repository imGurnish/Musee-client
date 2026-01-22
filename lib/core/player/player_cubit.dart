import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/features/player/domain/repository/player_repository.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerViewState> {
  final AudioPlayer _player;
  final PlayerRepository? _repo; // optional to allow previous initialization
  final TrackCacheService? _trackCache;
  final AudioCacheService? _audioCache;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  PlayerCubit({
    PlayerRepository? repository,
    TrackCacheService? trackCache,
    AudioCacheService? audioCache,
  }) : _player = AudioPlayer(),
       _repo = repository,
       _trackCache = trackCache,
       _audioCache = audioCache,
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

    // Load existing queue from backend if available
    final repo = _repo;
    if (repo != null) {
      unawaited(loadQueue());
    }
  }

  // Resolve playable URL with cache-first strategy
  Future<String?> _fetchPlayableUrl(String trackId) async {
    // 1. Check local audio cache first (for offline playback)
    if (_audioCache != null && !kIsWeb) {
      final localPath = await _audioCache.getLocalAudioPath(trackId);
      if (localPath != null && await File(localPath).exists()) {
        if (kDebugMode) {
          print('[PlayerCubit] Playing from local cache: $localPath');
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
        print('[PlayerCubit] Using cached streaming URL for track: $trackId');
      }
      return cachedTrack!.streamingUrl;
    }

    // 3. Fetch from backend API
    try {
      final client = dio.Dio();
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final res = await client.get(
        '${AppSecrets.backendUrl}/api/user/tracks/$trackId',
        options: dio.Options(
          headers: token != null
              ? {'Authorization': 'Bearer $token', 'Accept': 'application/json'}
              : {'Accept': 'application/json'},
        ),
      );
      final data = (res.data as Map).cast<String, dynamic>();
      final hls = (data['hls'] as Map?)?.cast<String, dynamic>();
      final master = hls?['master'] as String?;

      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      String? playableUrl;
      String? urlToCache;

      if (kIsWeb || isWindows) {
        final audios = (data['audios'] as List?)?.cast<dynamic>() ?? const [];
        String? bestMp3;
        int bestBitrate = -1;
        for (final item in audios) {
          final m = (item as Map).cast<String, dynamic>();
          final ext = (m['ext'] as String?)?.toLowerCase();
          final path = m['path'] as String?;
          final br = (m['bitrate'] as num?)?.toInt() ?? 0;
          if (ext == 'mp3' && path != null && path.isNotEmpty) {
            if (br > bestBitrate) {
              bestBitrate = br;
              bestMp3 = path;
            }
          }
        }
        playableUrl = bestMp3 ?? master;
        urlToCache = bestMp3 ?? master;
      } else {
        playableUrl = master;
        urlToCache = master;
      }

      // 4. Cache metadata from API response
      if (_trackCache != null && playableUrl != null) {
        await _cacheTrackFromApiResponse(trackId, data, playableUrl);
      }

      // 5. Optionally trigger background download for offline access (non-web only)
      if (_audioCache != null &&
          _trackCache != null &&
          urlToCache != null &&
          !kIsWeb) {
        unawaited(_downloadTrackForOffline(trackId, urlToCache));
      }

      return playableUrl;
    } catch (e) {
      // 6. On network error, try returning cached streaming URL as fallback
      if (cachedTrack?.streamingUrl != null) {
        if (kDebugMode) {
          print('[PlayerCubit] Network error, using cached URL: $trackId');
        }
        return cachedTrack!.streamingUrl;
      }
      return null;
    }
  }

  /// Cache track metadata from API response
  Future<void> _cacheTrackFromApiResponse(
    String trackId,
    Map<String, dynamic> data,
    String streamingUrl,
  ) async {
    if (_trackCache == null) return;

    final artists =
        (data['artists'] as List?)
            ?.map((a) => (a['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .join(', ') ??
        '';
    final album = data['album'] as Map<String, dynamic>?;

    final cached = CachedTrack()
      ..trackId = trackId
      ..title = (data['title'] ?? '').toString()
      ..albumId = album?['album_id']?.toString()
      ..albumTitle = album?['title']?.toString()
      ..albumCoverUrl = (album?['cover_url'] ?? data['cover_url'])?.toString()
      ..artistName = artists
      ..durationSeconds = (data['duration'] as num?)?.toInt() ?? 0
      ..isExplicit = data['is_explicit'] == true
      ..streamingUrl = streamingUrl
      ..cachedAt = DateTime.now()
      ..lastPlayedAt = DateTime.now();

    await _trackCache.cacheTrack(cached);
    if (kDebugMode) {
      print('[PlayerCubit] Cached track metadata: $trackId');
    }
  }

  /// Download track audio for offline playback in background
  Future<void> _downloadTrackForOffline(String trackId, String url) async {
    if (_audioCache == null || _trackCache == null) return;

    try {
      final localPath = await _audioCache.downloadAndCache(
        trackId: trackId,
        remoteUrl: url,
        trackCache: _trackCache,
      );
      if (localPath != null && kDebugMode) {
        print('[PlayerCubit] Downloaded track for offline: $trackId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PlayerCubit] Failed to download track: $trackId - $e');
      }
    }
  }

  Future<void> playTrack(PlayerTrack track) async {
    emit(state.copyWith(track: track, buffering: true));
    try {
      final headers = track.headers ?? const <String, String>{};
      final uri = Uri.parse(track.url);
      await _player.setAudioSource(
        AudioSource.uri(uri, headers: headers.isEmpty ? null : headers),
      );
      await _player.play();
    } catch (e) {
      emit(state.copyWith(buffering: false, playing: false));
    }
  }

  // Queue APIs
  Future<void> loadQueue() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final expanded = await repo.getQueueExpanded();
      final items = expanded.map((m) => QueueItem.fromExpandedJson(m)).toList();
      emit(state.copyWith(queue: items));
    } catch (_) {}
  }

  Future<void> playFromQueueTrackId(String trackId) async {
    final repo = _repo;
    if (repo != null) {
      try {
        final expanded = await repo.playQueueFrom(
          trackId: trackId,
          expand: true,
        );
        final items = expanded
            .map((m) => QueueItem.fromExpandedJson(m))
            .toList();
        emit(state.copyWith(queue: items));
      } catch (_) {}
    }
    // Find index locally
    final idx = state.queue.indexWhere((q) => q.trackId == trackId);
    if (idx >= 0) {
      await _playAtIndex(idx);
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

  Future<void> addToQueue(List<QueueItem> items) async {
    emit(state.copyWith(queue: [...state.queue, ...items]));
    final repo = _repo;
    if (repo != null) {
      unawaited(
        repo.addToQueue(trackIds: items.map((e) => e.trackId).toList()),
      );
    }
  }

  Future<void> removeFromQueue(String trackId) async {
    final newList = [...state.queue]..removeWhere((e) => e.trackId == trackId);
    var newIndex = state.currentIndex;
    final removedIndex = state.queue.indexWhere((e) => e.trackId == trackId);
    if (removedIndex >= 0 && removedIndex <= state.currentIndex) {
      newIndex = (state.currentIndex - 1).clamp(-1, newList.length - 1);
    }
    emit(state.copyWith(queue: newList, currentIndex: newIndex));
    final repo = _repo;
    if (repo != null) {
      unawaited(repo.removeFromQueue(trackId: trackId));
    }
  }

  Future<void> reorderQueue(int from, int to) async {
    final list = [...state.queue];
    if (from < 0 || from >= list.length || to < 0 || to >= list.length) return;
    final item = list.removeAt(from);
    list.insert(to, item);
    // Adjust current index if needed
    var idx = state.currentIndex;
    if (idx == from) {
      idx = to;
    } else if (from < idx && to >= idx)
      idx -= 1;
    else if (from > idx && to <= idx)
      idx += 1;
    emit(state.copyWith(queue: list, currentIndex: idx));
    final repo = _repo;
    if (repo != null) {
      unawaited(repo.reorderQueue(fromIndex: from, toIndex: to));
    }
  }

  Future<void> clearQueue() async {
    emit(state.copyWith(queue: const <QueueItem>[], currentIndex: -1));
    final repo = _repo;
    if (repo != null) {
      unawaited(repo.clearQueue());
    }
  }

  Future<void> next({bool userInitiated = true}) async {
    // userInitiated true when tapped button; false when auto-advance
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
    final idx = state.currentIndex;
    if (idx + 1 < state.queue.length) {
      // If user pressed next, remove the previous track from queue.
      if (userInitiated && idx >= 0 && idx < state.queue.length) {
        final prevItem = state.queue[idx];
        // Remove prev item (at current index) BEFORE advancing.
        final newQueue = [...state.queue]..removeAt(idx);
        // Adjust index so that next item shifts into current position.
        final newIndex = idx; // since removal shifts next track into idx
        emit(state.copyWith(queue: newQueue, currentIndex: newIndex));
      }
      await _playAtIndex(state.currentIndex + 1);
      await _refreshQueueIfNeeded();
    } else {
      // end of queue
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

  Future<void> _refreshQueueIfNeeded() async {
    // Ensure minimum of 10 remaining tracks after current index.
    if (state.queue.length >= 10) return;
    final repo = _repo;
    if (repo == null) return;
    try {
      final expanded = await repo.getQueueExpanded();
      final items = expanded.map((m) => QueueItem.fromExpandedJson(m)).toList();
      // Preserve current track: find same trackId in new list to set index.
      int newIndex = -1;
      if (state.track?.trackId != null) {
        newIndex = items.indexWhere((q) => q.trackId == state.track!.trackId);
      }
      emit(state.copyWith(queue: items, currentIndex: newIndex));
    } catch (_) {}
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
