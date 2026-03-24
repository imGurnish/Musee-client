import 'package:hive_flutter/hive_flutter.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/cache_config.dart';

/// Service for caching track and album metadata using Hive.
abstract class TrackCacheService {
  /// Initialize the cache database
  Future<void> init();

  /// Cache a track's metadata
  Future<void> cacheTrack(CachedTrack track);

  /// Get cached track by ID, or null if not cached
  Future<CachedTrack?> getTrack(String trackId);

  /// Update the last played timestamp and increment play count for LRU tracking
  Future<void> updateLastPlayed(String trackId);

  /// Cache an album's metadata
  Future<void> cacheAlbum(CachedAlbum album);

  /// Get cached album by ID
  Future<CachedAlbum?> getAlbum(String albumId);

  /// Get all cached tracks for an album
  Future<List<CachedTrack>> getAlbumTracks(String albumId);

  /// Clear expired metadata entries
  Future<void> clearExpired();

  /// Get total count of cached tracks
  Future<int> getCachedTrackCount();

  /// Clear all cached data
  Future<void> clearAll();

  /// Get recently played tracks sorted by last played time (most recent first)
  Future<List<CachedTrack>> getRecentlyPlayed({int limit = 20});

  /// Get most played tracks sorted by play count (highest first)
  Future<List<CachedTrack>> getMostPlayed({int limit = 20});

  /// Get all tracks that are available offline
  Future<List<CachedTrack>> getOfflineAvailable();

  /// Get all cached tracks
  Future<List<CachedTrack>> getAllTracks();

  /// Get all cached albums
  Future<List<CachedAlbum>> getAllAlbums();

  /// Get cache statistics
  Future<CacheStats> getStats();
}

/// Cache statistics for management UI
class CacheStats {
  final int trackCount;
  final int albumCount;
  final int offlineTrackCount;
  final int totalPlayCount;

  const CacheStats({
    required this.trackCount,
    required this.albumCount,
    required this.offlineTrackCount,
    required this.totalPlayCount,
  });
}

class TrackCacheServiceImpl implements TrackCacheService {
  Box<CachedTrack>? _trackBox;
  Box<CachedAlbum>? _albumBox;

  @override
  Future<void> init() async {
    if (_trackBox != null && _albumBox != null) return;

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CachedTrackAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CachedAlbumAdapter());
    }

    _trackBox = await Hive.openBox<CachedTrack>(CacheConfig.trackBoxName);
    _albumBox = await Hive.openBox<CachedAlbum>(CacheConfig.albumBoxName);
  }

  Box<CachedTrack> get _tracks {
    if (_trackBox == null) {
      throw StateError('TrackCacheService not initialized. Call init() first.');
    }
    return _trackBox!;
  }

  Box<CachedAlbum> get _albums {
    if (_albumBox == null) {
      throw StateError('TrackCacheService not initialized. Call init() first.');
    }
    return _albumBox!;
  }

  @override
  Future<void> cacheTrack(CachedTrack track) async {
    await _tracks.put(track.trackId, track);
  }

  @override
  Future<CachedTrack?> getTrack(String trackId) async {
    return _tracks.get(trackId);
  }

  @override
  Future<void> updateLastPlayed(String trackId) async {
    final track = _tracks.get(trackId);
    if (track != null) {
      track.lastPlayedAt = DateTime.now();
      track.playCount += 1;
      await track.save();
    }
  }

  @override
  Future<void> cacheAlbum(CachedAlbum album) async {
    await _albums.put(album.albumId, album);
  }

  @override
  Future<CachedAlbum?> getAlbum(String albumId) async {
    return _albums.get(albumId);
  }

  @override
  Future<List<CachedTrack>> getAlbumTracks(String albumId) async {
    return _tracks.values.where((t) => t.albumId == albumId).toList();
  }

  @override
  Future<void> clearExpired() async {
    final cutoff = DateTime.now().subtract(CacheConfig.metadataMaxAge);

    // Clear expired tracks
    final expiredTrackKeys = _tracks.values
        .where((t) => t.cachedAt.isBefore(cutoff))
        .map((t) => t.trackId)
        .toList();
    for (final key in expiredTrackKeys) {
      await _tracks.delete(key);
    }

    // Clear expired albums
    final expiredAlbumKeys = _albums.values
        .where((a) => a.cachedAt.isBefore(cutoff))
        .map((a) => a.albumId)
        .toList();
    for (final key in expiredAlbumKeys) {
      await _albums.delete(key);
    }
  }

  @override
  Future<int> getCachedTrackCount() async {
    return _tracks.length;
  }

  @override
  Future<void> clearAll() async {
    await _tracks.clear();
    await _albums.clear();
  }

  @override
  Future<List<CachedTrack>> getRecentlyPlayed({int limit = 20}) async {
    final tracksWithPlays = _tracks.values
        .where((t) => t.lastPlayedAt != null)
        .toList();
    // Sort by lastPlayedAt descending (most recent first)
    tracksWithPlays.sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return tracksWithPlays.take(limit).toList();
  }

  @override
  Future<List<CachedTrack>> getMostPlayed({int limit = 20}) async {
    final tracksWithPlays = _tracks.values
        .where((t) => t.playCount > 0)
        .toList();
    // Sort by playCount descending (highest first)
    tracksWithPlays.sort((a, b) => b.playCount.compareTo(a.playCount));
    return tracksWithPlays.take(limit).toList();
  }

  @override
  Future<List<CachedTrack>> getOfflineAvailable() async {
    return _tracks.values.where((t) => t.isAvailableOffline).toList();
  }

  @override
  Future<List<CachedTrack>> getAllTracks() async {
    return _tracks.values.toList();
  }

  @override
  Future<List<CachedAlbum>> getAllAlbums() async {
    return _albums.values.toList();
  }

  @override
  Future<CacheStats> getStats() async {
    final tracks = _tracks.values.toList();
    final offlineCount = tracks.where((t) => t.isAvailableOffline).length;
    final totalPlays = tracks.fold<int>(0, (sum, t) => sum + t.playCount);

    return CacheStats(
      trackCount: tracks.length,
      albumCount: _albums.length,
      offlineTrackCount: offlineCount,
      totalPlayCount: totalPlays,
    );
  }
}
