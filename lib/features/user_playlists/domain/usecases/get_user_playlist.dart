import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class GetUserPlaylist {
  final UserPlaylistsRepository _repo;

  GetUserPlaylist(this._repo);

  Future<UserPlaylistDetail> call(
    String playlistId, {
    bool forceRefresh = false,
  }) =>
      _repo.getPlaylist(playlistId, forceRefresh: forceRefresh);
}
