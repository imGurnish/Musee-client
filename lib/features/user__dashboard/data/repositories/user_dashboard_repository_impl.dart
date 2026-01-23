import 'package:musee/features/user__dashboard/data/datasources/user_dashboard_remote_data_source.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:musee/features/user__dashboard/domain/repository/user_dashboard_repository.dart';

class UserDashboardRepositoryImpl implements UserDashboardRepository {
  final UserDashboardRemoteDataSource _remote;
  UserDashboardRepositoryImpl(this._remote);

  @override
  Future<PagedDashboardItems> getMadeForYou({
    int page = 0,
    int limit = 20,
  }) async {
    return _remote.getMadeForYou(page: page, limit: limit);
  }

  @override
  Future<PagedDashboardItems> getTrending({
    int page = 0,
    int limit = 20,
  }) async {
    return _remote.getTrending(page: page, limit: limit);
  }
}
