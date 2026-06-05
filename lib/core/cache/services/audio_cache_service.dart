import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:musee/core/cache/cache_config.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/player/player_cubit.dart';

/// Service for downloading and caching audio files locally.
abstract class AudioCacheService {
  /// Initialize the audio cache directory
  Future<void> init();

  /// Get local file path for a cached track, or null if not cached
  Future<String?> getLocalAudioPath(String trackId);

  /// Get local playback URI (localhost HTTP URL or file URI) for a cached track
  Future<String?> getLocalPlaybackUri(
    String trackId, {
    int? targetBitrate,
    required TrackCacheService trackCache,
    bool isOnline,
  });

  /// Download audio file and cache it locally
  /// Returns the local file path on success
  Future<String?> downloadAndCache({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
    String? preferredHlsUrl,
    int? preferredHlsBitrate,
    int? maxCacheSizeBytes,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    List<String>? protectedTrackIds,
  });

  /// Delete a specific cached audio file
  Future<void> deleteAudio(String trackId);

  /// Get total size of all cached audio files in bytes
  Future<int> getTotalCacheSize();

  /// Clear oldest cached files to stay under size limit
  Future<void> enforceMaxSize({
    required int maxCacheSizeBytes,
    required TrackCacheService trackCache,
    List<String>? protectedTrackIds,
  });

  /// Clear all cached audio files
  Future<void> clearAll();
}

class AudioCacheServiceImpl implements AudioCacheService {
  final Dio _dio;
  Directory? _cacheDir;
  HttpServer? _localServer;
  final Set<String> _activeDownloads = {};

