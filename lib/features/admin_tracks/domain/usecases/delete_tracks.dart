import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import '../repository/admin_tracks_repository.dart';

class DeleteTracks implements UseCase<void, List<String>> {
  final AdminTracksRepository repo;
  DeleteTracks(this.repo);

  @override
  Future<Either<Failure, void>> call(List<String> ids) => repo.deleteTracks(ids);
}
