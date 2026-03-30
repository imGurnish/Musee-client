import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import '../repository/admin_artists_repository.dart';

class DeleteArtists implements UseCase<void, List<String>> {
  final AdminArtistsRepository repo;
  DeleteArtists(this.repo);

  @override
  Future<Either<Failure, void>> call(List<String> ids) =>
      repo.deleteArtists(ids);
}
