import 'package:musee/features/user_albums/domain/entities/user_album.dart';
import 'package:musee/features/user_albums/domain/repository/user_albums_repository.dart';

class GetUserAlbum {
  final UserAlbumsRepository _repo;
  GetUserAlbum(this._repo);

  Future<UserAlbumDetail> call(String albumId, {bool forceRefresh = false}) =>
      _repo.getAlbum(albumId, forceRefresh: forceRefresh);
}
