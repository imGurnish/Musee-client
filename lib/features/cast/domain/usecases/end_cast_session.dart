import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class EndCastSessionParams {
  final String sessionId;
  const EndCastSessionParams({required this.sessionId});
}

class EndCastSession implements UseCase<Unit, EndCastSessionParams> {
  final CastRepository repository;
  const EndCastSession(this.repository);

  @override
  Future<Either<Failure, Unit>> call(EndCastSessionParams params) {
    return repository.endCastSession(params.sessionId);
  }
}
