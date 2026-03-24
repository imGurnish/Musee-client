import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/user_media_detail_cache_service.dart';
import 'package:musee/core/common/services/connectivity_service.dart';
import 'package:musee/features/search/domain/entities/suggestion.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:musee/features/search/domain/usecases/get_suggestions.dart';
import 'package:musee/features/search/domain/usecases/get_search_results.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final GetSuggestions getSuggestions;
  final GetSearchResults getSearchResults;
  final TrackCacheService? _trackCache;
  final UserMediaDetailCacheService? _detailCache;
  final ConnectivityService? _connectivity;

  SearchBloc(
    this.getSuggestions,
    this.getSearchResults, {
    TrackCacheService? trackCache,
    UserMediaDetailCacheService? detailCache,
    ConnectivityService? connectivity,
  }) : _trackCache =
           trackCache ??
           (GetIt.I.isRegistered<TrackCacheService>()
               ? GetIt.I<TrackCacheService>()
               : null),
       _detailCache =
           detailCache ??
           (GetIt.I.isRegistered<UserMediaDetailCacheService>()
               ? GetIt.I<UserMediaDetailCacheService>()
               : null),
       _connectivity =
           connectivity ??
           (GetIt.I.isRegistered<ConnectivityService>()
               ? GetIt.I<ConnectivityService>()
             : null),
         super(SearchInitial()) {
    on<FetchSuggestions>((event, emit) async {
      emit(SuggestionLoading());
      try {
        final suggestions = await getSuggestions(event.query);
        suggestions.fold(
          (failure) => emit(SuggestionError(failure.message)),
          (data) => emit(SuggestionLoaded(data)),
        );
      } catch (e) {
        emit(
          SuggestionError(
            'Failed to fetch suggestions. Please check your internet connection.',
          ),
        );
      }
    });

    on<SearchQuery>((event, emit) async {
      emit(SearchQueryLoading());
      try {
        final isOnline = await (_connectivity?.checkConnectivity() ??
            Future<bool>.value(true));

        if (!isOnline) {
          final offline = await _searchCached(event.query);
          final enrichedOffline = await _enrichCacheStatus(offline);
          emit(
            SearchResultsLoaded(
              offline,
              cachedTrackIds: enrichedOffline.cachedTrackIds,
              cachedAlbumIds: enrichedOffline.cachedAlbumIds,
              cachedPlaylistIds: enrichedOffline.cachedPlaylistIds,
              fromOfflineCache: true,
            ),
          );
          return;
        }

        final results = await getSearchResults(event.query);
        await results.fold(
          (failure) async {
            final offline = await _searchCached(event.query);
            if (!offline.isEmpty) {
              final enrichedOffline = await _enrichCacheStatus(offline);
              emit(
                SearchResultsLoaded(
                  offline,
                  cachedTrackIds: enrichedOffline.cachedTrackIds,
                  cachedAlbumIds: enrichedOffline.cachedAlbumIds,
                  cachedPlaylistIds: enrichedOffline.cachedPlaylistIds,
                  fromOfflineCache: true,
                ),
              );
              return;
            }
            emit(VideosError(failure.message));
          },
          (data) async {
            final enriched = await _enrichCacheStatus(data);
            emit(
              SearchResultsLoaded(
                data,
                cachedTrackIds: enriched.cachedTrackIds,
                cachedAlbumIds: enriched.cachedAlbumIds,
                cachedPlaylistIds: enriched.cachedPlaylistIds,
                fromOfflineCache: false,
              ),
            );
          },
        );
      } catch (e) {
        final offline = await _searchCached(event.query);
        if (!offline.isEmpty) {
          final enrichedOffline = await _enrichCacheStatus(offline);
          emit(
            SearchResultsLoaded(
              offline,
              cachedTrackIds: enrichedOffline.cachedTrackIds,
              cachedAlbumIds: enrichedOffline.cachedAlbumIds,
              cachedPlaylistIds: enrichedOffline.cachedPlaylistIds,
              fromOfflineCache: true,
            ),
          );
        } else {
          emit(
            VideosError(
              'Failed to fetch videos. Please check your internet connection.',
            ),
          );
        }
      }
    });

    on<RunTest>((event, emit) async {
      emit(SearchLoading());
      try {
        if (kDebugMode) print("HEre");
        final result = event.query;
        emit(SearchTestLoaded(result));
      } catch (e) {
        emit(
          SearchTestError(
            'Failed to run test. Please check your internet connection.',
          ),
        );
      }
    });
  }

  Future<CatalogSearchResults> _searchCached(String query) async {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return const CatalogSearchResults();

    final trackCache = _trackCache;
    final detailCache = _detailCache;

    if (trackCache == null && detailCache == null) {
      return const CatalogSearchResults();
    }

    final tracks = <CatalogTrack>[];
    final albums = <CatalogAlbum>[];
    final playlists = <CatalogPlaylist>[];
    final artists = <CatalogArtist>[];

    if (trackCache != null) {
      final cachedTracks = await trackCache.getAllTracks();
      for (final t in cachedTracks) {
        final haystack =
            '${t.title} ${t.artistName} ${t.albumTitle ?? ''}'.toLowerCase();
        if (!haystack.contains(lower)) continue;
        tracks.add(
          CatalogTrack(
            trackId: t.trackId,
            title: t.title,
            duration: t.durationSeconds,
            artists: [
              CatalogArtist(
                artistId: 'cached:${t.trackId}',
                name: t.artistName,
              ),
            ],
            imageUrl: t.localImagePath ?? t.albumCoverUrl,
          ),
        );
      }

      final cachedAlbums = await trackCache.getAllAlbums();
      for (final a in cachedAlbums) {
        final haystack = '${a.title} ${a.artistName}'.toLowerCase();
        if (!haystack.contains(lower)) continue;
        albums.add(
          CatalogAlbum(
            albumId: a.albumId,
            title: a.title,
            coverUrl: a.localCoverPath ?? a.coverUrl,
            artists: [
              CatalogArtist(
                artistId: 'cached:${a.albumId}',
                name: a.artistName,
              ),
            ],
          ),
        );
      }
    }

    if (detailCache != null) {
      final cachedAlbumDetails = await detailCache.getAllAlbums();
      for (final payload in cachedAlbumDetails) {
        final albumId = payload['album_id']?.toString() ?? '';
        final title = payload['title']?.toString() ?? 'Album';
        final coverUrl = payload['cover_url']?.toString();
        final artistName = _firstArtistName(payload['artists']);
        final haystack = '$title $artistName'.toLowerCase();
        if (!haystack.contains(lower)) continue;
        if (albums.any((a) => a.albumId == albumId)) continue;

        albums.add(
          CatalogAlbum(
            albumId: albumId,
            title: title,
            coverUrl: coverUrl,
            artists: [
              CatalogArtist(artistId: 'cached:$albumId', name: artistName),
            ],
          ),
        );
      }

      final cachedPlaylists = await detailCache.getAllPlaylists();
      for (final payload in cachedPlaylists) {
        final playlistId = payload['playlist_id']?.toString() ??
            payload['id']?.toString() ??
            '';
        final name = payload['name']?.toString() ??
            payload['title']?.toString() ??
            'Playlist';
        final creator = payload['creator_name']?.toString();
        final coverUrl = payload['cover_url']?.toString();
        final haystack = '$name ${creator ?? ''}'.toLowerCase();
        if (!haystack.contains(lower)) continue;

        playlists.add(
          CatalogPlaylist(
            playlistId: playlistId,
            name: name,
            coverUrl: coverUrl,
            creatorName: creator,
          ),
        );
      }
    }

    return CatalogSearchResults(
      tracks: tracks.take(40).toList(),
      albums: albums.take(40).toList(),
      artists: artists,
      playlists: playlists.take(40).toList(),
    );
  }

  String _firstArtistName(dynamic rawArtists) {
    if (rawArtists is! List || rawArtists.isEmpty) return 'Unknown Artist';
    final first = rawArtists.first;
    if (first is Map) {
      return first['name']?.toString() ?? 'Unknown Artist';
    }
    return 'Unknown Artist';
  }

  Future<({
    Set<String> cachedTrackIds,
    Set<String> cachedAlbumIds,
    Set<String> cachedPlaylistIds
  })> _enrichCacheStatus(CatalogSearchResults results) async {
    final cachedTrackIds = <String>{};
    final cachedAlbumIds = <String>{};
    final cachedPlaylistIds = <String>{};

    if (_trackCache != null) {
      final trackCache = _trackCache;
      for (final track in results.tracks) {
        final cached = await trackCache.getTrack(track.trackId);
        if (cached != null) cachedTrackIds.add(track.trackId);
      }

      for (final album in results.albums) {
        final cachedAlbum = await trackCache.getAlbum(album.albumId);
        if (cachedAlbum != null) cachedAlbumIds.add(album.albumId);
      }
    }

    if (_detailCache != null) {
      final detailCache = _detailCache;
      for (final album in results.albums) {
        final cached = await detailCache.getAlbum(album.albumId);
        if (cached != null) cachedAlbumIds.add(album.albumId);
      }

      for (final playlist in results.playlists) {
        final cached = await detailCache.getPlaylist(playlist.playlistId);
        if (cached != null) cachedPlaylistIds.add(playlist.playlistId);
      }
    }

    return (
      cachedTrackIds: cachedTrackIds,
      cachedAlbumIds: cachedAlbumIds,
      cachedPlaylistIds: cachedPlaylistIds,
    );
  }
}

