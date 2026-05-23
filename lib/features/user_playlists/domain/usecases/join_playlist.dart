import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class JoinPlaylist {
  final UserPlaylistsRepository _repo;

  JoinPlaylist(this._repo);

  Future<UserPlaylistDetail> call(String playlistId) =>
      _repo.joinCollaborativePlaylist(playlistId);
}
