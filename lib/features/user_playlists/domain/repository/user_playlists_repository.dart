import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';

abstract interface class UserPlaylistsRepository {
  Future<UserPlaylistDetail> getPlaylist(
    String playlistId, {
    bool forceRefresh = false,
  });
}
