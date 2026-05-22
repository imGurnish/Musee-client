import 'package:musee/features/user_artists/domain/entities/user_artist.dart';
import 'package:musee/features/user_artists/domain/repository/user_artists_repository.dart';

class GetUserArtistAlbums {
  final UserArtistsRepository _repo;
  GetUserArtistAlbums(this._repo);

  Future<(List<UserArtistAlbum> items, int total, int page, int limit)>
  call({
    required String artistId,
    required int page,
    required int limit,
    bool singleTrack = false,
  }) {
    return _repo.getArtistAlbums(
      artistId: artistId,
      page: page,
      limit: limit,
      singleTrack: singleTrack,
    );
  }
}