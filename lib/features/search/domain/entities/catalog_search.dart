/// Source identifier for search results.
enum SearchSource { catalog }

class CatalogArtist {
  final String artistId;
  final String? name;
  final String? avatarUrl;
  final SearchSource source;

  CatalogArtist({
    required this.artistId,
    this.name,
    this.avatarUrl,
    this.source = SearchSource.catalog,
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
    this.source = SearchSource.catalog,
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
    this.source = SearchSource.catalog,
  });
}

class CatalogPlaylist {
  final String playlistId;
  final String name;
  final String? coverUrl;
  final String? creatorName;
  final SearchSource source;

  CatalogPlaylist({
    required this.playlistId,
    required this.name,
    this.coverUrl,
    this.creatorName,
    this.source = SearchSource.catalog,
  });
}

class CatalogSearchResults {
  final List<CatalogTrack> tracks;
  final List<CatalogAlbum> albums;
  final List<CatalogArtist> artists;
  final List<CatalogPlaylist> playlists;

  const CatalogSearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty &&
      albums.isEmpty &&
      artists.isEmpty &&
      playlists.isEmpty;

  /// Merge two search results (e.g., catalog + External).
  CatalogSearchResults merge(CatalogSearchResults other) {
    return CatalogSearchResults(
      tracks: [...tracks, ...other.tracks],
      albums: [...albums, ...other.albums],
      artists: [...artists, ...other.artists],
      playlists: [...playlists, ...other.playlists],
    );
  }
}
