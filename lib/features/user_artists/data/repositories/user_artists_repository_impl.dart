import 'package:musee/features/user_artists/data/datasources/user_artists_remote_data_source.dart';
import 'package:musee/features/user_artists/domain/entities/user_artist.dart';
import 'package:musee/features/user_artists/domain/repository/user_artists_repository.dart';

class UserArtistsRepositoryImpl implements UserArtistsRepository {
  final UserArtistsRemoteDataSource _remote;
  UserArtistsRepositoryImpl(this._remote);

  @override
  Future<UserArtistDetail> getArtist(String artistId) async {
    final artist = await _remote.getArtist(artistId);
    final albums = await _remote.getArtistAlbums(artistId);
    List<UserArtistTrackDTO> tracks = const [];
    try {
      tracks = await _remote.getArtistTracks(
        artistId: artistId,
        artistName: artist.name,
      );
    } catch (_) {
      tracks = const [];
    }

    return UserArtistDetail(
      artistId: artist.artistId,
      name: artist.name,
      avatarUrl: artist.avatarUrl,
      coverUrl: artist.coverUrl,
      bio: artist.bio,
      genres: artist.genres,
      monthlyListeners: artist.monthlyListeners,
      albums: albums
          .map(
            (a) => UserArtistAlbum(
              albumId: a.albumId,
              title: a.title,
              coverUrl: a.coverUrl,
              releaseDate: a.releaseDate,
            ),
          )
          .toList(),
      tracks: tracks
          .map(
            (t) => UserArtistTrack(
              trackId: t.trackId,
              title: t.title,
              duration: t.duration,
              playCount: t.playCount,
              likesCount: t.likesCount,
              albumId: t.albumId,
              coverUrl: t.coverUrl,
              artists: t.artists
                  .map(
                    (a) => UserArtistTrackArtist(
                      artistId: a.artistId,
                      name: a.name,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}