// // Snapshot entry for a search page instance.
// class SearchStackEntry {
//   final String query;
//   final SearchState? state;
//   final DateTime createdAt;

//   SearchStackEntry({required this.query, this.state, DateTime? createdAt})
//     : createdAt = createdAt ?? DateTime.now();
// }

// // State container for SearchStackCubit: keeps ordered stack of pageKeys and a map of entries.
// class SearchStackState {
//   final List<String> stack;
//   final Map<String, SearchStackEntry> entries;

//   SearchStackState({
//     List<String>? stack,
//     Map<String, SearchStackEntry>? entries,
//   }) : stack = stack ?? [],
//        entries = entries ?? {};

//   SearchStackState copyWith({
//     List<String>? stack,
//     Map<String, SearchStackEntry>? entries,
//   }) {
//     return SearchStackState(
//       stack: stack ?? List<String>.from(this.stack),
//       entries: entries ?? Map<String, SearchStackEntry>.from(this.entries),
//     );
//   }
// }

// // Global cubit that manages the search page stack and per-page snapshots.
// class SearchStackCubit extends Cubit<SearchStackState> {
//   SearchStackCubit() : super(SearchStackState());

//   // Push a new page onto the stack and save its initial snapshot.
//   void pushPage(String pageKey, String query, SearchState? searchState) {
//     final newEntries = Map<String, SearchStackEntry>.from(state.entries);
//     newEntries[pageKey] = SearchStackEntry(query: query, state: searchState);
//     final newStack = List<String>.from(state.stack)..add(pageKey);
//     emit(SearchStackState(stack: newStack, entries: newEntries));
//   }

