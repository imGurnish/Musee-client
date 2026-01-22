import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:musee/core/cache/cache_config.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';

/// Service for downloading and caching audio files locally.
abstract class AudioCacheService {
  /// Initialize the audio cache directory
  Future<void> init();

  /// Get local file path for a cached track, or null if not cached
  Future<String?> getLocalAudioPath(String trackId);

  /// Download audio file and cache it locally
  /// Returns the local file path on success
  Future<String?> downloadAndCache({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
  });

  /// Delete a specific cached audio file
  Future<void> deleteAudio(String trackId);

  /// Get total size of all cached audio files in bytes
  Future<int> getTotalCacheSize();

  /// Clear oldest cached files to stay under size limit
  Future<void> enforceMaxSize(TrackCacheService trackCache);

  /// Clear all cached audio files
  Future<void> clearAll();
}

class AudioCacheServiceImpl implements AudioCacheService {
  final Dio _dio;
  Directory? _cacheDir;

  AudioCacheServiceImpl(this._dio);

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/audio_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  Directory get _dir {
    if (kIsWeb) {
      throw UnsupportedError('Audio caching is not supported on web');
    }
    if (_cacheDir == null) {
      throw StateError('AudioCacheService not initialized. Call init() first.');
    }
    return _cacheDir!;
  }

  String _getFilePath(String trackId, String ext) {
    return '${_dir.path}/$trackId.$ext';
  }

  @override
  Future<String?> getLocalAudioPath(String trackId) async {
    if (kIsWeb) return null;
    // Check for common audio extensions
    for (final ext in ['mp3', 'm4a', 'aac', 'flac']) {
      final file = File(_getFilePath(trackId, ext));
      if (await file.exists()) {
        return file.path;
      }
    }
    return null;
  }

  @override
  Future<String?> downloadAndCache({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
  }) async {
    if (kIsWeb) return null;
    try {
      // Determine file extension from URL
      final uri = Uri.parse(remoteUrl);
      String ext = 'mp3';
      final pathSegments = uri.path.split('.');
      if (pathSegments.length > 1) {
        final urlExt = pathSegments.last.toLowerCase();
        if (['mp3', 'm4a', 'aac', 'flac', 'wav'].contains(urlExt)) {
          ext = urlExt;
        }
      }

      final filePath = _getFilePath(trackId, ext);
      final file = File(filePath);

      // Download the file
      await _dio.download(
        remoteUrl,
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      // Update the track cache with local path and file size
      final track = await trackCache.getTrack(trackId);
      if (track != null) {
        track.localAudioPath = filePath;
        track.audioSizeBytes = await file.length();
        await trackCache.cacheTrack(track);
      }

      return filePath;
    } catch (e) {
      // Download failed, return null
      return null;
    }
  }

  @override
  Future<void> deleteAudio(String trackId) async {
    if (kIsWeb) return;
    for (final ext in ['mp3', 'm4a', 'aac', 'flac']) {
      final file = File(_getFilePath(trackId, ext));
      if (await file.exists()) {
        await file.delete();
        break;
      }
    }
  }

  @override
  Future<int> getTotalCacheSize() async {
    if (kIsWeb) return 0;
    int totalSize = 0;
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }

  @override
  Future<void> enforceMaxSize(TrackCacheService trackCache) async {
    if (kIsWeb) return;
    final currentSize = await getTotalCacheSize();
    if (currentSize <= CacheConfig.maxAudioCacheSizeBytes) return;

    // Get all tracks with local audio, sorted by last played (oldest first)
    // This is a simplified LRU - in production you'd query the DB ordered by lastPlayedAt
    final tracksToDelete = <CachedTrack>[];
    int freedBytes = 0;
    final targetFree = currentSize - CacheConfig.maxAudioCacheSizeBytes;

    // Note: This is a placeholder - proper implementation would query Isar
    // with ordering by lastPlayedAt. For now, we'll rely on clearAll for simplicity.

    for (final track in tracksToDelete) {
      if (freedBytes >= targetFree) break;
      if (track.localAudioPath != null) {
        await deleteAudio(track.trackId);
        freedBytes += track.audioSizeBytes;
        track.localAudioPath = null;
        track.audioSizeBytes = 0;
        await trackCache.cacheTrack(track);
      }
    }
  }

  @override
  Future<void> clearAll() async {
    if (kIsWeb) return;
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }
}
