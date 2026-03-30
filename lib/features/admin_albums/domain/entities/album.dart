class AlbumArtistLink {
  final String? artistId;
  final String? role; // owner|editor|viewer
  final String? name;
  final String? avatarUrl;

  const AlbumArtistLink({this.artistId, this.role, this.name, this.avatarUrl});
}

class AlbumTrackSummary {
  final String id; // track_id
  final String title;
  final String? coverUrl;
  final int duration;
  final bool isExplicit;
  final bool? isPublished; // admin may include
  final DateTime? createdAt;
  final List<AlbumArtistLink> artists;

  const AlbumTrackSummary({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.duration,
    required this.isExplicit,
    this.isPublished,
    this.createdAt,
    this.artists = const [],
  });
}

class Album {
  final String id; // album_id
  final String? extAlbumId;
  final String title;
  final String? description;
  final String? coverUrl;
  final String? language;
  final String? releaseDate;
  final List<String> genres;
  final int? totalTracks;
  final int? likesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPublished;
  final int? duration;
  final List<AlbumArtistLink> artists;
  final List<AlbumTrackSummary>? tracks; // only present in GET one

  const Album({
    required this.id,
    this.extAlbumId,
    required this.title,
    this.description,
    this.coverUrl,
    this.language,
    this.releaseDate,
    this.genres = const [],
    this.totalTracks,
    this.likesCount,
    this.createdAt,
    this.updatedAt,
    this.isPublished = false,
    this.duration,
    this.artists = const [],
    this.tracks,
  });
}
