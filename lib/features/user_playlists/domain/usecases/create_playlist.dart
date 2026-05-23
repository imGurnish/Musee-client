import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class CreatePlaylist {
  final UserPlaylistsRepository _repo;

  CreatePlaylist(this._repo);

  Future<UserPlaylistDetail> call({
    required String name,
    String? description,
    required bool isPublic,
    required bool isCollaborative,
    String? coverPath,
  }) =>
      _repo.createPlaylist(
        name: name,
        description: description,
        isPublic: isPublic,
        isCollaborative: isCollaborative,
        coverPath: coverPath,
      );
}
