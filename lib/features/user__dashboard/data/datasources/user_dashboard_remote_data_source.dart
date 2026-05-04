import 'package:dio/dio.dart' as dio;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class DashboardItemDTO extends DashboardItem {
  const DashboardItemDTO({
    required super.id,
    required super.title,
    super.coverUrl,
    super.duration,
    super.playCount,
    super.likesCount,
    super.popularityScore,
    super.totalTracks,
    required super.artists,
    required super.type,
    super.trackId,
    super.albumId,
    super.playlistId,
  });

  factory DashboardItemDTO.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'album';
    final type = switch (typeStr) {
      'track' => DashboardItemType.track,
      'playlist' => DashboardItemType.playlist,
      _ => DashboardItemType.album,
    };

    // Preserve source-specific IDs so navigation and API calls remain stable.
    final trackId = json['track_id']?.toString();
    final albumId = json['album_id']?.toString();
    final playlistId = json['playlist_id']?.toString();
    final id = switch (type) {
      DashboardItemType.track => trackId ?? json['id']?.toString() ?? '',
      DashboardItemType.playlist =>
        playlistId ?? albumId ?? json['id']?.toString() ?? '',
      DashboardItemType.album => albumId ?? json['id']?.toString() ?? '',
    };

    return DashboardItemDTO(
      id: id,
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      playCount: (json['play_count'] as num?)?.toInt(),
      likesCount: (json['likes_count'] as num?)?.toInt(),
      popularityScore: (json['popularity_score'] as num?)?.toDouble(),
      totalTracks: (json['total_tracks'] as num?)?.toInt(),
      artists: (json['artists'] as List<dynamic>? ?? const [])
          .map(
            (e) => DashboardArtistDTO.fromJson(
              Map<String, dynamic>.from(e as Map),
            ).toDomain(),
          )
          .toList(),
      type: type,
      trackId: trackId,
      albumId: albumId,
      playlistId: playlistId,
    );
  }
}

class DashboardArtistDTO {
  final String artistId;
  final String name;
  final String? avatarUrl;

  DashboardArtistDTO({
    required this.artistId,
    required this.name,
    required this.avatarUrl,
  });

  factory DashboardArtistDTO.fromJson(Map<String, dynamic> json) {
    return DashboardArtistDTO(
      artistId: json['artist_id'] as String,
      name: json['name'] as String? ?? 'Artist',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  DashboardArtist toDomain() =>
      DashboardArtist(artistId: artistId, name: name, avatarUrl: avatarUrl);
}

class PagedDashboardItemsDTO extends PagedDashboardItems {
  const PagedDashboardItemsDTO({
    required super.items,
    required super.total,
    required super.page,
    required super.limit,
  });

  factory PagedDashboardItemsDTO.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map(
          (e) => DashboardItemDTO.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return PagedDashboardItemsDTO(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? items.length,
    );
  }
}

abstract interface class UserDashboardRemoteDataSource {
  Future<PagedDashboardItemsDTO> getMadeForYou({int page = 0, int limit = 20});
  Future<PagedDashboardItemsDTO> getTrending({int page = 0, int limit = 20});
}

class UserDashboardRemoteDataSourceImpl
    implements UserDashboardRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient _supabase;
  final String basePath;

  UserDashboardRemoteDataSourceImpl(this._dio, this._supabase)
    : basePath = '${AppSecrets.backendUrl}/api/user/dashboard';

  Map<String, String> _authHeader() {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for user API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<PagedDashboardItemsDTO> getMadeForYou({
    int page = 0,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '$basePath/made-for-you',
      queryParameters: {'page': page, 'limit': limit},
      options: dio.Options(headers: _authHeader()),
    );
    return PagedDashboardItemsDTO.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  @override
  Future<PagedDashboardItemsDTO> getTrending({
    int page = 0,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '$basePath/trending',
      queryParameters: {'page': page, 'limit': limit},
      options: dio.Options(headers: _authHeader()),
    );
    return PagedDashboardItemsDTO.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }
}
