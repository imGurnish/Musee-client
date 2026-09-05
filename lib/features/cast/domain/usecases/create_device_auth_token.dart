import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/cast/domain/entities/device_auth_token.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class CreateDeviceAuthTokenParams {
  final String? deviceName;
  const CreateDeviceAuthTokenParams({this.deviceName});
}

class CreateDeviceAuthToken implements UseCase<DeviceAuthToken, CreateDeviceAuthTokenParams> {
  final CastRepository repository;
  const CreateDeviceAuthToken(this.repository);

  @override
  Future<Either<Failure, DeviceAuthToken>> call(CreateDeviceAuthTokenParams params) {
    return repository.createDeviceAuthToken(deviceName: params.deviceName);
  }
}