  AudioCacheServiceImpl(this._dio);

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/audio_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    // Start local loopback HTTP server to serve cached audio files
    try {
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _localServer!.listen((request) async {
        try {
          final rawPath = request.uri.path.replaceFirst('/', '');
          final decodedPath = Uri.decodeComponent(rawPath);
          // Normalize backslashes from previously downloaded playlists to forward slashes
          final filePath = decodedPath.replaceAll(r'\', '/');
          final file = File('${_cacheDir!.path}/$filePath');

          if (await file.exists()) {
            if (filePath.endsWith('.m3u8')) {
              request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
            } else if (filePath.endsWith('.ts')) {
              request.response.headers.contentType = ContentType('video', 'mp2t');
            } else {
              request.response.headers.contentType = ContentType.binary;
            }
            await file.openRead().pipe(request.response);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });
      if (kDebugMode) {
        debugPrint('[AudioCacheService] Local HTTP server started on port ${_localServer!.port}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AudioCacheService] Failed to start local HTTP server: $e');
      }
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

  bool _isPlaylistUri(Uri uri) {
    return uri.path.toLowerCase().endsWith('.m3u8');
  }

  bool _sameRemoteResource(Uri a, Uri b) {
    return a.scheme == b.scheme &&
        a.host == b.host &&
        a.port == b.port &&
        a.path == b.path &&
        a.query == b.query;
  }

  List<String> _localSegmentsForUri(Uri uri, {required Uri rootUri}) {
    if (_sameRemoteResource(uri, rootUri)) {
      return const ['index.m3u8'];
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      return const ['index.m3u8'];
    }
    return segments;
  }

  String _localPathForSegments(
    List<String> segments, {
    required String basePath,
  }) {
    return '$basePath${Platform.pathSeparator}${segments.join(Platform.pathSeparator)}';
  }

  String _relativePathBetween(List<String> fromDirSegments, List<String> toFileSegments) {
    var sharedPrefix = 0;
    final maxShared = fromDirSegments.length < toFileSegments.length
        ? fromDirSegments.length
        : toFileSegments.length;
    while (sharedPrefix < maxShared &&
        fromDirSegments[sharedPrefix] == toFileSegments[sharedPrefix]) {
      sharedPrefix += 1;
    }

    final relativeParts = <String>[
      for (var i = sharedPrefix; i < fromDirSegments.length; i += 1) '..',
      ...toFileSegments.sublist(sharedPrefix),
    ];
    return relativeParts.isEmpty ? '.' : relativeParts.join('/');
  }

  Future<bool> _hasPlayableHlsCache(String trackId) async {
    final hlsDir = Directory(_getHlsDirPath(trackId));
    if (!await hlsDir.exists()) {
      return false;
    }

    var hasPlaylist = false;
    var hasMediaFile = false;
    await for (final entity in hlsDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final lowerPath = entity.path.toLowerCase();
      if (lowerPath.endsWith('.m3u8')) {
        hasPlaylist = true;
      } else {
        hasMediaFile = true;
      }
    }

    return hasPlaylist && hasMediaFile;
  }

  Future<({String path, List<String> segments})> _cacheHlsUri({
    required Uri uri,
    required Uri rootUri,
    required String basePath,
    required Set<String> visited,
    _HlsProgress? progressTracker,
    CancelToken? cancelToken,
  }) async {
    final localSegments = _localSegmentsForUri(uri, rootUri: rootUri);
    final localPath = _localPathForSegments(localSegments, basePath: basePath);

    if (!_isPlaylistUri(uri)) {
      progressTracker?.addFile();
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await _dio.download(
        uri.toString(),
        localPath,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes, followRedirects: true),
      );
      progressTracker?.completeFile();
      return (path: localPath, segments: localSegments);
    }

    final cacheKey = uri.toString();
    if (visited.contains(cacheKey) && await File(localPath).exists()) {
      return (path: localPath, segments: localSegments);
    }
    visited.add(cacheKey);

    progressTracker?.addFile();
    final playlistFile = File(localPath);
    await playlistFile.parent.create(recursive: true);

    final playlistResp = await _dio.get<String>(
      uri.toString(),
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.plain, followRedirects: true),
    );

    final rawPlaylist = playlistResp.data ?? '';
    if (rawPlaylist.trim().isEmpty) {
      throw StateError('Empty HLS playlist');
    }

    final rewritten = <String>[];
    final lines = rawPlaylist.split('\n');
    final playlistDirSegments = localSegments.isEmpty
        ? const <String>[]
        : localSegments.take(localSegments.length - 1).toList(growable: false);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        rewritten.add(line);
        continue;
      }

      final childUri = uri.resolve(trimmed);
      final childCache = await _cacheHlsUri(
        uri: childUri,
        rootUri: rootUri,
        basePath: basePath,
        visited: visited,
        progressTracker: progressTracker,
        cancelToken: cancelToken,
      );

      rewritten.add(
        _relativePathBetween(playlistDirSegments, childCache.segments),
      );
    }

    await playlistFile.writeAsString('${rewritten.join('\n')}\n');
    progressTracker?.completeFile();
    return (path: localPath, segments: localSegments);
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
    int? preferredHlsBitrate,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final hlsDir = Directory(_getHlsDirPath(trackId));
    if (await hlsDir.exists()) {
      await hlsDir.delete(recursive: true);
    }
    await hlsDir.create(recursive: true);

    try {
      final rootUri = Uri.parse(remoteUrl);
      final progressTracker = _HlsProgress((received, total) {
        if (onProgress != null) {
          onProgress(received, total);
        }
      });

      final cachedRoot = await _cacheHlsUri(
        uri: rootUri,
        rootUri: rootUri,
        basePath: hlsDir.path,
        visited: <String>{},
        progressTracker: progressTracker,
        cancelToken: cancelToken,
      );

      final playlistLocalPath = cachedRoot.path;

      final track = await trackCache.getTrack(trackId);
      if (track != null) {
        track.localAudioPath = playlistLocalPath;
        track.audioSizeBytes = await _dirSizeBytes(hlsDir);
        track.cachedHlsVariantUrl = remoteUrl;
        track.cachedHlsBitrate = preferredHlsBitrate ?? track.cachedHlsBitrate;
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
    if (await hlsPlaylist.exists() && await _hasPlayableHlsCache(trackId)) {
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
  Future<String?> getLocalPlaybackUri(
    String trackId, {
    int? targetBitrate,
    required TrackCacheService trackCache,
    bool isOnline = true,
  }) async {
    if (kIsWeb) return null;

    final path = await getLocalAudioPath(trackId);
    if (path == null) return null;

    final isHls = await _hasPlayableHlsCache(trackId);
    if (isHls) {
      final cachedTrack = await trackCache.getTrack(trackId);
      final cachedBitrate = cachedTrack?.cachedHlsBitrate;

      if (cachedBitrate != null) {
        if (isOnline) {
          if (targetBitrate == null) {
            // Target is Auto (adaptive, up to 320 kbps).
            // Serve from cache only if we have the highest quality (320).
            if (cachedBitrate < 320) {
              return null; // Force network stream (master)
            }
          } else {
            // Target is specific quality. Serve from cache if cached quality is equal or better.
            if (cachedBitrate < targetBitrate) {
              return null; // Force network stream of higher quality
            }
          }
        }
      }
    }

    if (_localServer != null) {
      if (isHls) {
        return 'http://localhost:${_localServer!.port}/${trackId}_hls/index.m3u8';
      } else {
        final file = File(path);
        final ext = file.path.split('.').last;
        return 'http://localhost:${_localServer!.port}/$trackId.$ext';
      }
    }

    // Fallback if local server failed to start
    return Uri.file(path).toString();
  }

  @override
  Future<String?> downloadAndCache({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
    String? preferredHlsUrl,
    int? preferredHlsBitrate,
    int? maxCacheSizeBytes,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    List<String>? protectedTrackIds,
  }) async {
    if (kIsWeb) return null;
    _activeDownloads.add(trackId);
    try {
      final existingLocalPath = await getLocalAudioPath(trackId);
      final existingTrack = await trackCache.getTrack(trackId);

      if (existingLocalPath != null &&
          existingTrack?.cachedHlsBitrate != null &&
          preferredHlsBitrate != null &&
          existingTrack!.cachedHlsBitrate! >= preferredHlsBitrate) {
        return existingLocalPath;
      }

      if (existingLocalPath != null) {
        if (preferredHlsBitrate != null &&
            existingTrack?.cachedHlsBitrate != null &&
            existingTrack!.cachedHlsBitrate! < preferredHlsBitrate) {
          final hlsDir = Directory(_getHlsDirPath(trackId));
          if (await hlsDir.exists()) {
            await hlsDir.delete(recursive: true);
          }
        } else {
          if (existingTrack != null && existingTrack.localAudioPath != existingLocalPath) {
            existingTrack.localAudioPath = existingLocalPath;
            await trackCache.cacheTrack(existingTrack);
          }
          return existingLocalPath;
        }
      }

      final hlsDir = Directory(_getHlsDirPath(trackId));
      if (await hlsDir.exists()) {
        await hlsDir.delete(recursive: true);
      }

      String? resultPath;

      if (_isLikelyHlsPlaylistUrl(remoteUrl)) {
        final hlsUrl = preferredHlsUrl ?? remoteUrl;
        resultPath = await _downloadAndCacheHls(
          trackId: trackId,
          remoteUrl: hlsUrl,
          trackCache: trackCache,
          preferredHlsBitrate: preferredHlsBitrate,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else {
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
        }

        final savedFile = File(filePath);

        // Update the track cache with local path and file size
        final track = await trackCache.getTrack(trackId);
        if (track != null) {
          track.localAudioPath = filePath;
          track.audioSizeBytes = await savedFile.length();
          await trackCache.cacheTrack(track);
        }

        resultPath = filePath;
      }

      if (resultPath != null) {
        final maxLimit = maxCacheSizeBytes ?? CacheConfig.maxAudioCacheSizeBytes;
        await enforceMaxSize(
          maxCacheSizeBytes: maxLimit,
          trackCache: trackCache,
          protectedTrackIds: {
            if (protectedTrackIds != null) ...protectedTrackIds,
            trackId,
          }.toList(),
        );
      }

      return resultPath;
    } catch (e) {
      // Download failed, return null
      return null;
    } finally {
      _activeDownloads.remove(trackId);
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
  Future<void> enforceMaxSize({
    required int maxCacheSizeBytes,
    required TrackCacheService trackCache,
    List<String>? protectedTrackIds,
  }) async {
    if (kIsWeb) return;

    // 1. Clean up orphaned files/folders on disk whose trackId is NOT registered in Hive
    // and is not currently in the protected list.
    final List<CachedTrack> allTracks = await trackCache.getAllTracks();
    final Set<String> registeredTrackIds = allTracks
        .where((t) => t.isAvailableOffline)
        .map((t) => t.trackId)
        .toSet();

    final protectSet = <String>{
      if (protectedTrackIds != null) ...protectedTrackIds,
      ..._activeDownloads,
    };

    // Dynamically retrieve player status from GetIt if registered, to protect currently playing and prefetching tracks
    try {
      if (GetIt.instance.isRegistered<PlayerCubit>()) {
        final player = GetIt.instance<PlayerCubit>();
        final currentTrackId = player.state.track?.trackId;
        if (currentTrackId != null) {
          protectSet.add(currentTrackId);
        }
        final queue = player.state.queue;
        final currentIndex = player.state.currentIndex;
        if (queue.isNotEmpty && currentIndex >= 0 && currentIndex + 1 < queue.length) {
          protectSet.add(queue[currentIndex + 1].trackId);
        }
      }
    } catch (_) {
      // Guard against any issues during early initialization
    }

    if (await _dir.exists()) {
      await for (final entity in _dir.list(recursive: false, followLinks: false)) {
        String? trackId;
        final name = entity.path.replaceAll(r'\', '/').split('/').last;
        if (entity is Directory) {
          if (name.endsWith('_hls')) {
            trackId = name.substring(0, name.length - 4);
          }
        } else if (entity is File) {
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex != -1) {
            trackId = name.substring(0, dotIndex);
          }
        }

        if (trackId != null && !registeredTrackIds.contains(trackId) && !protectSet.contains(trackId)) {
          try {
            if (entity is Directory) {
              await entity.delete(recursive: true);
            } else {
              await entity.delete();
            }
            if (kDebugMode) {
              debugPrint('[AudioCacheService] Cleaned up orphaned cache: ${entity.path}');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[AudioCacheService] Failed to delete orphaned cache entity ${entity.path}: $e');
            }
          }
        }
      }
    }

    // 2. Now calculate size and run LRU eviction if we exceed the limit
    final currentSize = await getTotalCacheSize();
    if (currentSize <= maxCacheSizeBytes) return;

    // Get all cached tracks that have offline files
    final offlineTracks = allTracks.where((t) => t.isAvailableOffline).toList();

    // Sort by lastPlayedAt ascending (oldest first). If lastPlayedAt is null, use cachedAt.
    offlineTracks.sort((a, b) {
      final timeA = a.lastPlayedAt ?? a.cachedAt;
      final timeB = b.lastPlayedAt ?? b.cachedAt;
      return timeA.compareTo(timeB);
    });

    int freedBytes = 0;
    final targetFree = currentSize - maxCacheSizeBytes;

    for (final track in offlineTracks) {
      if (freedBytes >= targetFree) break;

      // Skip protected tracks
      if (protectSet.contains(track.trackId)) {
        if (kDebugMode) {
          debugPrint('[AudioCacheService] Skipping eviction of protected track ${track.trackId} ("${track.title}")');
        }
        continue;
      }

      if (track.localAudioPath != null) {
        final trackSize = track.audioSizeBytes > 0 ? track.audioSizeBytes : 0;
        await deleteAudio(track.trackId);
        freedBytes += trackSize;
        track.localAudioPath = null;
        track.audioSizeBytes = 0;
        track.cachedHlsBitrate = null;
        track.cachedHlsVariantUrl = null;
        await trackCache.cacheTrack(track);
        if (kDebugMode) {
          debugPrint('[AudioCacheService] Evicted track ${track.trackId} ("${track.title}") to free $trackSize bytes');
        }
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

class _HlsProgress {
  int total = 0;
  int completed = 0;
  final void Function(int received, int total)? onProgress;

  _HlsProgress(this.onProgress);

  void addFile() {
    total++;
    _report();
  }

  void completeFile() {
    completed++;
    _report();
  }

  void _report() {
    if (onProgress != null && total > 0) {
      onProgress!(completed, total);
    }
  }
}
