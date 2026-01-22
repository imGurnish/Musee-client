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

  /// Update the last played timestamp for LRU tracking
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
}