//   // Update an existing page snapshot (for example when typing or receiving results).
//   void updatePage(String pageKey, {String? query, SearchState? searchState}) {
//     final existing = state.entries[pageKey];
//     if (existing == null) return;
//     final updated = SearchStackEntry(
//       query: query ?? existing.query,
//       state: searchState ?? existing.state,
//       createdAt: existing.createdAt,
//     );
//     final newEntries = Map<String, SearchStackEntry>.from(state.entries);
//     newEntries[pageKey] = updated;
//     emit(state.copyWith(entries: newEntries));
//   }

//   // Remove a page from the stack (called when page is popped permanently).
//   void removePage(String pageKey) {
//     if (!state.entries.containsKey(pageKey)) return;
//     final newEntries = Map<String, SearchStackEntry>.from(state.entries);
//     newEntries.remove(pageKey);
//     final newStack = List<String>.from(state.stack)..remove(pageKey);
//     emit(SearchStackState(stack: newStack, entries: newEntries));
//   }

//   SearchStackEntry? getEntry(String pageKey) => state.entries[pageKey];

//   List<String> getStack() => List<String>.from(state.stack);
// }

// // Simple cubit for search - stores results for one query
// class SearchCubit extends Cubit<SearchState> {
//   final String pageId;
//   final String query;
//   final GetVideos getVideos;
//   final GetSuggestions getSuggestions;
//   List<VideoInfo>? _cachedVideos; // Simple cache for videos
//   List<Suggestion>? _cachedSuggestions; // Cache for suggestions

//   SearchCubit(this.pageId, this.query, this.getVideos, this.getSuggestions)
//     : super(SearchInitial());

//   /// Start searching if not already done
//   void searchIfNeeded() {
//     if (kDebugMode) print('SearchCubit.searchIfNeeded() for pageId: $pageId, query: "$query"');
//     if (_cachedVideos != null) {
//       // Already have results, just show them
//       if (kDebugMode) print('  Using cached results: ${_cachedVideos!.length} videos');
//       emit(SearchTestLoaded(query));
//     } else if (query.isNotEmpty) {
//       // Need to search
//       if (kDebugMode) print('  No cache, starting search...');
//       search();
//     } else {
//       if (kDebugMode) print('  Empty query, skipping search');
//     }
//   }

