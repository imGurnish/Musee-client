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
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
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

  String _getHlsDirPath(String trackId) {
    return '${_dir.path}/${trackId}_hls';
  }

  bool _isLikelyHlsPlaylistUrl(String remoteUrl) {
    final normalized = remoteUrl.toLowerCase();
    return normalized.contains('.m3u8');
  }

  String _sanitizeSegmentName(String raw, int index) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'seg_${index.toString().padLeft(5, '0')}.ts';
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'seg_${index.toString().padLeft(5, '0')}.ts' : safe;
  }

  Future<int> _dirSizeBytes(Directory dir) async {
    int total = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<String?> _downloadAndCacheHls({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final hlsDir = Directory(_getHlsDirPath(trackId));
    if (await hlsDir.exists()) {
      await hlsDir.delete(recursive: true);
    }
    await hlsDir.create(recursive: true);

    try {
      final playlistResp = await _dio.get<String>(
        remoteUrl,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.plain, followRedirects: true),
      );

      final rawPlaylist = playlistResp.data ?? '';
      if (rawPlaylist.trim().isEmpty) {
        throw StateError('Empty HLS playlist');
      }

      final sourceUri = Uri.parse(remoteUrl);
      final lines = rawPlaylist.split('\n');
      final rewritten = <String>[];
      final segmentEntries = <({int lineIndex, String segmentRef})>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          rewritten.add(line);
          continue;
        }
        final rewrittenIndex = rewritten.length;
        segmentEntries.add((lineIndex: rewrittenIndex, segmentRef: trimmed));
        rewritten.add(trimmed);
      }

      final totalSegments = segmentEntries.length;
      for (var i = 0; i < segmentEntries.length; i++) {
        final segRef = segmentEntries[i].segmentRef;
        final segUri = sourceUri.resolve(segRef);
        final fileName = _sanitizeSegmentName(
          segUri.pathSegments.isNotEmpty ? segUri.pathSegments.last : '',
          i,
        );

        final localPath = '${hlsDir.path}/$fileName';
        await _dio.download(
          segUri.toString(),
          localPath,
          cancelToken: cancelToken,
          options: Options(responseType: ResponseType.bytes, followRedirects: true),
        );

        rewritten[segmentEntries[i].lineIndex] = fileName;

        onProgress?.call(i + 1, totalSegments == 0 ? 1 : totalSegments);
      }

      final playlistLocalPath = '${hlsDir.path}/index.m3u8';
      final playlistFile = File(playlistLocalPath);
      await playlistFile.writeAsString('${rewritten.join('\n')}\n');

      final track = await trackCache.getTrack(trackId);
      if (track != null) {
        track.localAudioPath = playlistLocalPath;
        track.audioSizeBytes = await _dirSizeBytes(hlsDir);
        await trackCache.cacheTrack(track);
      }

      return playlistLocalPath;
    } catch (_) {
      if (await hlsDir.exists()) {
        await hlsDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  @override
  Future<String?> getLocalAudioPath(String trackId) async {
    if (kIsWeb) return null;

    final hlsPlaylist = File('${_getHlsDirPath(trackId)}/index.m3u8');
    if (await hlsPlaylist.exists()) {
      return hlsPlaylist.path;
    }

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
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (kIsWeb) return null;
    try {
      if (_isLikelyHlsPlaylistUrl(remoteUrl)) {
        return await _downloadAndCacheHls(
          trackId: trackId,
          remoteUrl: remoteUrl,
          trackCache: trackCache,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      }

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

      var filePath = _getFilePath(trackId, ext);
      final file = File(filePath);

      // Download the file
      final response = await _dio.download(
        remoteUrl,
        filePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      // Verify content type and correct extension if needed
      final contentType = response.headers.value('content-type');
      String correctExt = ext;

      if (contentType != null) {
        if (contentType.contains('audio/mp4') ||
            contentType.contains('audio/m4a') ||
            contentType.contains('audio/x-m4a')) {
          correctExt = 'm4a';
        } else if (contentType.contains('audio/mpeg') ||
            contentType.contains('audio/mp3')) {
          correctExt = 'mp3';
        } else if (contentType.contains('audio/aac')) {
          correctExt = 'aac';
        } else if (contentType.contains('audio/flac')) {
          correctExt = 'flac';
        } else if (contentType.contains('audio/wav')) {
          correctExt = 'wav';
        }
      }

      // If extension needs correction, rename the file
      if (correctExt != ext) {
        final newPath = _getFilePath(trackId, correctExt);
        // Rename (move)
        await file.rename(newPath);

        // Update variables for registration
        filePath = newPath;
        // Check if old file exists (rename should move it)
      }

      final savedFile = File(filePath);

      // Update the track cache with local path and file size
      final track = await trackCache.getTrack(trackId);
      if (track != null) {
        track.localAudioPath = filePath;
        track.audioSizeBytes = await savedFile.length();
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
    final hlsDir = Directory(_getHlsDirPath(trackId));
    if (await hlsDir.exists()) {
      await hlsDir.delete(recursive: true);
    }
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
      await for (final entity in _dir.list(recursive: true, followLinks: false)) {
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
      await for (final entity in _dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    }
  }
}
