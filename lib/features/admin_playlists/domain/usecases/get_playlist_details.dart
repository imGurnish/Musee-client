import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_playlists/domain/entities/playlist.dart';
import 'package:musee/features/admin_playlists/domain/repositories/admin_playlists_repository.dart';

class GetPlaylistDetails implements UseCase<Playlist, String> {
  final AdminPlaylistsRepository repository;

  GetPlaylistDetails(this.repository);

  @override
  Future<Either<Failure, Playlist>> call(String playlistId) {
    return repository.getPlaylistDetails(playlistId);
  }
}
