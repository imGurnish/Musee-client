// Import Remote Data Source for Jio Saavn API calls

import 'package:dio/dio.dart';
import 'package:musee/core/error/app_logger.dart';
import 'package:musee/features/admin_import/data/models/import_models.dart';

class AdminImportRemoteDataSource {
  final Dio _dio;
  final String baseUrl = '/api/admin/import';

  AdminImportRemoteDataSource({required Dio dio}) : _dio = dio;

  /// Search for tracks on Jio Saavn
  Future<List<JioTrackModel>> searchTracks(String query, {int limit = 10}) async {
    try {
      appLogger.info('[ImportDS] Searching tracks: $query');

      final response = await _dio.get(
        '$baseUrl/search/tracks',
        queryParameters: {
          'query': query,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final tracks = (data['tracks'] as List?)
                ?.map((t) => JioTrackModel.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [];

        appLogger.info('[ImportDS] Found ${tracks.length} tracks');
        return tracks;
      }

      throw Exception('Failed to search tracks: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Search tracks failed', error: e);
      rethrow;
    }
  }

  /// Get track details from Jio Saavn
  Future<JioTrackModel> getTrackDetails(String trackId) async {
    try {
      appLogger.info('[ImportDS] Fetching track: $trackId');

      final response = await _dio.get('$baseUrl/track/$trackId');

      if (response.statusCode == 200) {
        final track = JioTrackModel.fromJson(response.data as Map<String, dynamic>);
        appLogger.info('[ImportDS] Retrieved track: ${track.title}');
        return track;
      }

      throw Exception('Failed to get track: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Get track failed', error: e);
      rethrow;
    }
  }

  /// Search for albums on Jio Saavn
  Future<List<JioAlbumModel>> searchAlbums(String query, {int limit = 10}) async {
    try {
      appLogger.info('[ImportDS] Searching albums: $query');

      final response = await _dio.get(
        '$baseUrl/search/albums',
        queryParameters: {
          'query': query,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final albums = (data['albums'] as List?)
                ?.map((a) => JioAlbumModel.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [];

        appLogger.info('[ImportDS] Found ${albums.length} albums');
        return albums;
      }

      throw Exception('Failed to search albums: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Search albums failed', error: e);
      rethrow;
    }
  }

  /// Get album details from Jio Saavn with all tracks
  Future<JioAlbumModel> getAlbumDetails(String albumId) async {
    try {
      appLogger.info('[ImportDS] Fetching album: $albumId');

      final response = await _dio.get('$baseUrl/album/$albumId');

      if (response.statusCode == 200) {
        final album = JioAlbumModel.fromJson(response.data as Map<String, dynamic>);
        appLogger.info('[ImportDS] Retrieved album: ${album.title} with ${album.tracks.length} tracks');
        return album;
      }

      throw Exception('Failed to get album: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Get album failed', error: e);
      rethrow;
    }
  }

  /// Search for artists on Jio Saavn
  Future<List<JioArtistModel>> searchArtists(String query, {int limit = 10}) async {
    try {
      appLogger.info('[ImportDS] Searching artists: $query');

      final response = await _dio.get(
        '$baseUrl/search/artists',
        queryParameters: {
          'query': query,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final artists = (data['artists'] as List?)
                ?.map((a) => JioArtistModel.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [];

        appLogger.info('[ImportDS] Found ${artists.length} artists');
        return artists;
      }

      throw Exception('Failed to search artists: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Search artists failed', error: e);
      rethrow;
    }
  }

  /// Get artist details from Jio Saavn
  Future<JioArtistModel> getArtistDetails(String artistId) async {
    try {
      appLogger.info('[ImportDS] Fetching artist: $artistId');

      final response = await _dio.get('$baseUrl/artist/$artistId');

      if (response.statusCode == 200) {
        final artist = JioArtistModel.fromJson(response.data as Map<String, dynamic>);
        appLogger.info('[ImportDS] Retrieved artist: ${artist.name}');
        return artist;
      }

      throw Exception('Failed to get artist: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Get artist failed', error: e);
      rethrow;
    }
  }

  /// Import complete album with all tracks
  Future<Map<String, dynamic>> importAlbum({
    required String jioSaavnAlbumId,
    required String artistName,
    String? artistBio,
    String? regionId,
    bool isPublished = false,
    bool dryRun = false,
  }) async {
    try {
      appLogger.info(
        '[ImportDS] Starting album import: $jioSaavnAlbumId'
        '${dryRun ? ' (DRY RUN)' : ''}'
      );

      final requestBody = {
        'jioSaavnAlbumId': jioSaavnAlbumId,
        'artistName': artistName,
        'artistBio': artistBio,
        'regionId': regionId,
        'isPublished': isPublished,
        'dryRun': dryRun,
      };

      final response = await _dio.post(
        '$baseUrl/album-complete',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final result = response.data as Map<String, dynamic>;

        appLogger.info(
          '[ImportDS] Album import ${dryRun ? 'dry-run' : 'completed'}: '
          'Session ${result['sessionId']} - '
          '${result['tracksImported']} tracks imported'
        );

        return result;
      }

      throw Exception('Failed to import album: ${response.statusCode}');
    } on DioException catch (e) {
      appLogger.error('[ImportDS] Album import failed', error: e);
      rethrow;
    }
  }
}
