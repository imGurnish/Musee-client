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
}
