import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class JoinCastSessionParams {
  final String sessionCode;
  const JoinCastSessionParams({required this.sessionCode});
}

class JoinCastSession implements UseCase<CastSession, JoinCastSessionParams> {
  final CastRepository repository;
  const JoinCastSession(this.repository);

  @override
  Future<Either<Failure, CastSession>> call(JoinCastSessionParams params) {
    return repository.joinCastSessionByCode(params.sessionCode);
  }
}
