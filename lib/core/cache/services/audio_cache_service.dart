import 'dart:async';
import 'dart:convert';
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
    bool isDownload = false,
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

  /// Flag to suspend enforceMaxSize during bulk downloads to avoid I/O thrashing
  bool get isBulkDownloading;
  set isBulkDownloading(bool value);

  /// Increment active player reference count for a file/directory path
  void incrementRef(String path);

  /// Decrement active player reference count for a file/directory path
  void decrementRef(String path);

  /// Check if a path (or any parent/child path) is in use by any player
  bool isPathInUse(String path);

  /// Helper to convert a local HTTP playback URI or file URI back to its absolute local path
  String? getLocalPathFromUri(String uri);

  /// Run crash recovery on startup to clean up uncommitted or partially deleted caches
  Future<void> recoverIncompleteOperations(TrackCacheService trackCache);

  /// Reconcile Hive metadata with actual disk usage, repairing inconsistencies
  Future<void> reconcileDiskUsage({required TrackCacheService trackCache});

  /// Scan the cache directory and rebuild the Hive database from sidecar track.json files if lost
  Future<void> rebuildHiveFromSidecars(TrackCacheService trackCache);
}

class AudioCacheServiceImpl implements AudioCacheService {
  final Dio _dio;
  Directory? _cacheDir;
  HttpServer? _localServer;
  final Set<String> _activeDownloads = {};
  final Map<String, ({CancelToken cancelToken, bool isDownload, Future<String?> future})> _activeOperations = {};

  AudioCacheServiceImpl(this._dio);

  @override
  bool isBulkDownloading = false;

  final Map<String, int> _pathRefCounts = {};

  @override
  void incrementRef(String path) {
    final normalized = path.replaceAll(r'\', '/');
    _pathRefCounts[normalized] = (_pathRefCounts[normalized] ?? 0) + 1;
  }

  @override
  void decrementRef(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final current = _pathRefCounts[normalized] ?? 0;
    if (current <= 1) {
      _pathRefCounts.remove(normalized);
    } else {
      _pathRefCounts[normalized] = current - 1;
    }
  }

  @override
  bool isPathInUse(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final count = _pathRefCounts[normalized] ?? 0;
    if (count > 0) return true;

    for (final activePath in _pathRefCounts.keys) {
      if (activePath.contains(normalized) || normalized.contains(activePath)) {
        return true;
      }
    }
    return false;
  }

  @override
  String? getLocalPathFromUri(String uri) {
    if (kIsWeb) return null;
    try {
      final parsed = Uri.parse(uri);
      if (parsed.isScheme('file')) {
        return File(parsed.toFilePath()).path;
      }
      if (parsed.host == 'localhost' || parsed.host == '127.0.0.1') {
        final pathSegments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
        if (pathSegments.isNotEmpty) {
          final firstSegment = pathSegments.first;
          return '${_dir.path}/$firstSegment';
        }
      }
    } catch (_) {}
    return null;
  }

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

            // Advertise and honour byte ranges so the player can seek within
            // cached single-file audio (mp3/m4a) and resume mid-track instead of
            // refetching the whole file. Without this, seeking on cached/
            // downloaded tracks fails because every request returns the full 200.
            final length = await file.length();
            request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

            final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
            if (rangeHeader != null && rangeHeader.startsWith('bytes=') && length > 0) {
              final spec = rangeHeader.substring(6).split('-');
              final start = int.tryParse(spec[0]) ?? 0;
              final end = (spec.length > 1 && spec[1].isNotEmpty)
                  ? (int.tryParse(spec[1]) ?? length - 1)
                  : length - 1;
              final safeStart = start.clamp(0, length - 1);
              final safeEnd = end.clamp(safeStart, length - 1);

              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                HttpHeaders.contentRangeHeader,
                'bytes $safeStart-$safeEnd/$length',
              );
              request.response.contentLength = safeEnd - safeStart + 1;
              await file.openRead(safeStart, safeEnd + 1).pipe(request.response);
            } else {
              request.response.contentLength = length;
              await file.openRead().pipe(request.response);
            }
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

    unawaited(() async {
      try {
        final trackCache = GetIt.I<TrackCacheService>();
        await rebuildHiveFromSidecars(trackCache);
        await recoverIncompleteOperations(trackCache);
        await reconcileDiskUsage(trackCache: trackCache);
      } catch (_) {}
    }());
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