//   Future<void> search() async {
//     if (kDebugMode) print('SearchCubit.search() called for query: "$query"');
//     if (query.trim().isEmpty) {
//       if (kDebugMode) print('  Empty query, returning to initial state');
//       emit(SearchInitial());
//       return;
//     }

//     emit(SearchLoading());

//     try {
//       // Get videos using existing use case
//       final videosResult = await getVideos(query);
//       videosResult.fold(
//         (failure) => {
//           if (kDebugMode) print('  Search failed: ${failure.message}'),
//           emit(SearchTestError('Failed to search: ${failure.message}')),
//         },
//         (videos) {
//           // Cache the results
//           _cachedVideos = videos.take(20).toList();
//           if (kDebugMode) print('  Search successful: ${_cachedVideos!.length} videos cached');
//           emit(SearchTestLoaded(query));
//         },
//       );
//     } catch (e) {
//       if (kDebugMode) print('  Search exception: $e');
//       emit(SearchTestError('Failed to search: $e'));
//     }
//   }

//   /// Clear cache and search again
//   void refresh() {
//     _cachedVideos = null;
//     search();
//   }

//   /// Fetch suggestions for a query
//   Future<void> fetchSuggestions(String suggestionQuery) async {
//     if (kDebugMode) print(
//       'SearchCubit.fetchSuggestions() called for query: "$suggestionQuery"',
//     );
//     if (suggestionQuery.trim().isEmpty) {
//       if (kDebugMode) print('  Empty suggestion query, returning to initial state');
//       emit(SearchInitial());
//       return;
//     }

//     emit(SuggestionLoading());

//     try {
//       final suggestionsResult = await getSuggestions(suggestionQuery);
//       suggestionsResult.fold(
//         (failure) => {
//           if (kDebugMode) print('  Suggestions failed: ${failure.message}'),
//           emit(
//             SuggestionError('Failed to get suggestions: ${failure.message}'),
//           ),
//         },
//         (suggestions) {
//           // Cache the suggestions
//           _cachedSuggestions = suggestions;
//           if (kDebugMode) print(
//             '  Suggestions successful: ${_cachedSuggestions!.length} suggestions cached',
//           );
//           emit(SuggestionLoaded(suggestions));
//         },
//       );
//     } catch (e) {
//       if (kDebugMode) print('  Suggestions exception: $e');
//       emit(SuggestionError('Failed to get suggestions: $e'));
//     }
//   }

//   /// Get cached videos
//   List<VideoInfo>? get cachedVideos => _cachedVideos;

//   /// Get cached suggestions
//   List<Suggestion>? get cachedSuggestions => _cachedSuggestions;
// }

// // /// Simple manager to store one SearchCubit per query
// // /// Each cubit handles exactly one search query and its results
// // class SearchCubitManager {
// //   static final SearchCubitManager _instance = SearchCubitManager._internal();
// //   factory SearchCubitManager() => _instance;
// //   SearchCubitManager._internal();

// //   // Simple map: pageId -> cubit
// //   final Map<String, SearchCubit> _cubits = {};

// //   /// Get existing cubit or create new one for this page
// //   SearchCubit getCubitForPageId(
// //     String pageId,
// //     String query,
// //     GetVideos getVideos,
// //     GetSuggestions getSuggestions,
// //   ) {
// //     if (!_cubits.containsKey(pageId)) {
// //       _cubits[pageId] = SearchCubit(pageId, query, getVideos, getSuggestions);
// //     }
// //     return _cubits[pageId]!;
// //   }

// //   /// Clear all stored cubits
// //   void clearAll() {
// //     for (final cubit in _cubits.values) {
// //       cubit.close();
// //     }
// //     _cubits.clear();
// //   }

// //   /// Debug method to check what's currently cached
// //   void debugPrintCache() {
// //     if (kDebugMode) print('SearchCubitManager Cache:');
// //     for (final entry in _cubits.entries) {
// //       final cubit = entry.value;
// //       if (kDebugMode) print('  PageId: ${entry.key}');
// //       if (kDebugMode) print('    Query: ${cubit.query}');
// //       if (kDebugMode) print('    Has Videos: ${cubit.cachedVideos?.length ?? 0}');
// //       if (kDebugMode) print('    State: ${cubit.state.runtimeType}');
// //     }
// //   }

// //   /// Get total number of cached cubits
// //   int get cacheSize => _cubits.length;
// // }

// // // (duplicate simple snapshot/cubit removed - using SearchStackState and
// // // SearchStackCubit above which provide ordered stack behavior and richer
// // // snapshot handling.)
