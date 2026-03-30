import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_playlists/domain/entities/playlist.dart';
import 'package:musee/features/admin_playlists/domain/repositories/admin_playlists_repository.dart';

class AddTrackToPlaylist implements UseCase<Playlist, AddTrackToPlaylistParams> {
  final AdminPlaylistsRepository repository;

  AddTrackToPlaylist(this.repository);

  @override
  Future<Either<Failure, Playlist>> call(AddTrackToPlaylistParams params) {
    return repository.addTrackToPlaylist(
      playlistId: params.playlistId,
      trackId: params.trackId,
    );
  }
}

class AddTrackToPlaylistParams {
  final String playlistId;
  final String trackId;

  AddTrackToPlaylistParams({
    required this.playlistId,
    required this.trackId,
  });
}
