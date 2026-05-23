import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class RemovePlaylistTrack {
  final UserPlaylistsRepository _repo;

  RemovePlaylistTrack(this._repo);

  Future<void> call(String playlistId, String trackId) =>
      _repo.removeTrackFromPlaylist(playlistId, trackId);
}
