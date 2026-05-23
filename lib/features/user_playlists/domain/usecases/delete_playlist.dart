import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class DeletePlaylist {
  final UserPlaylistsRepository _repo;

  DeletePlaylist(this._repo);

  Future<void> call(String playlistId) => _repo.deletePlaylist(playlistId);
}
