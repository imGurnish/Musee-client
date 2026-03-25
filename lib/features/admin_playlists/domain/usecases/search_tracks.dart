import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_playlists/data/models/track_search_model.dart';
import 'package:musee/features/admin_playlists/domain/repositories/admin_playlists_repository.dart';

class SearchTracks implements UseCase<(List<TrackSearchModel>, int, int, int), SearchTracksParams> {
  final AdminPlaylistsRepository repository;

  SearchTracks(this.repository);

  @override
  Future<Either<Failure, (List<TrackSearchModel>, int, int, int)>> call(SearchTracksParams params) {
    return repository.searchTracks(
      page: params.page,
      limit: params.limit,
      query: params.query,
    );
  }
}

class SearchTracksParams {
  final int page;
  final int limit;
  final String? query;

  SearchTracksParams({
    this.page = 0,
    this.limit = 20,
    this.query,
  });
}
