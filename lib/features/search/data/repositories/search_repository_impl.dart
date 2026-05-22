import 'package:musee/core/error/failures.dart';
import 'package:musee/features/search/data/datasources/search_remote_data_source.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:musee/features/search/domain/entities/suggestion.dart';
import 'package:musee/features/search/domain/repository/search_repository.dart';
import 'package:fpdart/fpdart.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<Suggestion>>> getSuggestions(String query) async {
    try {
      final suggestions = await remoteDataSource.getSuggestions(query);
      return Right(suggestions);
    } catch (error) {
      return Left(Failure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, CatalogSearchResults>> searchCatalog(
    String query, {
    String? type,
    int? limit,
    int? page,
  }) {
    try {
      return remoteDataSource
          .searchCatalog(
            query,
            type: type,
            limit: limit,
            page: page,
          )
          .then((results) => Right(results));
    } catch (error) {
      return Future.value(Left(Failure(error.toString())));
    }
  }
}
