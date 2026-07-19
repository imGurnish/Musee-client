import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:musee/features/user__dashboard/domain/repository/user_dashboard_repository.dart';

class ListUndiscoveredGems {
  final UserDashboardRepository _repo;
  ListUndiscoveredGems(this._repo);

  Future<PagedDashboardItems> call({int page = 0, int limit = 20}) {
    return _repo.getUndiscoveredGems(page: page, limit: limit);
  }
}
