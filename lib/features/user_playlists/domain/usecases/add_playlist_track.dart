import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class AddPlaylistTrack {
  final UserPlaylistsRepository _repo;

  AddPlaylistTrack(this._repo);

  Future<UserPlaylistDetail> call(String playlistId, String trackId) =>
      _repo.addTrackToPlaylist(playlistId, trackId);
}
