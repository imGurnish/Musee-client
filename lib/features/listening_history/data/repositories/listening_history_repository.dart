import 'dart:async';

import 'package:hive/hive.dart';

import '../models/listening_history_models.dart';
import '../datasources/listening_history_remote_data_source.dart';
import '../services/play_log_queue.dart';

abstract class ListeningHistoryRepository {
  /// Log a track play. This is non-blocking — entries are batched and
  /// sent to the backend in the background.
  void logTrackPlay(TrackPlayData data);
  Future<void> likeTrack(String trackId, {List<String>? mood});
  Future<void> dislikeTrack(String trackId);
  Future<void> clearTrackPreference(String trackId);
  Future<int> getTrackPreference(String trackId);
  Stream<int> watchTrackPreference(String trackId);

  /// Fetch all liked tracks (preference == 1) for the current user.
  Future<List<Map<String, dynamic>>> getLikedTracks();

  // Album preferences
  Future<void> likeAlbum(String albumId);
  Future<void> dislikeAlbum(String albumId);
  Future<void> clearAlbumPreference(String albumId);
  Future<int> getAlbumPreference(String albumId);

  // Playlist preferences
  Future<void> likePlaylist(String playlistId);
  Future<void> dislikePlaylist(String playlistId);
  Future<void> clearPlaylistPreference(String playlistId);
  Future<int> getPlaylistPreference(String playlistId);

  // Admin analytics
  Future<EngagementMetrics> getEngagementMetrics();
  Future<RefreshTrendingResult> refreshTrending();

  Future<Recommendation> getRecommendations({
    int limit = 50,
    String type = 'discovery',
    bool includeReasons = false,
  });
  Future<void> saveOnboardingPreferences(UserOnboardingPreferences preferences);
  Future<UserOnboardingPreferences> getOnboardingPreferences();
  Future<ListeningStats> getListeningStats();

  /// Flush any pending play-log entries to the backend immediately.
  Future<void> flushPlayLogs();

  /// Release resources. Should be called on app shutdown.
  Future<void> dispose();
}

class ListeningHistoryRepositoryImpl implements ListeningHistoryRepository {
  static const String _localPreferenceBoxName = 'listening_history_preferences';
  static const String _likedTrackIdsStorageKey = 'listening_history_liked_track_ids';

  final ListeningHistoryRemoteDataSource remoteDataSource;
  final PlayLogQueue _playLogQueue;
  final StreamController<_TrackPreferenceUpdate> _trackPreferenceController =
      StreamController<_TrackPreferenceUpdate>.broadcast();
  final Map<String, int> _trackPreferenceCache = <String, int>{};
  Future<void>? _localLikeHydration;
  Box<dynamic>? _localPreferenceBox;

  ListeningHistoryRepositoryImpl({required this.remoteDataSource})
      : _playLogQueue = PlayLogQueue(remote: remoteDataSource) {
    _localLikeHydration = _hydrateLocalLikes();
  }

  @override
  void logTrackPlay(TrackPlayData data) {
    // Fully non-blocking — the entry is added to an in-memory queue
    // and flushed to the backend in periodic batches.
    _playLogQueue.enqueue(data);
  }

  @override
  Future<void> flushPlayLogs() => _playLogQueue.flush();

  @override
  Future<void> dispose() async {
    await _playLogQueue.dispose();
    await _trackPreferenceController.close();
    if (_localPreferenceBox?.isOpen == true) {
      await _localPreferenceBox!.close();
    }
  }

  @override
  Future<void> likeTrack(String trackId, {List<String>? mood}) async {
    final normalizedTrackId = trackId.trim();
    if (normalizedTrackId.isEmpty) return;

    final previous = _trackPreferenceCache[normalizedTrackId];
    _publishTrackPreference(normalizedTrackId, 1);
    unawaited(_persistLocalTrackPreference(normalizedTrackId, 1));
    try {
      await remoteDataSource.likeTrack(normalizedTrackId, mood: mood);
    } catch (e) {
      if (previous == null) {
        _trackPreferenceCache.remove(normalizedTrackId);
        _emitTrackPreference(normalizedTrackId, 0);
        unawaited(_persistLocalTrackPreference(normalizedTrackId, 0));
      } else {
        _publishTrackPreference(normalizedTrackId, previous);
        unawaited(_persistLocalTrackPreference(normalizedTrackId, previous));
      }
      rethrow;
    }
  }

