import 'package:musee/core/providers/music_provider_registry.dart';

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
}

abstract interface class UserArtistsRemoteDataSource {
  Future<UserArtistDTO> getArtist(String artistId);
  Future<List<UserArtistAlbumDTO>> getArtistAlbums(String artistId);
}

/// Artist data source using external (JioSaavn) API via MusicProviderRegistry.
class UserArtistsRemoteDataSourceImpl implements UserArtistsRemoteDataSource {
  final MusicProviderRegistry _registry;

  UserArtistsRemoteDataSourceImpl(this._registry);

  @override
  Future<UserArtistDTO> getArtist(String artistId) async {
    final artist = await _registry.getArtist(artistId);
    if (artist == null) {
      throw Exception('Artist not found: $artistId');
    }

    return UserArtistDTO(
      artistId: artist.prefixedId,
      name: artist.name,
      avatarUrl: artist.avatarUrl,
      bio: artist.bio,
    );
  }

  @override
  Future<List<UserArtistAlbumDTO>> getArtistAlbums(String artistId) async {
    // JioSaavn doesn't have a direct artist-albums endpoint.
    // Search by artist name as a workaround.
    final artist = await _registry.getArtist(artistId);
    if (artist == null) return [];

    final results = await _registry.search(
      artist.name,
      limitPerProvider: 10,
    );

    return results.albums
        .map(
          (album) => UserArtistAlbumDTO(
            albumId: album.prefixedId,
            title: album.title,
            coverUrl: album.coverUrl,
            releaseDate: album.year,
          ),
        )
        .toList();
  }
}
