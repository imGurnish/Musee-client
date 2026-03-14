import 'package:musee/core/providers/music_provider_registry.dart';

class UserAlbumDetailDTO {
  final String albumId;
  final String title;
  final String? coverUrl;
  final String? releaseDate; // YYYY-MM-DD
  final List<UserAlbumArtistDTO> artists;
  final List<UserAlbumTrackDTO> tracks;

  UserAlbumDetailDTO({
    required this.albumId,
    required this.title,
    required this.coverUrl,
    required this.releaseDate,
    required this.artists,
    required this.tracks,
  });
}

class UserAlbumArtistDTO {
  final String artistId;
  final String? name;
  final String? avatarUrl;

  UserAlbumArtistDTO({required this.artistId, this.name, this.avatarUrl});
}

class UserAlbumTrackDTO {
  final String trackId;
  final String title;
  final int duration; // seconds
  final bool isExplicit;
  final List<UserAlbumArtistDTO> artists;

  UserAlbumTrackDTO({
    required this.trackId,
    required this.title,
    required this.duration,
    required this.isExplicit,
    required this.artists,
  });
}

abstract interface class UserAlbumsRemoteDataSource {
  Future<UserAlbumDetailDTO> getAlbum(String albumId);
}

/// Album data source using external (JioSaavn) API via MusicProviderRegistry.
class UserAlbumsRemoteDataSourceImpl implements UserAlbumsRemoteDataSource {
  final MusicProviderRegistry _registry;

  UserAlbumsRemoteDataSourceImpl(this._registry);

  @override
  Future<UserAlbumDetailDTO> getAlbum(String albumId) async {
    final album = await _registry.getAlbumWithTracks(albumId);
    if (album == null) {
      throw Exception('Album not found: $albumId');
    }

    return UserAlbumDetailDTO(
      albumId: album.prefixedId,
      title: album.title,
      coverUrl: album.coverUrl,
      releaseDate: album.year,
      artists: album.artists
          .map(
            (a) => UserAlbumArtistDTO(
              artistId: a.prefixedId,
              name: a.name,
              avatarUrl: a.avatarUrl,
            ),
          )
          .toList(),
      tracks: (album.tracks ?? [])
          .map(
            (t) => UserAlbumTrackDTO(
              trackId: t.prefixedId,
              title: t.title,
              duration: t.durationSeconds ?? 0,
              isExplicit: t.isExplicit,
              artists: t.artists
                  .map(
                    (a) => UserAlbumArtistDTO(
                      artistId: a.prefixedId,
                      name: a.name,
                      avatarUrl: a.avatarUrl,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}
