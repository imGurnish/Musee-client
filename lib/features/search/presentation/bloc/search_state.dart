part of 'search_bloc.dart';

@immutable
sealed class SearchState {
  const SearchState();
}

final class SearchInitial extends SearchState {}

final class SearchLoading extends SearchState {}

final class SearchQueryLoading extends SearchState {}

final class SearchResultsLoaded extends SearchState {
  final CatalogSearchResults results;
  final Set<String> cachedTrackIds;
  final Set<String> cachedAlbumIds;
  final Set<String> cachedPlaylistIds;
  final bool fromOfflineCache;

  // Pagination metadata
  final bool hasReachedMax;
  final int page;
  final String? type;
  final String query;
  final bool isFetchingMore;

  const SearchResultsLoaded(
    this.results, {
    this.cachedTrackIds = const <String>{},
    this.cachedAlbumIds = const <String>{},
    this.cachedPlaylistIds = const <String>{},
    this.fromOfflineCache = false,
    this.hasReachedMax = false,
    this.page = 1,
    this.type,
    this.query = '',
    this.isFetchingMore = false,
  });

  SearchResultsLoaded copyWith({
    CatalogSearchResults? results,
    Set<String>? cachedTrackIds,
    Set<String>? cachedAlbumIds,
    Set<String>? cachedPlaylistIds,
    bool? fromOfflineCache,
    bool? hasReachedMax,
    int? page,
    String? type,
    String? query,
    bool? isFetchingMore,
  }) {
    return SearchResultsLoaded(
      results ?? this.results,
      cachedTrackIds: cachedTrackIds ?? this.cachedTrackIds,
      cachedAlbumIds: cachedAlbumIds ?? this.cachedAlbumIds,
      cachedPlaylistIds: cachedPlaylistIds ?? this.cachedPlaylistIds,
      fromOfflineCache: fromOfflineCache ?? this.fromOfflineCache,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      page: page ?? this.page,
      type: type ?? this.type,
      query: query ?? this.query,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResultsLoaded &&
        other.results == results &&
        setEquals(other.cachedTrackIds, cachedTrackIds) &&
        setEquals(other.cachedAlbumIds, cachedAlbumIds) &&
        setEquals(other.cachedPlaylistIds, cachedPlaylistIds) &&
        other.fromOfflineCache == fromOfflineCache &&
        other.hasReachedMax == hasReachedMax &&
        other.page == page &&
        other.type == type &&
        other.query == query &&
        other.isFetchingMore == isFetchingMore;
  }

  @override
  int get hashCode => Object.hash(
        results,
        cachedTrackIds.length,
        cachedAlbumIds.length,
        cachedPlaylistIds.length,
        fromOfflineCache,
        hasReachedMax,
        page,
        type,
        query,
        isFetchingMore,
      );
}

class VideosError extends SearchState {
  final String message;
  const VideosError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideosError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}

final class SuggestionLoading extends SearchState {}

class SuggestionError extends SearchState {
  final String message;
  const SuggestionError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideosError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}

class SuggestionLoaded extends SearchState {
  final List<Suggestion> suggestions;
  const SuggestionLoaded(this.suggestions);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuggestionLoaded && other.suggestions == suggestions;
  }

  @override
  int get hashCode => suggestions.hashCode;
}

final class SearchTestInitial extends SearchState {}

class SearchTestError extends SearchState {
  final String message;
  const SearchTestError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchTestError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}

class SearchTestLoaded extends SearchState {
  final String query;
  const SearchTestLoaded(this.query);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchTestLoaded && other.query == query;
  }

  @override
  int get hashCode => query.hashCode;
}
