import 'package:musee/features/user_artists/data/datasources/user_artists_remote_data_source.dart';
import 'package:musee/features/user_artists/domain/entities/user_artist.dart';
import 'package:musee/features/user_artists/domain/repository/user_artists_repository.dart';

class UserArtistsRepositoryImpl implements UserArtistsRepository {
  final UserArtistsRemoteDataSource _remote;
  UserArtistsRepositoryImpl(this._remote);

  // DTO → entity helper (shared by getArtist and getArtistAlbums)
  UserArtistAlbum _toEntity(UserArtistAlbumDTO dto) => UserArtistAlbum(
    albumId: dto.albumId,
    title: dto.title,
    coverUrl: dto.coverUrl,
    releaseDate: dto.releaseDate,
    isSingle: dto.isSingle,
    singleTrackId: dto.singleTrackId,
  );

  @override
  Future<UserArtistDetail> getArtist(String artistId) async {
    // Fetch artist metadata, first page of albums, first page of singles,
    // and tracks – all in parallel for fast initial load.
    final results = await Future.wait([
      _remote.getArtist(artistId),
      _remote.getArtistAlbums(
        artistId: artistId,
        page: 0,
        limit: 20,
        singleTrack: false,
      ),
      _remote.getArtistAlbums(
        artistId: artistId,
        page: 0,
        limit: 20,
        singleTrack: true,
      ),
    ]);

    final artist = results[0] as UserArtistDTO;
    final albumsPage =
        results[1]
            as (List<UserArtistAlbumDTO>, int, int, int);
    final singlesPage =
        results[2]
            as (List<UserArtistAlbumDTO>, int, int, int);

    List<UserArtistTrackDTO> tracks = const [];
    try {
      tracks = await _remote.getArtistTracks(
        artistId: artistId,
        artistName: artist.name,
      );
    } catch (_) {
      tracks = const [];
    }

    // Singles first, then albums – within the initial page.
    final combinedAlbums = [
      ...singlesPage.$1.map(_toEntity),
      ...albumsPage.$1.map(_toEntity),
    ];

    return UserArtistDetail(
      artistId: artist.artistId,
      name: artist.name,
      avatarUrl: artist.avatarUrl,
      coverUrl: artist.coverUrl,
      bio: artist.bio,
      genres: artist.genres,
      monthlyListeners: artist.monthlyListeners,
      albums: combinedAlbums,
      tracks:
          tracks
              .map(
                (t) => UserArtistTrack(
                  trackId: t.trackId,
                  title: t.title,
                  duration: t.duration,
                  playCount: t.playCount,
                  likesCount: t.likesCount,
                  albumId: t.albumId,
                  coverUrl: t.coverUrl,
                  artists:
                      t.artists
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

  @override
  Future<(List<UserArtistAlbum> items, int total, int page, int limit)>
  getArtistAlbums({
    required String artistId,
    required int page,
    required int limit,
    bool singleTrack = false,
  }) async {
    final pageData = await _remote.getArtistAlbums(
      artistId: artistId,
      page: page,
      limit: limit,
      singleTrack: singleTrack,
    );
    return (
      pageData.$1.map(_toEntity).toList(),
      pageData.$2,
      pageData.$3,
      pageData.$4,
    );
  }
}
