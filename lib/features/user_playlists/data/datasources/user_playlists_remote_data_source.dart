import 'package:dio/dio.dart' as dio;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class UserPlaylistDetailDTO {
  final String playlistId;
  final String name;
  final String? coverUrl;
  final String? description;
  final List<UserPlaylistArtistDTO> artists;
  final List<UserPlaylistTrackDTO> tracks;
  final bool isPublic;
  final bool isCollaborative;
  final List<UserPlaylistArtistDTO> collaborators;
  final int totalTracks;
  final int totalDuration;
  final String? createdAt;

  UserPlaylistDetailDTO({
    required this.playlistId,
    required this.name,
    required this.coverUrl,
    required this.description,
    required this.artists,
    required this.tracks,
    required this.isPublic,
    required this.isCollaborative,
    required this.collaborators,
    required this.totalTracks,
    required this.totalDuration,
    required this.createdAt,
  });

  factory UserPlaylistDetailDTO.fromJson(Map<String, dynamic> json) {
    return UserPlaylistDetailDTO(
      playlistId: json['playlist_id'] as String,
      name: json['name'] as String,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      artists: (json['artists'] as List<dynamic>? ?? const [])
          .map((e) => UserPlaylistArtistDTO.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      tracks: (json['tracks'] as List<dynamic>? ?? const [])
          .map((e) => UserPlaylistTrackDTO.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isPublic: (json['is_public'] ?? false) as bool,
      isCollaborative: (json['is_collaborative'] ?? false) as bool,
      collaborators: (json['collaborators'] as List<dynamic>? ?? const [])
          .map((e) => UserPlaylistArtistDTO.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalTracks: (json['total_tracks'] ?? 0) as int,
      totalDuration: (json['duration'] ?? 0) as int,
      createdAt: json['created_at'] as String?,
    );
  }
}

class UserPlaylistArtistDTO {
  final String artistId;
  final String? name;
  final String? avatarUrl;

  UserPlaylistArtistDTO({
    required this.artistId,
    this.name,
    this.avatarUrl,
  });

  factory UserPlaylistArtistDTO.fromJson(Map<String, dynamic> json) {
    return UserPlaylistArtistDTO(
      artistId: json['artist_id'] as String? ?? json['creator_id'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class UserPlaylistTrackDTO {
  final String trackId;
  final String title;
  final int duration;
  final bool isExplicit;
  final List<UserPlaylistArtistDTO> artists;

  UserPlaylistTrackDTO({
    required this.trackId,
    required this.title,
    required this.duration,
    required this.isExplicit,
    required this.artists,
  });

  factory UserPlaylistTrackDTO.fromJson(Map<String, dynamic> json) {
    return UserPlaylistTrackDTO(
      trackId: json['track_id'] as String,
      title: json['title'] as String,
      duration: (json['duration'] ?? 0) as int,
      isExplicit: (json['is_explicit'] ?? false) as bool,
      artists: (json['artists'] as List<dynamic>? ?? const [])
          .map((e) => UserPlaylistArtistDTO.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

abstract interface class UserPlaylistsRemoteDataSource {
  Future<UserPlaylistDetailDTO> getPlaylist(String playlistId);
  Future<List<UserPlaylistDetailDTO>> getPlaylists();
  Future<UserPlaylistDetailDTO> createPlaylist({
    required String name,
    String? description,
    required bool isPublic,
    required bool isCollaborative,
    String? coverPath,
  });
  Future<UserPlaylistDetailDTO> joinCollaborativePlaylist(String playlistId);
  Future<UserPlaylistDetailDTO> addTrackToPlaylist(String playlistId, String trackId);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
}

class UserPlaylistsRemoteDataSourceImpl implements UserPlaylistsRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient supabase;
  final String basePath;

  UserPlaylistsRemoteDataSourceImpl(this._dio, this.supabase)
    : basePath = '${AppSecrets.backendUrl}/api/user/playlists';

  Future<Map<String, String>> _authHeader({bool allowRefresh = true}) async {
    var token = supabase.auth.currentSession?.accessToken;

    if ((token == null || token.isEmpty) && allowRefresh) {
      try {
        await supabase.auth.refreshSession();
      } catch (_) {
        // Ignore refresh errors; we still validate token below.
      }
      token = supabase.auth.currentSession?.accessToken;
    }

    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for user API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<UserPlaylistDetailDTO> getPlaylist(String playlistId) async {
    final encodedPlaylistId = Uri.encodeComponent(playlistId);
    final endpoint = '$basePath/$encodedPlaylistId';

    try {
      final res = await _dio.get(
        endpoint,
        options: dio.Options(headers: await _authHeader()),
      );
      return UserPlaylistDetailDTO.fromJson(Map<String, dynamic>.from(res.data));
    } on dio.DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        final retryRes = await _dio.get(
          endpoint,
          options: dio.Options(
            headers: await _authHeader(allowRefresh: true),
          ),
        );
        return UserPlaylistDetailDTO.fromJson(
          Map<String, dynamic>.from(retryRes.data),
        );
      }
      rethrow;
    }
  }

  @override
  Future<UserPlaylistDetailDTO> createPlaylist({
    required String name,
    String? description,
    required bool isPublic,
    required bool isCollaborative,
    String? coverPath,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      if (description != null) 'description': description,
      'is_public': isPublic.toString(),
      'is_collaborative': isCollaborative.toString(),
    };

    final formData = dio.FormData.fromMap(data);

    if (coverPath != null && coverPath.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'cover',
          await dio.MultipartFile.fromFile(coverPath),
        ),
      );
    }

    try {
      final res = await _dio.post(
        basePath,
        data: formData,
        options: dio.Options(headers: await _authHeader()),
      );
      return UserPlaylistDetailDTO.fromJson(Map<String, dynamic>.from(res.data));
    } on dio.DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<UserPlaylistDetailDTO> joinCollaborativePlaylist(String playlistId) async {
    final encodedPlaylistId = Uri.encodeComponent(playlistId);
    final endpoint = '$basePath/$encodedPlaylistId/collaborators/join';

    try {
      final res = await _dio.post(
        endpoint,
        options: dio.Options(headers: await _authHeader()),
      );
      return UserPlaylistDetailDTO.fromJson(Map<String, dynamic>.from(res.data));
    } on dio.DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<UserPlaylistDetailDTO> addTrackToPlaylist(String playlistId, String trackId) async {
    final encodedPlaylistId = Uri.encodeComponent(playlistId);
    final endpoint = '$basePath/$encodedPlaylistId/tracks';

    try {
      final res = await _dio.post(
        endpoint,
        data: {'track_id': trackId},
        options: dio.Options(headers: await _authHeader()),
      );
      return UserPlaylistDetailDTO.fromJson(Map<String, dynamic>.from(res.data));
    } on dio.DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final encodedPlaylistId = Uri.encodeComponent(playlistId);
    final encodedTrackId = Uri.encodeComponent(trackId);
    final endpoint = '$basePath/$encodedPlaylistId/tracks/$encodedTrackId';

    try {
      await _dio.delete(
        endpoint,
        options: dio.Options(headers: await _authHeader()),
      );
    } on dio.DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<List<UserPlaylistDetailDTO>> getPlaylists() async {
    try {
      final res = await _dio.get(
        basePath,
        options: dio.Options(headers: await _authHeader()),
      );
      final rawList = res.data['items'] as List<dynamic>? ?? const [];
      return rawList
          .map((e) => UserPlaylistDetailDTO.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on dio.DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Exception _handleDioException(dio.DioException e) {
    String message = 'An error occurred';
    if (e.response != null) {
      message = e.response?.data?['error'] ?? e.response?.data?['message'] ?? e.response?.statusMessage ?? message;
    }
    return Exception(message);
  }
}
