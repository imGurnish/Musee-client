/// Source identifier for search results.
enum SearchSource { external }

class CatalogArtist {
  final String artistId;
  final String? name;
  final String? avatarUrl;
  final SearchSource source;

  CatalogArtist({
    required this.artistId,
    this.name,
    this.avatarUrl,
    this.source = SearchSource.external,
  });
}

class CatalogAlbum {
  final String albumId;
  final String title;
  final String? coverUrl;
  final List<CatalogArtist> artists;
  final SearchSource source;

  CatalogAlbum({
    required this.albumId,
    required this.title,
    this.coverUrl,
    this.artists = const [],
    this.source = SearchSource.external,
  });
}

class CatalogTrack {
  final String trackId;
  final String title;
  final int? duration;
  final List<CatalogArtist> artists;
  final String? imageUrl;
  final SearchSource source;

  CatalogTrack({
    required this.trackId,
    required this.title,
    this.duration,
    this.artists = const [],
    this.imageUrl,
    this.source = SearchSource.external,
  });
}

class CatalogSearchResults {
  final List<CatalogTrack> tracks;
  final List<CatalogAlbum> albums;
  final List<CatalogArtist> artists;

  const CatalogSearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
  });

  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty;

  /// Merge two search results (e.g., catalog + External).
  CatalogSearchResults merge(CatalogSearchResults other) {
    return CatalogSearchResults(
      tracks: [...tracks, ...other.tracks],
      albums: [...albums, ...other.albums],
      artists: [...artists, ...other.artists],
    );
  }
}
