import 'package:fpdart/fpdart.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/error/failures.dart';

abstract interface class AdminRepository {
  Future<Either<Failure, (List<User> items, int total, int page, int limit)>>
  listUsers({int page, int limit, String? search});

  Future<Either<Failure, User>> getUser(String id);

  Future<Either<Failure, User>> createUser({
    required String name,
    required String email,
    SubscriptionType subscriptionType,
    String? planId,
    List<int>? avatarBytes,
    String? avatarFilename,
  });

  Future<Either<Failure, User>> updateUser({
    required String id,
    String? name,
    String? email,
    SubscriptionType? subscriptionType,
    String? planId,
    List<int>? avatarBytes,
    String? avatarFilename,
  });

  Future<Either<Failure, void>> deleteUser(String id);

  Future<Either<Failure, void>> deleteUsers(List<String> ids);
}
