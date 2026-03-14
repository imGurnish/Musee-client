import 'package:musee/features/search/domain/entities/catalog_search.dart';

class CatalogArtistModel extends CatalogArtist {
  CatalogArtistModel({
    required super.artistId,
    super.name,
    super.avatarUrl,
    super.source = SearchSource.external,
  });

  factory CatalogArtistModel.fromJson(Map<String, dynamic> json) {
    String? name = json['name'] as String?;
    String? avatarUrl = json['avatar_url'] as String?;
    // Fallback for admin-style or enriched payloads with nested user fields
    final users = json['users'];
    if (name == null && users is Map) {
      name = users['name'] as String?;
    }
    if (avatarUrl == null && users is Map) {
      avatarUrl = users['avatar_url'] as String?;
    }
    return CatalogArtistModel(
      artistId: json['artist_id']?.toString() ?? json['id']?.toString() ?? '',
      name: name,
      avatarUrl: avatarUrl,
    );
  }
}

class CatalogAlbumModel extends CatalogAlbum {
  CatalogAlbumModel({
    required super.albumId,
    required super.title,
    super.coverUrl,
    super.artists = const [],
    super.source = SearchSource.external,
  });

  factory CatalogAlbumModel.fromJson(Map<String, dynamic> json) {
    final artists =
        (json['artists'] as List?)
            ?.map(
              (e) => CatalogArtistModel.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList() ??
        const <CatalogArtistModel>[];
    return CatalogAlbumModel(
      albumId: json['album_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['cover_url'] as String?,
      artists: artists,
    );
  }
}

class CatalogTrackModel extends CatalogTrack {
  CatalogTrackModel({
    required super.trackId,
    required super.title,
    super.duration,
    super.artists = const [],
    super.imageUrl,
    super.source = SearchSource.external,
  });

  factory CatalogTrackModel.fromJson(Map<String, dynamic> json) {
    final artists =
        (json['artists'] as List?)
            ?.map(
              (e) => CatalogArtistModel.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList() ??
        const <CatalogArtistModel>[];
    return CatalogTrackModel(
      trackId: json['track_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      duration: (json['duration'] is int)
          ? json['duration'] as int
          : int.tryParse(json['duration']?.toString() ?? ''),
      artists: artists,
      imageUrl:
          (json['album']?['cover_url'] ??
                  json['image_url'] ??
                  json['cover_url'])
              as String?,
    );
  }
}

class CatalogSearchResultsModel extends CatalogSearchResults {
  const CatalogSearchResultsModel({
    super.tracks = const [],
    super.albums = const [],
    super.artists = const [],
  });

  factory CatalogSearchResultsModel.fromThreeLists({
    required List<dynamic> tracks,
    required List<dynamic> albums,
    required List<dynamic> artists,
  }) {
    return CatalogSearchResultsModel(
      tracks: tracks
          .map(
            (e) =>
                CatalogTrackModel.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      albums: albums
          .map(
            (e) =>
                CatalogAlbumModel.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      artists: artists
          .map(
            (e) =>
                CatalogArtistModel.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
