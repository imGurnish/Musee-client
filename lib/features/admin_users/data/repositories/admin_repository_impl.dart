import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/admin_users/data/datasources/admin_remote_data_source.dart';
import 'package:musee/features/admin_users/domain/repository/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource remote;

  AdminRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, (List<User> items, int total, int page, int limit)>>
  listUsers({int page = 0, int limit = 20, String? search}) async {
    try {
      final result = await remote.listUsers(
        page: page,
        limit: limit,
        search: search,
      );
      return right(result);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getUser(String id) async {
    try {
      final user = await remote.getUser(id);
      return right(user);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> createUser({
    required String name,
    required String email,
    SubscriptionType subscriptionType = SubscriptionType.free,
    String? planId,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    try {
      final user = await remote.createUser(
        name: name,
        email: email,
        subscriptionType: subscriptionType,
        planId: planId,
        avatarBytes: avatarBytes != null
            ? Uint8List.fromList(avatarBytes)
            : null,
        avatarFilename: avatarFilename,
      );
      return right(user);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateUser({
    required String id,
    String? name,
    String? email,
    SubscriptionType? subscriptionType,
    String? planId,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    try {
      final user = await remote.updateUser(
        id: id,
        name: name,
        email: email,
        subscriptionType: subscriptionType,
        planId: planId,
        avatarBytes: avatarBytes != null
            ? Uint8List.fromList(avatarBytes)
            : null,
        avatarFilename: avatarFilename,
      );
      return right(user);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String id) async {
    try {
      await remote.deleteUser(id);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUsers(List<String> ids) async {
    try {
      await remote.deleteUsers(ids);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }
}
