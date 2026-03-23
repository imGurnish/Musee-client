import '../../domain/entities/album.dart';

class AlbumArtistLinkModel extends AlbumArtistLink {
  const AlbumArtistLinkModel({
    super.artistId,
    super.role,
    super.name,
    super.avatarUrl,
  });

  factory AlbumArtistLinkModel.fromJson(Map<String, dynamic> json) {
    return AlbumArtistLinkModel(
      artistId: json['artist_id'] as String?,
      role: json['role'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class AlbumTrackSummaryModel extends AlbumTrackSummary {
  const AlbumTrackSummaryModel({
    required super.id,
    required super.title,
    super.coverUrl,
    required super.duration,
    required super.isExplicit,
    super.isPublished,
    super.createdAt,
    super.artists = const [],
  });

  factory AlbumTrackSummaryModel.fromJson(Map<String, dynamic> json) {
    return AlbumTrackSummaryModel(
      id: (json['track_id'] ?? json['id']).toString(),
      title: (json['title'] ?? '') as String,
      coverUrl: json['cover_url'] as String?,
      duration: (json['duration'] as num).toInt(),
      isExplicit: (json['is_explicit'] as bool?) ?? false,
      isPublished: json['is_published'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      artists:
          (json['artists'] as List?)
              ?.map(
                (e) =>
                    AlbumArtistLinkModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
    );
  }
}

class AlbumModel extends Album {
  const AlbumModel({
    required super.id,
    super.extAlbumId,
    required super.title,
    super.description,
    super.coverUrl,
    super.language,
    super.releaseDate,
    super.genres = const [],
    super.totalTracks,
    super.likesCount,
    super.createdAt,
    super.updatedAt,
    super.isPublished = false,
    super.duration,
    super.artists = const [],
    super.tracks,
  });

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      id: (json['album_id'] ?? json['id']).toString(),
      extAlbumId: json['ext_album_id']?.toString(),
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      language: json['language']?.toString(),
      releaseDate: json['release_date']?.toString(),
      genres:
          (json['genres'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      totalTracks: (json['total_tracks'] as num?)?.toInt(),
      likesCount: (json['likes_count'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isPublished: (json['is_published'] as bool?) ?? false,
      duration: (json['duration'] as num?)?.toInt(),
      artists:
          (json['artists'] as List?)
              ?.map(
                (e) =>
                    AlbumArtistLinkModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      tracks: (json['tracks'] as List?)
          ?.map(
            (e) =>
                AlbumTrackSummaryModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}
