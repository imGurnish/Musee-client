import 'package:musee/features/admin_playlists/domain/entities/playlist.dart';

class PlaylistTrackModel extends PlaylistTrack {
  PlaylistTrackModel({
    required super.trackId,
    required super.title,
    required super.duration,
    required super.createdAt,
  });

  factory PlaylistTrackModel.fromJson(Map<String, dynamic> json) {
    return PlaylistTrackModel(
      trackId: json['track_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_id': trackId,
      'title': title,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PlaylistModel extends Playlist {
  PlaylistModel({
    required super.playlistId,
    required super.name,
    super.description,
    super.coverUrl,
    super.language,
    required super.isPublic,
    required super.likesCount,
    required super.totalTracks,
    super.duration,
    required super.createdAt,
    required super.updatedAt,
    super.tracks,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final directTracksData = json['tracks'] as List?;
    final nestedTracksData = json['playlist_tracks'] as List?;

    final tracks = (directTracksData ?? (nestedTracksData ?? []).map((e) => e is Map ? e['tracks'] : null).toList())
        .whereType<Map>()
        .map((e) => PlaylistTrackModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return PlaylistModel(
      playlistId: json['playlist_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      language: json['language_code'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      likesCount: json['likes_count'] as int? ?? 0,
      totalTracks: json['total_tracks'] as int? ?? 0,
      duration: json['duration'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      tracks: tracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playlist_id': playlistId,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'language_code': language,
      'is_public': isPublic,
      'likes_count': likesCount,
      'total_tracks': totalTracks,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (tracks != null)
        'tracks': tracks!.map((t) {
          if (t is PlaylistTrackModel) {
            return t.toJson();
          }
          return {
            'track_id': t.trackId,
            'title': t.title,
            'duration': t.duration,
            'created_at': t.createdAt.toIso8601String(),
          };
        }).toList(),
    };
  }
}
