import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import '../repository/admin_albums_repository.dart';

class DeleteAlbums implements UseCase<void, List<String>> {
  final AdminAlbumsRepository repo;
  DeleteAlbums(this.repo);

  @override
  Future<Either<Failure, void>> call(List<String> ids) => repo.deleteAlbums(ids);
}
