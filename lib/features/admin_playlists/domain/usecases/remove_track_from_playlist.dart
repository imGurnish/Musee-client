import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_playlists/domain/repositories/admin_playlists_repository.dart';

class RemoveTrackFromPlaylist implements UseCase<void, RemoveTrackFromPlaylistParams> {
  final AdminPlaylistsRepository repository;

  RemoveTrackFromPlaylist(this.repository);

  @override
  Future<Either<Failure, void>> call(RemoveTrackFromPlaylistParams params) {
    return repository.removeTrackFromPlaylist(
      playlistId: params.playlistId,
      trackId: params.trackId,
    );
  }
}

class RemoveTrackFromPlaylistParams {
  final String playlistId;
  final String trackId;

  RemoveTrackFromPlaylistParams({
    required this.playlistId,
    required this.trackId,
  });
}
