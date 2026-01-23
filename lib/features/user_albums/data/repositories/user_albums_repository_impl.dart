import 'package:musee/features/user_albums/data/datasources/user_albums_remote_data_source.dart';
import 'package:musee/features/user_albums/domain/entities/user_album.dart';
import 'package:musee/features/user_albums/domain/repository/user_albums_repository.dart';
import 'package:musee/core/providers/music_provider_registry.dart';

class UserAlbumsRepositoryImpl implements UserAlbumsRepository {
  final UserAlbumsRemoteDataSource _remote;
  final MusicProviderRegistry _registry;

  UserAlbumsRepositoryImpl(this._remote, this._registry);

  @override
  Future<UserAlbumDetail> getAlbum(String albumId) async {
    // Check if ID is likely external (not a UUID)
    final isUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(albumId);

    if (!isUuid) {
      final album = await _registry.getAlbumWithTracks(albumId);
      if (album != null) {
        return UserAlbumDetail(
          albumId: album.prefixedId,
          title: album.title,
          coverUrl: album.coverUrl,
          releaseDate: DateTime.now().toIso8601String(),
          artists: album.artists
              .map(
                (a) => UserAlbumArtist(
                  artistId: a.prefixedId,
                  name: a.name,
                  avatarUrl: null,
                ),
              )
              .toList(),
          tracks: (album.tracks ?? [])
              .map(
                (t) => UserAlbumTrack(
                  trackId: t.prefixedId,
                  title: t.title,
                  duration: t.durationSeconds ?? 0,
                  isExplicit: t.isExplicit,
                  artists: t.artists
                      .map(
                        (a) => UserAlbumArtist(
                          artistId: a.prefixedId,
                          name: a.name,
                          avatarUrl: null,
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        );
      }
      throw Exception("External album not found");
    }

    final dto = await _remote.getAlbum(albumId);
    return UserAlbumDetail(
      albumId: dto.albumId,
      title: dto.title,
      coverUrl: dto.coverUrl,
      releaseDate: dto.releaseDate,
      artists: dto.artists
          .map(
            (a) => UserAlbumArtist(
              artistId: a.artistId,
              name: a.name,
              avatarUrl: a.avatarUrl,
            ),
          )
          .toList(),
      tracks: dto.tracks
          .map(
            (t) => UserAlbumTrack(
              trackId: t.trackId,
              title: t.title,
              duration: t.duration,
              isExplicit: t.isExplicit,
              artists: t.artists
                  .map(
                    (a) => UserAlbumArtist(
                      artistId: a.artistId,
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
