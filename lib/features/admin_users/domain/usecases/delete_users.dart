import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_users/domain/repository/admin_repository.dart';

class DeleteUsers implements UseCase<void, List<String>> {
  final AdminRepository repo;
  DeleteUsers(this.repo);

  @override
  Future<Either<Failure, void>> call(List<String> ids) => repo.deleteUsers(ids);
}
