import 'package:musee/features/user_albums/domain/entities/user_album.dart';

abstract interface class UserAlbumsRepository {
  Future<UserAlbumDetail> getAlbum(String albumId, {bool forceRefresh = false});
}
