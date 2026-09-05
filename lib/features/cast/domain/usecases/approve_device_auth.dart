import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class ApproveDeviceAuthParams {
  final String token;
  const ApproveDeviceAuthParams({required this.token});
}

class ApproveDeviceAuth implements UseCase<Unit, ApproveDeviceAuthParams> {
  final CastRepository repository;
  const ApproveDeviceAuth(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ApproveDeviceAuthParams params) {
    return repository.approveDeviceAuth(params.token);
  }
}
