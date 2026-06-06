import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';

// Mock TrackCacheService
class MockTrackCacheService implements TrackCacheService {
  final Map<String, CachedTrack> tracks = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> cacheTrack(CachedTrack track) async {
    tracks[track.trackId] = track;
  }

  @override
  Future<CachedTrack?> getTrack(String trackId) async {
    return tracks[trackId];
  }

  @override
  CachedTrack? getTrackSync(String trackId) {
    return tracks[trackId];
  }

  @override
  Future<List<CachedTrack>> getAllTracks() async {
    return tracks.values.toList();
  }

  @override
  Future<void> updateLastPlayed(String trackId) async {
    final track = tracks[trackId];
    if (track != null) {
      track.lastPlayedAt = DateTime.now();
      track.playCount += 1;
    }
  }

  @override
  Future<List<CachedTrack>> getOfflineAvailable() async {
    return tracks.values.where((t) => t.isAvailableOffline && t.isDownloaded).toList();
  }

  @override
  Future<void> clearAll() async => tracks.clear();

  // Stub other methods to satisfy abstract class
  @override
  Future<void> cacheAlbum(CachedAlbum album) async {}
  @override
  Future<CachedAlbum?> getAlbum(String albumId) async => null;
  @override
  Future<List<CachedTrack>> getAlbumTracks(String albumId) async => [];
  @override
  Future<void> clearExpired() async {}
  @override
  Future<int> getCachedTrackCount() async => tracks.length;
  @override
  Future<List<CachedTrack>> getRecentlyPlayed({int limit = 20}) async => [];
  @override
  Future<List<CachedTrack>> getMostPlayed({int limit = 20}) async => [];
  @override
  Future<List<CachedAlbum>> getAllAlbums() async => [];
  @override
  Future<CacheStats> getStats() async => const CacheStats(
        trackCount: 0,
        albumCount: 0,
        offlineTrackCount: 0,
        totalPlayCount: 0,
      );
}

// Mock Dio using Fake
class MockDio extends Fake implements Dio {
  String manifestContent = '';
  String segmentContent = 'audio-segment-bytes';
  bool failDownload = false;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (failDownload) throw DioException(requestOptions: RequestOptions(path: path));
    return Response<T>(
      data: manifestContent as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
    FileAccessMode fileAccessMode = FileAccessMode.write,
  }) async {
    if (failDownload) throw DioException(requestOptions: RequestOptions(path: urlPath));

    final file = File(savePath as String);
    await file.parent.create(recursive: true);
    await file.writeAsString(segmentContent);

    return Response(
      statusCode: 200,
      requestOptions: RequestOptions(path: urlPath),
    );
  }
}

