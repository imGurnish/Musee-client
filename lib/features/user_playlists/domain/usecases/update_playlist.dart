import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class UpdatePlaylist {
  final UserPlaylistsRepository _repo;

  UpdatePlaylist(this._repo);

  Future<UserPlaylistDetail> call({
    required String playlistId,
    String? name,
    String? description,
    bool? isPublic,
    bool? isCollaborative,
    String? coverPath,
  }) =>
      _repo.updatePlaylist(
        playlistId: playlistId,
        name: name,
        description: description,
        isPublic: isPublic,
        isCollaborative: isCollaborative,
        coverPath: coverPath,
      );
}
