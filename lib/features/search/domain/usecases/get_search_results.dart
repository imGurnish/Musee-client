import 'package:musee/core/error/failures.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:musee/features/search/domain/repository/search_repository.dart';
import 'package:fpdart/fpdart.dart';

class GetSearchResults {
  final SearchRepository repository;

  GetSearchResults(this.repository);

  Future<Either<Failure, CatalogSearchResults>> call(
    String query, {
    String? type,
    int? limit,
    int? page,
  }) {
    return repository.searchCatalog(
      query,
      type: type,
      limit: limit,
      page: page,
    );
  }
}
