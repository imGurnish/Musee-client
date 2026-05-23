import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';

abstract interface class UserPlaylistsRepository {
  Future<UserPlaylistDetail> getPlaylist(
    String playlistId, {
    bool forceRefresh = false,
  });

  Future<List<UserPlaylistDetail>> getPlaylists();

  Future<UserPlaylistDetail> createPlaylist({
    required String name,
    String? description,
    required bool isPublic,
    required bool isCollaborative,
    String? coverPath,
  });

  Future<UserPlaylistDetail> joinCollaborativePlaylist(String playlistId);

  Future<UserPlaylistDetail> addTrackToPlaylist(String playlistId, String trackId);

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);

  Future<void> deletePlaylist(String playlistId);

  Future<UserPlaylistDetail> updatePlaylist({
    required String playlistId,
    String? name,
    String? description,
    bool? isPublic,
    bool? isCollaborative,
    String? coverPath,
  });
}
