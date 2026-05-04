import 'package:dio/dio.dart' as dio;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class UserArtistDTO {
  final String artistId;
  final String? name;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final List<String> genres;
  final int? monthlyListeners;

  UserArtistDTO({
    required this.artistId,
    this.name,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.genres = const [],
    this.monthlyListeners,
  });

  factory UserArtistDTO.fromJson(Map<String, dynamic> json) {
    return UserArtistDTO(
      artistId: (json['artist_id'] ?? json['id']).toString(),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      bio: json['bio'] as String?,
      genres:
          (json['genres'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      monthlyListeners: (json['monthly_listeners'] as num?)?.toInt(),
    );
  }
}

class UserArtistAlbumDTO {
  final String albumId;
  final String title;
  final String? coverUrl;
  final String? releaseDate;

  UserArtistAlbumDTO({
    required this.albumId,
    required this.title,
    this.coverUrl,
    this.releaseDate,
  });

  factory UserArtistAlbumDTO.fromJson(Map<String, dynamic> json) {
    return UserArtistAlbumDTO(
      albumId: (json['album_id'] ?? json['id']).toString(),
      title: json['title']?.toString() ?? '',
      coverUrl: json['cover_url'] as String?,
      releaseDate: json['release_date'] as String?,
    );
  }
}

class UserArtistTrackArtistDTO {
  final String artistId;
  final String? name;

  UserArtistTrackArtistDTO({required this.artistId, this.name});

  factory UserArtistTrackArtistDTO.fromJson(Map<String, dynamic> json) {
    return UserArtistTrackArtistDTO(
      artistId: (json['artist_id'] ?? json['id']).toString(),
      name: json['name']?.toString(),
    );
  }
}

class UserArtistTrackDTO {
  final String trackId;
  final String title;
  final int? duration;
  final int? playCount;
  final int? likesCount;
  final String? albumId;
  final String? coverUrl;
  final List<UserArtistTrackArtistDTO> artists;

  UserArtistTrackDTO({
    required this.trackId,
    required this.title,
    this.duration,
    this.playCount,
    this.likesCount,
    this.albumId,
    this.coverUrl,
    this.artists = const [],
  });

  factory UserArtistTrackDTO.fromJson(Map<String, dynamic> json) {
    final artistsRaw = (json['artists'] as List?) ?? const [];
    return UserArtistTrackDTO(
      trackId: (json['track_id'] ?? json['id']).toString(),
      title: json['title']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt(),
      playCount: (json['play_count'] as num?)?.toInt(),
      likesCount: (json['likes_count'] as num?)?.toInt(),
      albumId: json['album_id']?.toString(),
      coverUrl:
          json['cover_url']?.toString() ??
          json['album_cover_url']?.toString() ??
          (json['album'] is Map
              ? (json['album']['cover_url']?.toString())
              : null),
      artists: artistsRaw
          .map(
            (e) => UserArtistTrackArtistDTO.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

abstract interface class UserArtistsRemoteDataSource {
  Future<UserArtistDTO> getArtist(String artistId);
  Future<List<UserArtistAlbumDTO>> getArtistAlbums(String artistId);
  Future<List<UserArtistTrackDTO>> getArtistTracks({
    required String artistId,
    String? artistName,
  });
}

class UserArtistsRemoteDataSourceImpl implements UserArtistsRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient supabase;
  final String baseArtistsPath;

  UserArtistsRemoteDataSourceImpl(this._dio, this.supabase)
    : baseArtistsPath = '${AppSecrets.backendUrl}/api/user/artists';

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for user API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<UserArtistDTO> getArtist(String artistId) async {
    final res = await _dio.get(
      '$baseArtistsPath/$artistId',
      options: dio.Options(headers: _authHeader()),
    );
    return UserArtistDTO.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<List<UserArtistAlbumDTO>> getArtistAlbums(String artistId) async {
    // Assumption: backend exposes this route; falls back to filtering albums list by artist_id if needed in future.
    final res = await _dio.get(
      '$baseArtistsPath/$artistId/albums',
      options: dio.Options(headers: _authHeader()),
    );
    final data = res.data;
    List<dynamic> items;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['items'] is List) {
        items = (map['items'] as List).cast<dynamic>();
      } else if (map['data'] is List) {
        items = (map['data'] as List).cast<dynamic>();
      } else {
        items = const [];
      }
    } else if (data is List) {
      items = data;
    } else {
      items = const [];
    }
    return items
        .map((e) => UserArtistAlbumDTO.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<UserArtistTrackDTO>> getArtistTracks({
    required String artistId,
    String? artistName,
  }) async {
    List<dynamic> items = const [];

    // Preferred route if backend exposes artist tracks directly.
    try {
      final res = await _dio.get(
        '$baseArtistsPath/$artistId/tracks',
        options: dio.Options(headers: _authHeader()),
      );
      items = _extractList(res.data);
    } catch (_) {
      // Fallback: query user tracks by artist name and filter by artist_id.
      final q = Uri.encodeQueryComponent(artistName ?? '');
      final url =
          '${AppSecrets.backendUrl}/api/user/tracks?page=0&limit=100&q=$q';
      final res = await _dio.get(
        url,
        options: dio.Options(headers: _authHeader()),
      );
      items = _extractList(res.data);
    }

    final parsed = items
        .map((e) => UserArtistTrackDTO.fromJson(Map<String, dynamic>.from(e)))
        .where((track) => track.trackId.isNotEmpty)
        .toList();

    final filtered = parsed.where((track) {
      if (track.artists.isEmpty) return true;
      return track.artists.any((a) => a.artistId == artistId);
    }).toList();

    filtered.sort((a, b) {
      final aPopularity = (a.playCount ?? 0) + (a.likesCount ?? 0);
      final bPopularity = (b.playCount ?? 0) + (b.likesCount ?? 0);
      return bPopularity.compareTo(aPopularity);
    });

    return filtered;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['items'] is List) return (map['items'] as List).cast<dynamic>();
      if (map['data'] is List) return (map['data'] as List).cast<dynamic>();
      return const [];
    }
    if (data is List) return data;
    return const [];
  }
}