  @override
  Future<void> dislikeTrack(String trackId) async {
    try {
      await remoteDataSource.dislikeTrack(trackId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearTrackPreference(String trackId) async {
    final normalizedTrackId = trackId.trim();
    if (normalizedTrackId.isEmpty) return;

    final previous = _trackPreferenceCache[normalizedTrackId];
    _publishTrackPreference(normalizedTrackId, 0);
    unawaited(_persistLocalTrackPreference(normalizedTrackId, 0));
    try {
      await remoteDataSource.clearTrackPreference(normalizedTrackId);
    } catch (e) {
      if (previous != null) {
        _publishTrackPreference(normalizedTrackId, previous);
        unawaited(_persistLocalTrackPreference(normalizedTrackId, previous));
      }
      rethrow;
    }
  }

  @override
  Future<Recommendation> getRecommendations({
    int limit = 50,
    String type = 'discovery',
    bool includeReasons = false,
  }) async {
    try {
      return await remoteDataSource.getRecommendations(
        limit: limit,
        type: type,
        includeReasons: includeReasons,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveOnboardingPreferences(UserOnboardingPreferences preferences) async {
    try {
      await remoteDataSource.saveOnboardingPreferences(preferences);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserOnboardingPreferences> getOnboardingPreferences() async {
    try {
      return await remoteDataSource.getOnboardingPreferences();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ListeningStats> getListeningStats() async {
    try {
      return await remoteDataSource.getListeningStats();
    } catch (e) {
      rethrow;
    }
  }

  // ==================== GET PREFERENCES ====================

  @override
  Future<int> getTrackPreference(String trackId) async {
    final normalizedTrackId = trackId.trim();
    if (normalizedTrackId.isEmpty) return 0;

    await _ensureLocalLikesHydrated();

    final cached = _trackPreferenceCache[normalizedTrackId];
    if (cached != null) {
      return cached;
    }

    try {
      final preference = await remoteDataSource.getTrackPreference(normalizedTrackId);
      _publishTrackPreference(normalizedTrackId, preference);
      unawaited(_persistLocalTrackPreference(normalizedTrackId, preference));
      return preference;
    } catch (_) {
      final localFallback = _trackPreferenceCache[normalizedTrackId] ?? 0;
      if (localFallback != 0) {
        _emitTrackPreference(normalizedTrackId, localFallback);
      }
      return localFallback;
    }
  }

  @override
  Stream<int> watchTrackPreference(String trackId) async* {
    final normalizedTrackId = trackId.trim();
    if (normalizedTrackId.isEmpty) {
      yield 0;
      return;
    }

    await _ensureLocalLikesHydrated();

    final cached = _trackPreferenceCache[normalizedTrackId];
    if (cached != null) {
      yield cached;
    }

    await for (final update in _trackPreferenceController.stream) {
      if (update.trackId == normalizedTrackId) {
        yield update.preference;
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLikedTracks() async {
    try {
      return await remoteDataSource.getLikedTracks();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> getAlbumPreference(String albumId) async {
    try {
      return await remoteDataSource.getAlbumPreference(albumId);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> getPlaylistPreference(String playlistId) async {
    try {
      return await remoteDataSource.getPlaylistPreference(playlistId);
    } catch (_) {
      return 0;
    }
  }

  // ==================== ALBUM PREFERENCES ====================

  @override
  Future<void> likeAlbum(String albumId) async {
    try {
      await remoteDataSource.likeAlbum(albumId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> dislikeAlbum(String albumId) async {
    try {
      await remoteDataSource.dislikeAlbum(albumId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearAlbumPreference(String albumId) async {
    try {
      await remoteDataSource.clearAlbumPreference(albumId);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== PLAYLIST PREFERENCES ====================

  @override
  Future<void> likePlaylist(String playlistId) async {
    try {
      await remoteDataSource.likePlaylist(playlistId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> dislikePlaylist(String playlistId) async {
    try {
      await remoteDataSource.dislikePlaylist(playlistId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearPlaylistPreference(String playlistId) async {
    try {
      await remoteDataSource.clearPlaylistPreference(playlistId);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ADMIN ANALYTICS ====================

  @override
  Future<EngagementMetrics> getEngagementMetrics() async {
    try {
      return await remoteDataSource.getEngagementMetrics();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<RefreshTrendingResult> refreshTrending() async {
    try {
      return await remoteDataSource.refreshTrending();
    } catch (e) {
      rethrow;
    }
  }

  void _publishTrackPreference(String trackId, int preference) {
    final safePreference = preference.clamp(-1, 1);
    _trackPreferenceCache[trackId] = safePreference;
    _emitTrackPreference(trackId, safePreference);
  }

  void _emitTrackPreference(String trackId, int preference) {
    if (_trackPreferenceController.isClosed) return;
    _trackPreferenceController.add(
      _TrackPreferenceUpdate(trackId: trackId, preference: preference),
    );
  }

  Future<void> _ensureLocalLikesHydrated() async {
    _localLikeHydration ??= _hydrateLocalLikes();
    await _localLikeHydration;
  }

  Future<void> _hydrateLocalLikes() async {
    try {
      final box = await _getLocalPreferenceBox();
      final stored = box.get(_likedTrackIdsStorageKey);
      final likedIds = stored is List
          ? stored.map((e) => e.toString()).toList(growable: false)
          : const <String>[];
      for (final id in likedIds) {
        final normalized = id.trim();
        if (normalized.isEmpty) continue;
        _trackPreferenceCache[normalized] = 1;
      }
    } catch (_) {
      // Keep behavior resilient when local storage is unavailable.
    }
  }

  Future<void> _persistLocalTrackPreference(String trackId, int preference) async {
    try {
      final box = await _getLocalPreferenceBox();
      final stored = box.get(_likedTrackIdsStorageKey);
      final likedIds = stored is List
          ? stored.map((e) => e.toString()).toSet()
          : <String>{};

      if (preference == 1) {
        likedIds.add(trackId);
      } else {
        likedIds.remove(trackId);
      }

      await box.put(
        _likedTrackIdsStorageKey,
        likedIds.toList(growable: false),
      );
    } catch (_) {
      // Ignore local persistence failures; remote remains source of truth.
    }
  }

  Future<Box<dynamic>> _getLocalPreferenceBox() async {
    final existingBox = _localPreferenceBox;
    if (existingBox != null && existingBox.isOpen) {
      return existingBox;
    }

    _localPreferenceBox = await Hive.openBox<dynamic>(_localPreferenceBoxName);
    return _localPreferenceBox!;
  }
}

class _TrackPreferenceUpdate {
  final String trackId;
  final int preference;

  const _TrackPreferenceUpdate({
    required this.trackId,
    required this.preference,
  });
}
