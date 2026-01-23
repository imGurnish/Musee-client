import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';

abstract interface class UserDashboardRepository {
  Future<PagedDashboardItems> getMadeForYou({int page, int limit});
  Future<PagedDashboardItems> getTrending({int page, int limit});
}
