import 'package:dio/dio.dart';
import 'package:musee/core/error/exceptions.dart';
import 'package:musee/features/admin_playlists/data/models/playlist_model.dart';
import 'package:musee/features/admin_playlists/data/models/track_search_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AdminPlaylistsRemoteDataSource {
  Future<PlaylistModel> getPlaylistDetails(String playlistId);

  Future<(List<TrackSearchModel>, int)> searchTracks({
    int page = 0,
    int limit = 20,
    String? query,
  });

  Future<PlaylistModel> addTrackToPlaylist({
    required String playlistId,
    required String trackId,
  });

  Future<void> removeTrackFromPlaylist({
    required String playlistId,
    required String trackId,
  });
}

class AdminPlaylistsRemoteDataSourceImpl implements AdminPlaylistsRemoteDataSource {
  final Dio dio;
  final String baseUrl;
  final SupabaseClient supabase;

  AdminPlaylistsRemoteDataSourceImpl({
    required this.dio,
    required this.baseUrl,
    required this.supabase,
  });

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ServerException(
        'Missing Supabase access token for admin API request',
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<PlaylistModel> getPlaylistDetails(String playlistId) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/admin/playlists/$playlistId',
        options: Options(headers: _authHeader()),
      );
      if (response.statusCode != 200) {
        throw ServerException(
          response.data['error']?.toString() ?? 'Failed to fetch playlist',
        );
      }
      return PlaylistModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error']?.toString() ?? e.message ?? 'Network error',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<(List<TrackSearchModel>, int)> searchTracks({
    int page = 0,
    int limit = 20,
    String? query,
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/admin/tracks',
        options: Options(headers: _authHeader()),
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      );
      if (response.statusCode != 200) {
        throw ServerException(
          response.data['error']?.toString() ?? 'Failed to search tracks',
        );
      }
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List? ?? [])
          .map((e) => TrackSearchModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = data['total'] as int? ?? 0;
      return (items, total);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error']?.toString() ?? e.message ?? 'Network error',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PlaylistModel> addTrackToPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/admin/playlists/$playlistId/tracks',
        options: Options(headers: _authHeader()),
        data: {'track_id': trackId},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          response.data['error']?.toString() ?? 'Failed to add track',
        );
      }
      return PlaylistModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error']?.toString() ?? e.message ?? 'Network error',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> removeTrackFromPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    try {
      final response = await dio.delete(
        '$baseUrl/api/admin/playlists/$playlistId/tracks/$trackId',
        options: Options(headers: _authHeader()),
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw ServerException(
          response.data?['error']?.toString() ?? 'Failed to remove track',
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error']?.toString() ?? e.message ?? 'Network error',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
