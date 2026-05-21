import 'package:musee/features/user_artists/domain/entities/user_artist.dart';

abstract interface class UserArtistsRepository {
  Future<UserArtistDetail> getArtist(String artistId);
  Future<(List<UserArtistAlbum> items, int total, int page, int limit)>
  getArtistAlbums({
    required String artistId,
    required int page,
    required int limit,
  });
}