  String _getHlsDirPath(String trackId, {int? bitrate}) {
    final br = bitrate ?? _getCachedBitrateSync(trackId);
    final suffix = br != null ? '_$br' : '';
    return '${_dir.path}/${trackId}_hls$suffix';
  }

  int? _getCachedBitrateSync(String trackId) {
    try {
      final trackCache = GetIt.I<TrackCacheService>();
      final track = trackCache.getTrackSync(trackId);
      return track?.cachedHlsBitrate;
    } catch (_) {}
    return null;
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

  Future<bool> _verifyHlsCacheComplete(String hlsDirPath) async {
    final playlistFile = File('$hlsDirPath/index.m3u8');
    if (!await playlistFile.exists()) {
      return false;
    }
    try {
      final content = await playlistFile.readAsString();
      final lines = content.split('\n');
      var segmentFound = false;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        segmentFound = true;
        // Resolve HLS segment path relative to hlsDirPath
        final segmentFile = File('$hlsDirPath/$trimmed');
        if (!await segmentFile.exists() || await segmentFile.length() == 0) {
          return false;
        }
      }
      return segmentFound;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _verifyAudioPathExists(String path) async {
    try {
      if (path.contains('_hls')) {
        final dir = Directory(path).parent;
        return await dir.exists() && await _verifyHlsCacheComplete(dir.path);
      } else {
        final file = File(path);
        return await file.exists() && await file.length() > 0;
      }
    } catch (_) {}
    return false;
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

  Future<void> _saveSidecarMetadataForHls(CachedTrack track, String dirPath) async {
    try {
      final file = File('$dirPath/track.json');
      final map = {
        'trackId': track.trackId,
        'title': track.title,
        'artistName': track.artistName,
        'albumTitle': track.albumTitle,
        'albumId': track.albumId,
        'albumCoverUrl': track.albumCoverUrl,
        'durationSeconds': track.durationSeconds,
        'isExplicit': track.isExplicit,
        'audioSizeBytes': track.audioSizeBytes,
        'cachedHlsBitrate': track.cachedHlsBitrate,
        'cachedHlsVariantUrl': track.cachedHlsVariantUrl,
        'downloadedAudioPath': track.downloadedAudioPath,
        'downloadedAudioSizeBytes': track.downloadedAudioSizeBytes,
        'downloadedHlsBitrate': track.downloadedHlsBitrate,
        'downloadedHlsVariantUrl': track.downloadedHlsVariantUrl,
        'isDownloaded': track.isDownloaded,
        'sourceProvider': track.sourceProvider,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }

  Future<String?> _downloadAndCacheHls({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
    int? preferredHlsBitrate,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    bool isDownload = false,
  }) async {
    final targetHlsDir = Directory(_getHlsDirPath(trackId, bitrate: preferredHlsBitrate));
    final tempHlsDir = Directory('${targetHlsDir.path}_tmp');
    
    if (await tempHlsDir.exists()) {
      await tempHlsDir.delete(recursive: true);
    }
    await tempHlsDir.create(recursive: true);

    try {
      final rootUri = Uri.parse(remoteUrl);
      final progressTracker = _HlsProgress((received, total) {
        if (onProgress != null) {
          onProgress(received, total);
        }
      });

      await _cacheHlsUri(
        uri: rootUri,
        rootUri: rootUri,
        basePath: tempHlsDir.path,
        visited: <String>{},
        progressTracker: progressTracker,
        cancelToken: cancelToken,
      );

      final complete = await _verifyHlsCacheComplete(tempHlsDir.path);
      if (!complete) {
        throw StateError('Downloaded HLS cache is incomplete');
      }

      Directory resolvedHlsDir = tempHlsDir;
      try {
        if (await targetHlsDir.exists()) {
          await targetHlsDir.delete(recursive: true);
        }
        await tempHlsDir.rename(targetHlsDir.path);
        resolvedHlsDir = targetHlsDir;
      } catch (_) {
        resolvedHlsDir = tempHlsDir;
      }

      final playlistLocalPath = '${resolvedHlsDir.path}/index.m3u8';

      final track = await trackCache.getTrack(trackId);
      if (track != null) {
        final dirSize = await _dirSizeBytes(resolvedHlsDir);
        if (isDownload) {
          track.downloadedAudioPath = playlistLocalPath;
          track.downloadedAudioSizeBytes = dirSize;
          track.downloadedHlsVariantUrl = remoteUrl;
          track.downloadedHlsBitrate = preferredHlsBitrate ?? track.downloadedHlsBitrate;
          track.isDownloaded = true;
        } else {
          track.localAudioPath = playlistLocalPath;
          track.audioSizeBytes = dirSize;
          track.cachedHlsVariantUrl = remoteUrl;
          track.cachedHlsBitrate = preferredHlsBitrate ?? track.cachedHlsBitrate;
        }
        await trackCache.cacheTrack(track);
        await _saveSidecarMetadataForHls(track, resolvedHlsDir.path);
      }

      return playlistLocalPath;
    } catch (_) {
      if (await tempHlsDir.exists()) {
        try {
          await tempHlsDir.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<String?> getLocalAudioPath(String trackId) async {
    if (kIsWeb) return null;

    try {
      final trackCache = GetIt.I<TrackCacheService>();
      final track = await trackCache.getTrack(trackId);
      if (track != null) {
        if (track.downloadedAudioPath != null && await _verifyAudioPathExists(track.downloadedAudioPath!)) {
          return track.downloadedAudioPath;
        }
        if (track.localAudioPath != null && await _verifyAudioPathExists(track.localAudioPath!)) {
          return track.localAudioPath;
        }
      }
    } catch (_) {}

    final hlsPlaylist = File('${_getHlsDirPath(trackId)}/index.m3u8');
    if (await hlsPlaylist.exists() && await _verifyHlsCacheComplete(hlsPlaylist.parent.path)) {
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

    final cachedTrack = await trackCache.getTrack(trackId);
    if (cachedTrack == null) return null;

    String? bestLocalPath;
    int? bestLocalBitrate;

    if (cachedTrack.localAudioPath != null && await _verifyAudioPathExists(cachedTrack.localAudioPath!)) {
      bestLocalPath = cachedTrack.localAudioPath;
      bestLocalBitrate = cachedTrack.cachedHlsBitrate;
    }

    if (cachedTrack.downloadedAudioPath != null && await _verifyAudioPathExists(cachedTrack.downloadedAudioPath!)) {
      final downloadBitrate = cachedTrack.downloadedHlsBitrate;
      if (bestLocalPath == null || (downloadBitrate != null && bestLocalBitrate != null && downloadBitrate > bestLocalBitrate)) {
        bestLocalPath = cachedTrack.downloadedAudioPath;
        bestLocalBitrate = downloadBitrate;
      }
    }

    if (bestLocalPath == null) return null;

    final isHls = bestLocalPath.contains('_hls');
    if (isHls && bestLocalBitrate != null) {
      if (isOnline) {
        if (targetBitrate == null) {
          if (bestLocalBitrate < 320) {
            return null;
          }
        } else {
          if (bestLocalBitrate < targetBitrate) {
            return null;
          }
        }
      }
    }

    if (_localServer != null) {
      if (isHls) {
        final suffix = bestLocalBitrate != null ? '_$bestLocalBitrate' : '';
        return 'http://localhost:${_localServer!.port}/${trackId}_hls$suffix/index.m3u8';
      } else {
        final ext = bestLocalPath.split('.').last;
        return 'http://localhost:${_localServer!.port}/$trackId.$ext';
      }
    }

    return Uri.file(bestLocalPath).toString();
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
    bool isDownload = false,
  }) async {
    if (kIsWeb) return null;

    // 1. Reconcile with active operations on the same track to prevent concurrent write conflicts
    final active = _activeOperations[trackId];
    if (active != null) {
      if (active.isDownload) {
        if (isDownload) {
          return active.future;
        } else {
          // Playback cache is covered by active download
          return null;
        }
      } else {
        if (isDownload) {
          // User download takes priority. Cancel active background cache and wait for it to exit.
          active.cancelToken.cancel();
          try {
            await active.future;
          } catch (_) {}
        } else {
          // Let current background cache finish
          return active.future;
        }
      }
    }

    final operationCancelToken = cancelToken ?? CancelToken();
    final completer = Completer<String?>();

    _activeOperations[trackId] = (
      cancelToken: operationCancelToken,
      isDownload: isDownload,
      future: completer.future,
    );

    try {
      final result = await _executeDownloadAndCache(
        trackId: trackId,
        remoteUrl: remoteUrl,
        trackCache: trackCache,
        preferredHlsUrl: preferredHlsUrl,
        preferredHlsBitrate: preferredHlsBitrate,
        maxCacheSizeBytes: maxCacheSizeBytes,
        onProgress: onProgress,
        cancelToken: operationCancelToken,
        protectedTrackIds: protectedTrackIds,
        isDownload: isDownload,
      );
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      if (_activeOperations[trackId]?.cancelToken == operationCancelToken) {
        _activeOperations.remove(trackId);
      }
    }
  }

  bool _isSameMediaAsset(String urlA, String urlB) {
    try {
      final uriA = Uri.parse(urlA);
      final uriB = Uri.parse(urlB);
      return uriA.scheme == uriB.scheme &&
          uriA.host == uriB.host &&
          uriA.path == uriB.path;
    } catch (_) {}
    return false;
  }

  Future<void> _saveSidecarMetadataForSingleFile(CachedTrack track, String filePath) async {
    try {
      final dotIndex = filePath.lastIndexOf('.');
      if (dotIndex == -1) return;
      final file = File('${filePath.substring(0, dotIndex)}.json');
      final map = {
        'trackId': track.trackId,
        'title': track.title,
        'artistName': track.artistName,
        'albumTitle': track.albumTitle,
        'albumId': track.albumId,
        'albumCoverUrl': track.albumCoverUrl,
        'durationSeconds': track.durationSeconds,
        'isExplicit': track.isExplicit,
        'audioSizeBytes': track.audioSizeBytes,
        'cachedHlsBitrate': track.cachedHlsBitrate,
        'cachedHlsVariantUrl': track.cachedHlsVariantUrl,
        'downloadedAudioPath': track.downloadedAudioPath,
        'downloadedAudioSizeBytes': track.downloadedAudioSizeBytes,
        'downloadedHlsBitrate': track.downloadedHlsBitrate,
        'downloadedHlsVariantUrl': track.downloadedHlsVariantUrl,
        'isDownloaded': track.isDownloaded,
        'sourceProvider': track.sourceProvider,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }

  Future<String?> _executeDownloadAndCache({
    required String trackId,
    required String remoteUrl,
    required TrackCacheService trackCache,
    String? preferredHlsUrl,
    int? preferredHlsBitrate,
    int? maxCacheSizeBytes,
    void Function(int received, int total)? onProgress,
    required CancelToken cancelToken,
    List<String>? protectedTrackIds,
    required bool isDownload,
  }) async {
    _activeDownloads.add(trackId);
    
    // Begin transaction: set downloadState to 'downloading'
    CachedTrack? track = await trackCache.getTrack(trackId);
    track ??= CachedTrack()
      ..trackId = trackId
      ..title = 'Unknown Title'
      ..artistName = 'Unknown Artist'
      ..cachedAt = DateTime.now();
    track.downloadState = 'downloading';
    await trackCache.cacheTrack(track);

    try {
      final existingTrack = await trackCache.getTrack(trackId);

      if (existingTrack != null) {
        if (isDownload) {
          final existingDownloadPath = existingTrack.downloadedAudioPath;
          if (existingDownloadPath != null) {
            bool isQualityMatch = true;
            if (preferredHlsBitrate != null && existingTrack.downloadedHlsBitrate != null) {
              isQualityMatch = existingTrack.downloadedHlsBitrate == preferredHlsBitrate;
            }
            bool isAssetMatch = true;
            if (existingTrack.downloadedHlsVariantUrl != null) {
              isAssetMatch = _isSameMediaAsset(existingTrack.downloadedHlsVariantUrl!, remoteUrl);
            }

            if (isQualityMatch && isAssetMatch) {
              final exists = await _verifyAudioPathExists(existingDownloadPath);
              if (exists) {
                if (!existingTrack.isDownloaded) {
                  existingTrack.isDownloaded = true;
                  await trackCache.cacheTrack(existingTrack);
                }
                return existingDownloadPath;
              }
            }
          }
        } else {
          final existingCachePath = existingTrack.localAudioPath;
          if (existingCachePath != null) {
            bool isQualityMatch = true;
            if (preferredHlsBitrate != null && existingTrack.cachedHlsBitrate != null) {
              isQualityMatch = existingTrack.cachedHlsBitrate! >= preferredHlsBitrate;
            }
            bool isAssetMatch = true;
            if (existingTrack.cachedHlsVariantUrl != null) {
              isAssetMatch = _isSameMediaAsset(existingTrack.cachedHlsVariantUrl!, remoteUrl);
            }

            if (isQualityMatch && isAssetMatch) {
              final exists = await _verifyAudioPathExists(existingCachePath);
              if (exists) {
                return existingCachePath;
              }
            }
          }

          final existingDownloadPath = existingTrack.downloadedAudioPath;
          if (existingDownloadPath != null) {
            bool isQualityMatch = true;
            if (preferredHlsBitrate != null && existingTrack.downloadedHlsBitrate != null) {
              isQualityMatch = existingTrack.downloadedHlsBitrate! >= preferredHlsBitrate;
            }
            bool isAssetMatch = true;
            if (existingTrack.downloadedHlsVariantUrl != null) {
              isAssetMatch = _isSameMediaAsset(existingTrack.downloadedHlsVariantUrl!, remoteUrl);
            }

            if (isQualityMatch && isAssetMatch) {
              final exists = await _verifyAudioPathExists(existingDownloadPath);
              if (exists) {
                return existingDownloadPath;
              }
            }
          }
        }

        // Quality or asset URL mismatch for target.
        // Delete the target directory if it exists, to prepare for a fresh download.
        // BUT do not delete any actively playing/locked directory.
        if (_isLikelyHlsPlaylistUrl(remoteUrl)) {
          final targetHlsDir = Directory(_getHlsDirPath(trackId, bitrate: preferredHlsBitrate));
          if (await targetHlsDir.exists()) {
            try {
              await targetHlsDir.delete(recursive: true);
            } catch (_) {}
          }
        } else {
          for (final ext in ['mp3', 'm4a', 'aac', 'flac', 'wav']) {
            final file = File(_getFilePath(trackId, ext));
            if (await file.exists()) {
              try {
                await file.delete();
              } catch (_) {}
            }
          }
        }
      }

      if (cancelToken.isCancelled) return null;

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
          isDownload: isDownload,
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

        if (cancelToken.isCancelled) return null;

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
          await file.rename(newPath);
          filePath = newPath;
        }

        final savedFile = File(filePath);

        // Update the track cache with local path and file size
        final t = await trackCache.getTrack(trackId);
        if (t != null) {
          final fileSize = await savedFile.length();
          if (isDownload) {
            t.downloadedAudioPath = filePath;
            t.downloadedAudioSizeBytes = fileSize;
            t.isDownloaded = true;
          } else {
            t.localAudioPath = filePath;
            t.audioSizeBytes = fileSize;
          }
          await trackCache.cacheTrack(t);
          await _saveSidecarMetadataForSingleFile(t, filePath);
        }

        resultPath = filePath;
      }

      // Commit transaction: set downloadState to 'committed' (or null)
      final committedTrack = await trackCache.getTrack(trackId);
      if (committedTrack != null) {
        committedTrack.downloadState = 'committed';
        await trackCache.cacheTrack(committedTrack);
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
    } catch (e, stackTrace) {
      final isCancel = e is DioException && e.type == DioExceptionType.cancel;
      if (kDebugMode) {
        if (isCancel) {
          debugPrint('[AudioCacheService] Download/Cache cancelled for track $trackId');
        } else {
          debugPrint('[AudioCacheService] _executeDownloadAndCache failed for track $trackId: $e');
          debugPrint(stackTrace.toString());
        }
      }

      // Cleanup files/directories on cancellation or error
      try {
        if (_isLikelyHlsPlaylistUrl(remoteUrl)) {
          final targetHlsDir = Directory(_getHlsDirPath(trackId, bitrate: preferredHlsBitrate));
          if (await targetHlsDir.exists()) {
            await targetHlsDir.delete(recursive: true);
          }
          final tempHlsDir = Directory('${targetHlsDir.path}_tmp');
          if (await tempHlsDir.exists()) {
            await tempHlsDir.delete(recursive: true);
          }
        } else {
          for (final ext in ['mp3', 'm4a', 'aac', 'flac', 'wav']) {
            final file = File(_getFilePath(trackId, ext));
            if (await file.exists()) {
              await file.delete();
            }
            final dotIdx = file.path.lastIndexOf('.');
            if (dotIdx != -1) {
              final jsonFile = File('${file.path.substring(0, dotIdx)}.json');
              if (await jsonFile.exists()) {
                await jsonFile.delete();
              }
            }
          }
        }
      } catch (_) {}

      // Reset downloadState to null so it doesn't get stuck in startup recovery
      try {
        final t = await trackCache.getTrack(trackId);
        if (t != null && t.downloadState == 'downloading') {
          t.downloadState = null;
          await trackCache.cacheTrack(t);
        }
      } catch (_) {}

      if (isDownload) {
        rethrow;
      }
      return null;
    } finally {
      _activeDownloads.remove(trackId);
    }
  }

  @override
  Future<void> deleteAudio(String trackId) async {
    if (kIsWeb) return;

    final trackCache = GetIt.I<TrackCacheService>();
    final track = await trackCache.getTrack(trackId);
    if (track != null) {
      track.downloadState = 'deleting';
      await trackCache.cacheTrack(track);
    }

    if (await _dir.exists()) {
      await for (final entity in _dir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.replaceAll(r'\', '/').split('/').last;
          final hlsIndex = name.indexOf('_hls');
          if (hlsIndex != -1) {
            final parsedTrackId = name.substring(0, hlsIndex);
            if (parsedTrackId == trackId) {
              try {
                await entity.delete(recursive: true);
              } catch (_) {}
            }
          }
        }
      }
    }

    for (final ext in ['mp3', 'm4a', 'aac', 'flac', 'wav']) {
      final file = File(_getFilePath(trackId, ext));
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      final dotIdx = file.path.lastIndexOf('.');
      if (dotIdx != -1) {
        final jsonFile = File('${file.path.substring(0, dotIdx)}.json');
        if (await jsonFile.exists()) {
          try {
            await jsonFile.delete();
          } catch (_) {}
        }
      }
    }

    if (track != null) {
      track.downloadState = null;
      track.localAudioPath = null;
      track.audioSizeBytes = 0;
      track.cachedHlsBitrate = null;
      track.cachedHlsVariantUrl = null;
      track.downloadedAudioPath = null;
      track.downloadedAudioSizeBytes = 0;
      track.downloadedHlsBitrate = null;
      track.downloadedHlsVariantUrl = null;
      track.isDownloaded = false;
      await trackCache.cacheTrack(track);
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
    if (isBulkDownloading) {
      if (kDebugMode) {
        debugPrint('[AudioCacheService] Skipping enforceMaxSize during bulk download');
      }
      return;
    }

    final List<CachedTrack> allTracks = await trackCache.getAllTracks();
    final Map<String, CachedTrack> tracksMap = {
      for (final t in allTracks) t.trackId: t
    };

    final protectSet = <String>{
      if (protectedTrackIds != null) ...protectedTrackIds,
      ..._activeDownloads,
    };

    // Dynamically retrieve player status from GetIt if registered, to protect currently playing, prefetching, and recently played tracks
    try {
      if (GetIt.instance.isRegistered<PlayerCubit>()) {
        final player = GetIt.instance<PlayerCubit>();
        final currentTrackId = player.state.track?.trackId;
        if (currentTrackId != null) {
          protectSet.add(currentTrackId);
        }
        final queue = player.state.queue;
        final currentIndex = player.state.currentIndex;
        if (queue.isNotEmpty && currentIndex >= 0) {
          if (currentIndex + 1 < queue.length) {
            protectSet.add(queue[currentIndex + 1].trackId);
          }
          if (currentIndex - 1 >= 0) {
            protectSet.add(queue[currentIndex - 1].trackId);
          }
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
          final hlsIndex = name.indexOf('_hls');
          if (hlsIndex != -1) {
            trackId = name.substring(0, hlsIndex);
          }
        } else if (entity is File) {
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex != -1) {
            trackId = name.substring(0, dotIndex);
          }
        }

        final normalizedEntityPath = entity.path.replaceAll(r'\', '/');
        if (trackId != null && !protectSet.contains(trackId) && !isPathInUse(normalizedEntityPath)) {
          bool isObsolete = false;
          final track = tracksMap[trackId];
          if (track == null || !track.isAvailableOffline) {
            isObsolete = true;
          } else {
            final normalizedLocalPath = track.localAudioPath?.replaceAll(r'\', '/') ?? '';
            final normalizedDownloadPath = track.downloadedAudioPath?.replaceAll(r'\', '/') ?? '';
            if (!normalizedLocalPath.contains(normalizedEntityPath) &&
                !normalizedDownloadPath.contains(normalizedEntityPath)) {
              isObsolete = true;
            }
          }

          if (isObsolete) {
            try {
              if (entity is Directory) {
                await entity.delete(recursive: true);
              } else {
                await entity.delete();
              }
              if (kDebugMode) {
                debugPrint('[AudioCacheService] Cleaned up obsolete/orphaned cache: ${entity.path}');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[AudioCacheService] Failed to delete obsolete/orphaned cache entity ${entity.path}: $e');
              }
            }
          }
        }
      }
    }

    // 2. Now calculate size of cached-only tracks and run LRU eviction if we exceed the limit
    final cacheTracks = allTracks.where((t) => t.localAudioPath != null).toList();
    final currentCacheSize = cacheTracks.fold<int>(0, (sum, t) => sum + t.audioSizeBytes);
    if (currentCacheSize <= maxCacheSizeBytes) return;

    // Sort by lastPlayedAt ascending (oldest first). If lastPlayedAt is null, use cachedAt.
    cacheTracks.sort((a, b) {
      final timeA = a.lastPlayedAt ?? a.cachedAt;
      final timeB = b.lastPlayedAt ?? b.cachedAt;
      return timeA.compareTo(timeB);
    });

    int freedBytes = 0;
    final targetFree = currentCacheSize - maxCacheSizeBytes;

    for (final track in cacheTracks) {
      if (freedBytes >= targetFree) break;

      // Skip protected tracks
      if (protectSet.contains(track.trackId)) {
        if (kDebugMode) {
          debugPrint('[AudioCacheService] Skipping eviction of protected track ${track.trackId} ("${track.title}")');
        }
        continue;
      }

      if (track.localAudioPath != null) {
        final absolutePath = track.localAudioPath!;
        if (isPathInUse(absolutePath)) {
          if (kDebugMode) {
            debugPrint('[AudioCacheService] Skipping eviction of track ${track.trackId} because its path is in use');
          }
          continue;
        }

        final trackSize = track.audioSizeBytes > 0 ? track.audioSizeBytes : 0;
        
        // Delete only the cached file/folder from disk, preserving downloaded files
        if (absolutePath.contains('_hls')) {
          final dir = Directory(absolutePath).parent;
          if (await dir.exists()) {
            try {
              await dir.delete(recursive: true);
            } catch (_) {}
          }
        } else {
          final file = File(absolutePath);
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (_) {}
          }
          final dotIdx = file.path.lastIndexOf('.');
          if (dotIdx != -1) {
            final jsonFile = File('${file.path.substring(0, dotIdx)}.json');
            if (await jsonFile.exists()) {
              try {
                await jsonFile.delete();
              } catch (_) {}
            }
          }
        }

        freedBytes += trackSize;
        track.localAudioPath = null;
        track.audioSizeBytes = 0;
        track.cachedHlsBitrate = null;
        track.cachedHlsVariantUrl = null;
        await trackCache.cacheTrack(track);
        if (kDebugMode) {
          debugPrint('[AudioCacheService] Evicted cache-only version of track ${track.trackId} ("${track.title}") to free $trackSize bytes');
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

  @override
  Future<void> recoverIncompleteOperations(TrackCacheService trackCache) async {
    if (kIsWeb) return;
    try {
      final List<CachedTrack> allTracks = await trackCache.getAllTracks();
      for (final track in allTracks) {
        if (track.downloadState == 'downloading') {
          if (kDebugMode) {
            debugPrint('[AudioCacheService] Recovering incomplete download for track ${track.trackId}');
          }
          await deleteAudio(track.trackId);
          track.downloadState = null;
          await trackCache.cacheTrack(track);
        } else if (track.downloadState == 'deleting') {
          if (kDebugMode) {
            debugPrint('[AudioCacheService] Recovering incomplete deletion for track ${track.trackId}');
          }
          await deleteAudio(track.trackId);
          track.downloadState = null;
          await trackCache.cacheTrack(track);
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> reconcileDiskUsage({required TrackCacheService trackCache}) async {
    if (kIsWeb) return;
    try {
      final List<CachedTrack> allTracks = await trackCache.getAllTracks();
      for (final track in allTracks) {
        // Reconcile Cached Version
        if (track.localAudioPath != null) {
          final path = track.localAudioPath!;
          final isHls = path.contains('_hls');
          int actualSize = 0;
          bool exists = false;
          try {
            if (isHls) {
              final dir = Directory(path).parent;
              if (await dir.exists() && await _verifyHlsCacheComplete(dir.path)) {
                exists = true;
                actualSize = await _dirSizeBytes(dir);
              }
            } else {
              final file = File(path);
              if (await file.exists() && await file.length() > 0) {
                exists = true;
                actualSize = await file.length();
              }
            }
          } catch (_) {}

          if (!exists) {
            track.localAudioPath = null;
            track.audioSizeBytes = 0;
            track.cachedHlsBitrate = null;
            track.cachedHlsVariantUrl = null;
            await trackCache.cacheTrack(track);
          } else if (track.audioSizeBytes != actualSize) {
            track.audioSizeBytes = actualSize;
            await trackCache.cacheTrack(track);
          }
        }

        // Reconcile Downloaded Version
        if (track.downloadedAudioPath != null) {
          final path = track.downloadedAudioPath!;
          final isHls = path.contains('_hls');
          int actualSize = 0;
          bool exists = false;
          try {
            if (isHls) {
              final dir = Directory(path).parent;
              if (await dir.exists() && await _verifyHlsCacheComplete(dir.path)) {
                exists = true;
                actualSize = await _dirSizeBytes(dir);
              }
            } else {
              final file = File(path);
              if (await file.exists() && await file.length() > 0) {
                exists = true;
                actualSize = await file.length();
              }
            }
          } catch (_) {}

          if (!exists) {
            track.downloadedAudioPath = null;
            track.downloadedAudioSizeBytes = 0;
            track.downloadedHlsBitrate = null;
            track.downloadedHlsVariantUrl = null;
            track.isDownloaded = false;
            await trackCache.cacheTrack(track);
          } else if (track.downloadedAudioSizeBytes != actualSize) {
            track.downloadedAudioSizeBytes = actualSize;
            await trackCache.cacheTrack(track);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> rebuildHiveFromSidecars(TrackCacheService trackCache) async {
    if (kIsWeb || !await _dir.exists()) return;
    try {
      final tracks = await trackCache.getAllTracks();
      if (tracks.isNotEmpty) return;

      if (kDebugMode) {
        debugPrint('[AudioCacheService] Hive database is empty. Rebuilding from sidecar metadata files...');
      }

      await for (final entity in _dir.list(recursive: false, followLinks: false)) {
        File? jsonFile;
        if (entity is Directory) {
          jsonFile = File('${entity.path}/track.json');
        } else if (entity is File && entity.path.endsWith('.json')) {
          jsonFile = entity;
        }

        if (jsonFile != null && await jsonFile.exists()) {
          try {
            final content = await jsonFile.readAsString();
            final map = jsonDecode(content) as Map<String, dynamic>;
            final track = CachedTrack()
              ..trackId = map['trackId'] as String
              ..title = map['title'] as String
              ..artistName = map['artistName'] as String
              ..albumTitle = map['albumTitle'] as String?
              ..albumId = map['albumId'] as String?
              ..albumCoverUrl = map['albumCoverUrl'] as String?
              ..durationSeconds = map['durationSeconds'] as int
              ..isExplicit = map['isExplicit'] as bool? ?? false
              ..audioSizeBytes = map['audioSizeBytes'] as int? ?? 0
              ..cachedHlsBitrate = map['cachedHlsBitrate'] as int?
              ..cachedHlsVariantUrl = map['cachedHlsVariantUrl'] as String?
              ..downloadedAudioPath = map['downloadedAudioPath'] as String?
              ..downloadedAudioSizeBytes = map['downloadedAudioSizeBytes'] as int? ?? 0
              ..downloadedHlsBitrate = map['downloadedHlsBitrate'] as int?
              ..downloadedHlsVariantUrl = map['downloadedHlsVariantUrl'] as String?
              ..isDownloaded = map['isDownloaded'] as bool? ?? false
              ..sourceProvider = map['sourceProvider'] as String? ?? 'musee'
              ..cachedAt = DateTime.now();

            if (entity is Directory) {
              final playlistPath = '${entity.path}/index.m3u8';
              if (track.isDownloaded) {
                track.downloadedAudioPath = playlistPath;
                track.downloadedAudioSizeBytes = track.audioSizeBytes;
                track.downloadedHlsBitrate = track.cachedHlsBitrate;
                track.downloadedHlsVariantUrl = track.cachedHlsVariantUrl;
                track.audioSizeBytes = 0;
                track.cachedHlsBitrate = null;
                track.cachedHlsVariantUrl = null;
              } else {
                track.localAudioPath = playlistPath;
              }
            } else {
              for (final ext in ['mp3', 'm4a', 'aac', 'flac', 'wav']) {
                final audioFile = File('${_dir.path}/${track.trackId}.$ext');
                if (await audioFile.exists()) {
                  if (track.isDownloaded) {
                    track.downloadedAudioPath = audioFile.path;
                    track.downloadedAudioSizeBytes = track.audioSizeBytes;
                    track.audioSizeBytes = 0;
                  } else {
                    track.localAudioPath = audioFile.path;
                  }
                  break;
                }
              }
            }

            if (track.localAudioPath != null || track.downloadedAudioPath != null) {
              await trackCache.cacheTrack(track);
              if (kDebugMode) {
                debugPrint('[AudioCacheService] Rebuilt track entry for ${track.trackId} ("${track.title}")');
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
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
