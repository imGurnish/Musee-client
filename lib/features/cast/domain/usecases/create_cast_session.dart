import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class CreateCastSessionParams {
  final String? deviceName;
  const CreateCastSessionParams({this.deviceName});
}

class CreateCastSession implements UseCase<CastSession, CreateCastSessionParams> {
  final CastRepository repository;
  const CreateCastSession(this.repository);

  @override
  Future<Either<Failure, CastSession>> call(CreateCastSessionParams params) {
    return repository.createCastSession(deviceName: params.deviceName);
  }
}