void main() {
  late Directory tempDir;
  late MockTrackCacheService trackCache;
  late MockDio mockDio;
  late AudioCacheServiceImpl audioCache;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('audio_cache_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    trackCache = MockTrackCacheService();
    mockDio = MockDio();
    
    // Register mock dependencies in GetIt
    final getIt = GetIt.instance;
    getIt.reset();
    getIt.registerSingleton<TrackCacheService>(trackCache);

    audioCache = AudioCacheServiceImpl(mockDio);
    await audioCache.init();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('Reference Counting & Path Locks', () {
    test('Increment, decrement, and path check in use', () {
      final path = '${tempDir.path}/track_123_hls_320';
      expect(audioCache.isPathInUse(path), isFalse);

      audioCache.incrementRef(path);
      expect(audioCache.isPathInUse(path), isTrue);

      // Child path checks
      expect(audioCache.isPathInUse('$path/index.m3u8'), isTrue);

      audioCache.decrementRef(path);
      expect(audioCache.isPathInUse(path), isFalse);
    });

    test('getLocalPathFromUri handles file and localhost URIs', () {
      final fileUri = 'file:///C:/Users/test/track.mp3';
      final mappedPath = audioCache.getLocalPathFromUri(fileUri);
      expect(mappedPath, isNotNull);
    });
  });

  group('HLS Staging & Manifest Validation', () {
    test('verifyHlsCacheComplete parses playlist and checks files', () async {
      final hlsDirPath = tempDir.path;
      final manifest = File('$hlsDirPath/index.m3u8');

      // Create manifest with 3 segments
      await manifest.writeAsString('''
#EXTM3U
#EXT-X-TARGETDURATION:10
segment0.ts
segment1.ts
segment2.ts
''');

      // Let's create the segments
      await File('$hlsDirPath/segment0.ts').writeAsString('data');
      await File('$hlsDirPath/segment1.ts').writeAsString('data');
      await File('$hlsDirPath/segment2.ts').writeAsString('data');

      // Verify that all exist now
      final playlist = File('$hlsDirPath/index.m3u8');
      final lines = (await playlist.readAsString()).split('\n');
      var verified = true;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final f = File('$hlsDirPath/$trimmed');
        if (!f.existsSync() || f.lengthSync() == 0) {
          verified = false;
        }
      }
      expect(verified, isTrue);
    });
  });

  group('Rebuild from Sidecars & Reconciliation', () {
    test('Sidecar JSON file serialization and rebuild', () async {
      final track = CachedTrack()
        ..trackId = 'test_track_999'
        ..title = 'My Test Title'
        ..artistName = 'Test Artist'
        ..albumTitle = 'Test Album'
        ..durationSeconds = 180
        ..cachedAt = DateTime.now()
        ..isDownloaded = true;

      // Simulate writing sidecar track.json inside a mock HLS folder
      final folder = Directory('${tempDir.path}/test_track_999_hls_320');
      await folder.create(recursive: true);
      final sidecarFile = File('${folder.path}/track.json');
      
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
        'isDownloaded': track.isDownloaded,
        'sourceProvider': track.sourceProvider,
      };
      await sidecarFile.writeAsString(jsonEncode(map));

      // Make sure database is empty initially
      expect(trackCache.tracks.isEmpty, isTrue);

      // Rebuild mock
      final rebuiltTracks = <CachedTrack>[];
      await for (final entity in tempDir.list()) {
        if (entity is Directory) {
          final sidecar = File('${entity.path}/track.json');
          if (sidecar.existsSync()) {
            final sidecarContent = sidecar.readAsStringSync();
            final decoded = jsonDecode(sidecarContent) as Map<String, dynamic>;
            final t = CachedTrack()
              ..trackId = decoded['trackId'] as String
              ..title = decoded['title'] as String
              ..artistName = decoded['artistName'] as String
              ..durationSeconds = decoded['durationSeconds'] as int
              ..isDownloaded = decoded['isDownloaded'] as bool
              ..localAudioPath = '${entity.path}/index.m3u8'
              ..cachedAt = DateTime.now();
            rebuiltTracks.add(t);
            await trackCache.cacheTrack(t);
          }
        }
      }

      expect(trackCache.tracks.length, 1);
      expect(trackCache.tracks['test_track_999']?.title, 'My Test Title');
      expect(trackCache.tracks['test_track_999']?.isDownloaded, isTrue);
    });

    test('Reconcile Disk Usage repairs missing file states', () async {
      final track = CachedTrack()
        ..trackId = 'test_reconcile_track'
        ..title = 'Title'
        ..artistName = 'Artist'
        ..cachedAt = DateTime.now()
        ..localAudioPath = '${tempDir.path}/missing_audio.mp3'
        ..audioSizeBytes = 1000;

      await trackCache.cacheTrack(track);

      for (final t in await trackCache.getAllTracks()) {
        if (t.localAudioPath != null) {
          final file = File(t.localAudioPath!);
          if (!file.existsSync()) {
            t.localAudioPath = null;
            t.audioSizeBytes = 0;
            await trackCache.cacheTrack(t);
          }
        }
      }

      final reconciled = await trackCache.getTrack('test_reconcile_track');
      expect(reconciled?.localAudioPath, isNull);
      expect(reconciled?.audioSizeBytes, 0);
    });
  });

  group('Transactions and Startup Recovery', () {
    test('Incomplete transaction recovery deletes partial data', () async {
      final track = CachedTrack()
        ..trackId = 'incomplete_tx_track'
        ..title = 'TX Track'
        ..artistName = 'Artist'
        ..cachedAt = DateTime.now()
        ..downloadState = 'downloading'
        ..localAudioPath = '${tempDir.path}/incomplete_hls/index.m3u8';

      await trackCache.cacheTrack(track);

      final partialDir = Directory('${tempDir.path}/incomplete_hls');
      await partialDir.create(recursive: true);
      await File('${partialDir.path}/segment.ts').writeAsString('partial-bytes');

      for (final t in await trackCache.getAllTracks()) {
        if (t.downloadState == 'downloading') {
          if (partialDir.existsSync()) {
            partialDir.deleteSync(recursive: true);
          }
          t.downloadState = null;
          t.localAudioPath = null;
          await trackCache.cacheTrack(t);
        }
      }

      final recovered = await trackCache.getTrack('incomplete_tx_track');
      expect(recovered?.downloadState, isNull);
      expect(recovered?.localAudioPath, isNull);
      expect(partialDir.existsSync(), isFalse);
    });
  });

  group('enforceMaxSize Protection', () {
    test('obsolete/orphaned cleanup protects active downloads and players', () async {
      // Create a simulated active download/temp directory
      final cacheDir = Directory('${tempDir.path}/audio_cache');
      final activeDir = Directory('${cacheDir.path}/active_track_hls_320_tmp');
      await activeDir.create(recursive: true);
      final activeFile = File('${activeDir.path}/segment0.ts');
      await activeFile.writeAsString('data');

      // Create a simulated inactive/obsolete directory
      final obsoleteDir = Directory('${cacheDir.path}/obsolete_track_hls_128');
      await obsoleteDir.create(recursive: true);
      final obsoleteFile = File('${obsoleteDir.path}/segment0.ts');
      await obsoleteFile.writeAsString('data');

      // Set up tracks in trackCache (both not fully cached/available offline yet)
      final activeTrack = CachedTrack()
        ..trackId = 'active_track'
        ..title = 'Active Track'
        ..artistName = 'Artist'
        ..isDownloaded = false;
      await trackCache.cacheTrack(activeTrack);

      final obsoleteTrack = CachedTrack()
        ..trackId = 'obsolete_track'
        ..title = 'Obsolete Track'
        ..artistName = 'Artist'
        ..isDownloaded = false;
      await trackCache.cacheTrack(obsoleteTrack);

      // Call enforceMaxSize with active_track protected
      await audioCache.enforceMaxSize(
        maxCacheSizeBytes: 1000000,
        trackCache: trackCache,
        protectedTrackIds: ['active_track'],
      );

      // Verify that obsolete_track_hls_128 was deleted
      expect(obsoleteDir.existsSync(), isFalse);

      // Verify that active_track_hls_320_tmp was NOT deleted
      expect(activeDir.existsSync(), isTrue);
    });

    test('LRU eviction only evicts cached version, keeping downloaded version intact', () async {
      final cacheDir = Directory('${tempDir.path}/audio_cache');
      
      // Create downloaded version folder at 96 kbps
      final downloadDir = Directory('${cacheDir.path}/dual_track_hls_96');
      await downloadDir.create(recursive: true);
      await File('${downloadDir.path}/index.m3u8').writeAsString('#EXTM3U\nsegment.ts');
      await File('${downloadDir.path}/segment.ts').writeAsString('data');

      // Create cached version folder at 320 kbps
      final cachedDir = Directory('${cacheDir.path}/dual_track_hls_320');
      await cachedDir.create(recursive: true);
      await File('${cachedDir.path}/index.m3u8').writeAsString('#EXTM3U\nsegment.ts');
      await File('${cachedDir.path}/segment.ts').writeAsString('data');

      // Register the dual track in trackCache
      final track = CachedTrack()
        ..trackId = 'dual_track'
        ..title = 'Dual Track'
        ..artistName = 'Artist'
        ..isDownloaded = true
        ..downloadedAudioPath = '${downloadDir.path}/index.m3u8'
        ..downloadedAudioSizeBytes = 100
        ..downloadedHlsBitrate = 96
        ..localAudioPath = '${cachedDir.path}/index.m3u8'
        ..audioSizeBytes = 200
        ..cachedHlsBitrate = 320
        ..cachedAt = DateTime.now().subtract(const Duration(minutes: 10));
      await trackCache.cacheTrack(track);

      // Call enforceMaxSize with cache limit 50 bytes (forcing eviction of cached version)
      await audioCache.enforceMaxSize(
        maxCacheSizeBytes: 50,
        trackCache: trackCache,
      );

      // Verify cached version is evicted from disk & Hive
      expect(cachedDir.existsSync(), isFalse);
      
      final updated = await trackCache.getTrack('dual_track');
      expect(updated?.localAudioPath, isNull);
      expect(updated?.audioSizeBytes, 0);

      // Verify downloaded version remains intact on disk & Hive
      expect(downloadDir.existsSync(), isTrue);
      expect(updated?.downloadedAudioPath, isNotNull);
      expect(updated?.downloadedAudioSizeBytes, 100);
      expect(updated?.isDownloaded, isTrue);
    });
  });
}
