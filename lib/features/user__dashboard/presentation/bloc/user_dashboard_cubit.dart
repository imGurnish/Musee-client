import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/error/app_errors.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:musee/features/user__dashboard/data/services/user_dashboard_cache_service.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_albums_for_you.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_made_for_you.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_trending.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_undiscovered_gems.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'dart:math';

class UserDashboardState extends Equatable {
  final bool loadingMadeForYou;
  final bool loadingTrending;
  final bool loadingAlbumsForYou;
  final bool loadingUndiscoveredGems;
  final bool loadingInfiniteSuggestedTracks;
  final bool hasRetryableError;
  final List<DashboardItem> madeForYou;
  final List<DashboardItem> trending;
  final List<DashboardItem> albumsForYou;
  final List<DashboardItem> undiscoveredGems;
  final List<DashboardItem> infiniteSuggestedTracks;
  final String? errorMadeForYou;
  final String? errorTrending;
  final String? errorAlbumsForYou;
  final String? errorUndiscoveredGems;

  /// Recently played tracks from local cache
  final List<CachedTrack> recentlyPlayed;

  /// Most played tracks from local cache (for recommendations)
  final List<CachedTrack> mostPlayed;

  /// Timestamp to force state updates even if list content references are same
  final DateTime? lastUpdated;

  /// Recommended tracks based on user history
  final List<DashboardItem> recommendations;
  final String? recommendationTitle;

  const UserDashboardState({
    this.loadingMadeForYou = false,
    this.loadingTrending = false,
    this.loadingAlbumsForYou = false,
    this.loadingUndiscoveredGems = false,
    this.loadingInfiniteSuggestedTracks = false,
    this.hasRetryableError = false,
    this.madeForYou = const [],
    this.trending = const [],
    this.albumsForYou = const [],
    this.undiscoveredGems = const [],
    this.infiniteSuggestedTracks = const [],
    this.errorMadeForYou,
    this.errorTrending,
    this.errorAlbumsForYou,
    this.errorUndiscoveredGems,
    this.recentlyPlayed = const [],
    this.mostPlayed = const [],
    this.lastUpdated,
    this.recommendations = const [],
    this.recommendationTitle,
  });

  UserDashboardState copyWith({
    bool? loadingMadeForYou,
    bool? loadingTrending,
    bool? loadingAlbumsForYou,
    bool? loadingUndiscoveredGems,
    bool? loadingInfiniteSuggestedTracks,
    bool? hasRetryableError,
    List<DashboardItem>? madeForYou,
    List<DashboardItem>? trending,
    List<DashboardItem>? albumsForYou,
    List<DashboardItem>? undiscoveredGems,
    List<DashboardItem>? infiniteSuggestedTracks,
    String? errorMadeForYou,
    String? errorTrending,
    String? errorAlbumsForYou,
    String? errorUndiscoveredGems,
    List<CachedTrack>? recentlyPlayed,
    List<CachedTrack>? mostPlayed,
    DateTime? lastUpdated,
    List<DashboardItem>? recommendations,
    String? recommendationTitle,
  }) {
    return UserDashboardState(
      loadingMadeForYou: loadingMadeForYou ?? this.loadingMadeForYou,
      loadingTrending: loadingTrending ?? this.loadingTrending,
      loadingAlbumsForYou: loadingAlbumsForYou ?? this.loadingAlbumsForYou,
      loadingUndiscoveredGems:
          loadingUndiscoveredGems ?? this.loadingUndiscoveredGems,
      loadingInfiniteSuggestedTracks:
          loadingInfiniteSuggestedTracks ?? this.loadingInfiniteSuggestedTracks,
      hasRetryableError: hasRetryableError ?? this.hasRetryableError,
      madeForYou: madeForYou ?? this.madeForYou,
      trending: trending ?? this.trending,
      albumsForYou: albumsForYou ?? this.albumsForYou,
      undiscoveredGems: undiscoveredGems ?? this.undiscoveredGems,
      infiniteSuggestedTracks:
          infiniteSuggestedTracks ?? this.infiniteSuggestedTracks,
      errorMadeForYou: errorMadeForYou,
      errorTrending: errorTrending,
      errorAlbumsForYou: errorAlbumsForYou,
      errorUndiscoveredGems: errorUndiscoveredGems,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      mostPlayed: mostPlayed ?? this.mostPlayed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      recommendations: recommendations ?? this.recommendations,
      recommendationTitle: recommendationTitle ?? this.recommendationTitle,
    );
  }

  @override
  List<Object?> get props => [
    loadingMadeForYou,
    loadingTrending,
    loadingAlbumsForYou,
    loadingUndiscoveredGems,
    loadingInfiniteSuggestedTracks,
    hasRetryableError,
    madeForYou,
    trending,
    albumsForYou,
    undiscoveredGems,
    infiniteSuggestedTracks,
    errorMadeForYou,
    errorTrending,
    errorAlbumsForYou,
    errorUndiscoveredGems,
    recentlyPlayed,
    mostPlayed,
    lastUpdated,
    recommendations,
    recommendationTitle,
  ];
}

class UserDashboardCubit extends Cubit<UserDashboardState> {
  static const Duration _madeForYouCacheTtl = Duration(minutes: 30);

  final ListMadeForYou _listMadeForYou;
  final ListAlbumsForYou _listAlbumsForYou;
  final ListTrending _listTrending;
  final ListUndiscoveredGems _listUndiscoveredGems;
  final TrackCacheService? _trackCache;
  final UserDashboardCacheService? _dashboardCache;

  int _loadedSectionIndex = 1;
  int _infiniteSuggestedTracksPage = 0;
  bool _hasReachedInfiniteEnd = false;

  int get loadedSectionIndex => _loadedSectionIndex;

  UserDashboardCubit(
    this._listMadeForYou,
    this._listAlbumsForYou,
    this._listTrending,
    this._listUndiscoveredGems, {
    TrackCacheService? trackCache,
    UserDashboardCacheService? dashboardCache,
  }) : _trackCache = trackCache,
       _dashboardCache = dashboardCache,
       super(const UserDashboardState());

  Future<void> load({
    int page = 0,
    int limit = 72,
    bool forceRefresh = false,
  }) async {
    final usePersistentCache = !forceRefresh && _dashboardCache != null;

    _loadedSectionIndex = 1;
    _infiniteSuggestedTracksPage = 0;
    _hasReachedInfiniteEnd = false;

    if (forceRefresh && _dashboardCache != null) {
      try {
        await _dashboardCache.clearMadeForYou();
        await _dashboardCache.clearTrending();
        await _dashboardCache.clearAlbumsForYou();
        await _dashboardCache.clearUndiscoveredGems();
      } catch (_) {}
    }

    emit(
      state.copyWith(
        loadingMadeForYou: !usePersistentCache,
        loadingTrending: false,
        loadingAlbumsForYou: false,
        loadingUndiscoveredGems: false,
        loadingInfiniteSuggestedTracks: false,
        hasRetryableError: false,
        errorMadeForYou: null,
        errorTrending: null,
        errorAlbumsForYou: null,
        errorUndiscoveredGems: null,
        madeForYou: forceRefresh ? const [] : state.madeForYou,
        trending: forceRefresh ? const [] : state.trending,
        albumsForYou: forceRefresh ? const [] : state.albumsForYou,
        undiscoveredGems: forceRefresh ? const [] : state.undiscoveredGems,
        infiniteSuggestedTracks: const [],
      ),
    );

    // Load from cache first (instant display)
    await _loadFromCache();

    List<DashboardItem>? backendMadeForYou;
    String? madeForYouError;
    bool hasRetryableError = false;

    if (usePersistentCache) {
      try {
        backendMadeForYou = await _dashboardCache.getMadeForYou(
          page: page,
          limit: limit,
          ttl: _madeForYouCacheTtl,
        );
      } catch (_) {
        backendMadeForYou = null;
      }
    }

    if (backendMadeForYou == null) {
      try {
        final madeForYouResult = await _listMadeForYou(
          page: page,
          limit: limit,
        );
        backendMadeForYou = madeForYouResult.items;
        await _dashboardCache?.cacheMadeForYou(
          page: page,
          limit: limit,
          items: backendMadeForYou,
        );
      } catch (e) {
        final appError = e.toAppError();
        madeForYouError = appError.userMessage;
        hasRetryableError = hasRetryableError || appError.isRetryable;
      }
    }

    final effectiveBackendMadeForYou =
        backendMadeForYou ??
        state.madeForYou.where((item) {
          return item.type == DashboardItemType.track ||
              item.type == DashboardItemType.album ||
              item.type == DashboardItemType.playlist;
        }).toList();

    final decoratedMadeForYou = await _decorateWithCacheState(
      effectiveBackendMadeForYou,
    );

    final mixedMadeForYou = _mixMadeForYouWithRecommendations(
      decoratedMadeForYou,
      state.recommendations,
    );

    emit(
      state.copyWith(
        loadingMadeForYou: false,
        hasRetryableError: hasRetryableError,
        madeForYou: mixedMadeForYou.isNotEmpty
            ? mixedMadeForYou
            : decoratedMadeForYou,
        errorMadeForYou: madeForYouError,
      ),
    );
  }

  Future<void> loadNextSection() async {
    if (state.loadingMadeForYou ||
        state.loadingTrending ||
        state.loadingAlbumsForYou ||
        state.loadingUndiscoveredGems ||
        state.loadingInfiniteSuggestedTracks) {
      return; // Already loading a section
    }

    if (_loadedSectionIndex == 1) {
      // Load Section 2: Trending Picks
      emit(state.copyWith(
        loadingTrending: true,
        errorTrending: null,
      ));
      try {
        final trendingResult = await _listTrending(page: 0, limit: 60);
        final decoratedTrending = await _decorateWithCacheState(
          trendingResult.items,
        );
        await _dashboardCache?.cacheTrending(
          page: 0,
          limit: 60,
          items: decoratedTrending,
        );
        _loadedSectionIndex = 2;
        emit(state.copyWith(
          loadingTrending: false,
          trending: decoratedTrending,
        ));
      } catch (e) {
        final appError = e.toAppError();
        emit(state.copyWith(
          loadingTrending: false,
          errorTrending: state.trending.isEmpty ? appError.userMessage : null,
          hasRetryableError: appError.isRetryable,
        ));
      }
    } else if (_loadedSectionIndex == 2) {
      // Load Section 3: Albums For You
      emit(state.copyWith(
        loadingAlbumsForYou: true,
        errorAlbumsForYou: null,
      ));
      try {
        final albumsResult = await _listAlbumsForYou(page: 0, limit: 30);
        final albums = albumsResult.items
            .where((item) => item.type == DashboardItemType.album)
            .toList();
        final decoratedAlbums = await _decorateWithCacheState(albums);
        await _dashboardCache?.cacheAlbumsForYou(
          page: 0,
          limit: 30,
          items: decoratedAlbums,
        );
        _loadedSectionIndex = 3;
        emit(state.copyWith(
          loadingAlbumsForYou: false,
          albumsForYou: decoratedAlbums,
        ));
      } catch (e) {
        final appError = e.toAppError();
        emit(state.copyWith(
          loadingAlbumsForYou: false,
          errorAlbumsForYou:
              state.albumsForYou.isEmpty ? appError.userMessage : null,
          hasRetryableError: appError.isRetryable,
        ));
      }
    } else if (_loadedSectionIndex == 3) {
      // Section 4 (Playlists & Artists) are derived from the already loaded State list items!
      // No server API request is required. We advance loaded index immediately and trigger next section loading (Section 5).
      _loadedSectionIndex = 4;
      await loadNextSection();
    } else if (_loadedSectionIndex == 4) {
      // Load Section 5: Undiscovered Gems
      emit(state.copyWith(
        loadingUndiscoveredGems: true,
        errorUndiscoveredGems: null,
      ));
      try {
        final undiscoveredGemsResult = await _listUndiscoveredGems(
          page: 0,
          limit: 30,
        );
        final decoratedGems = await _decorateWithCacheState(
          undiscoveredGemsResult.items,
        );
        await _dashboardCache?.cacheUndiscoveredGems(
          page: 0,
          limit: 30,
          items: decoratedGems,
        );
        _loadedSectionIndex = 5;
        emit(state.copyWith(
          loadingUndiscoveredGems: false,
          undiscoveredGems: decoratedGems,
        ));
      } catch (e) {
        final appError = e.toAppError();
        emit(state.copyWith(
          loadingUndiscoveredGems: false,
          errorUndiscoveredGems:
              state.undiscoveredGems.isEmpty ? appError.userMessage : null,
          hasRetryableError: appError.isRetryable,
        ));
      }
    } else if (_loadedSectionIndex == 5) {
      _loadedSectionIndex = 6;
      await loadMoreSuggestedTracks();
    }
  }

  Future<void> loadMoreSuggestedTracks() async {
    if (state.loadingInfiniteSuggestedTracks || _hasReachedInfiniteEnd) return;

    emit(state.copyWith(loadingInfiniteSuggestedTracks: true));
    try {
      final items = await fetchSuggestedTracks(
        page: _infiniteSuggestedTracksPage,
        limit: 20,
      );
      _infiniteSuggestedTracksPage++;

      if (items.isEmpty) {
        _hasReachedInfiniteEnd = true;
      } else {
        final currentList = List<DashboardItem>.from(
          state.infiniteSuggestedTracks,
        );
        final seenIds = currentList.map((i) => i.id).toSet();
        final newItems = items.where((i) => seenIds.add(i.id)).toList();

        if (newItems.isEmpty && items.length < 20) {
          _hasReachedInfiniteEnd = true;
        }

        emit(
          state.copyWith(
            infiniteSuggestedTracks: [...currentList, ...newItems],
          ),
        );
      }
    } catch (_) {
      // Non-fatal infinite scroll errors, just let it allow retry on next scroll trigger
    } finally {
      emit(state.copyWith(loadingInfiniteSuggestedTracks: false));
    }
  }

  Future<List<DashboardItem>> _decorateWithCacheState(
    List<DashboardItem> items,
  ) async {
    if (_trackCache == null || items.isEmpty) return items;

    final output = <DashboardItem>[];
    for (final item in items) {
      switch (item.type) {
        case DashboardItemType.track:
          final trackId = item.trackId ?? item.id;
          final cachedTrack = await _trackCache.getTrack(trackId);
          output.add(
            item.copyWith(
              isCached: cachedTrack != null,
              localImagePath: cachedTrack?.localImagePath,
            ),
          );
          break;
        case DashboardItemType.album:
          final albumId = item.albumId ?? item.id;
          final cachedAlbum = await _trackCache.getAlbum(albumId);
          output.add(
            item.copyWith(
              isCached: cachedAlbum != null,
              localImagePath: cachedAlbum?.localCoverPath,
            ),
          );
          break;
        case DashboardItemType.playlist:
          output.add(item.copyWith(isCached: false));
          break;
      }
    }

    return output;
  }

  List<DashboardItem> _mixMadeForYouWithRecommendations(
    List<DashboardItem> backendMadeForYou,
    List<DashboardItem> recommendations,
  ) {
    final mixedMadeForYou = <DashboardItem>[];
    final seenIds = <String>{};

    void addUnique(DashboardItem item) {
      if (!seenIds.contains(item.id)) {
        seenIds.add(item.id);
        mixedMadeForYou.add(item);
      }
    }

    final maxLen = recommendations.length > backendMadeForYou.length
        ? recommendations.length
        : backendMadeForYou.length;

    for (var i = 0; i < maxLen; i++) {
      if (i < recommendations.length) addUnique(recommendations[i]);
      if (i < backendMadeForYou.length) addUnique(backendMadeForYou[i]);
    }

    mixedMadeForYou.shuffle(Random());
    return mixedMadeForYou;
  }

  Future<void> _loadFromCache() async {
    try {
      final recentlyPlayed =
          _trackCache != null
              ? await _trackCache.getRecentlyPlayed(limit: 10)
              : const <CachedTrack>[];
      final mostPlayed =
          _trackCache != null
              ? await _trackCache.getMostPlayed(limit: 10)
              : const <CachedTrack>[];

      List<DashboardItem> cachedMadeForYou = const [];
      List<DashboardItem> cachedTrending = const [];
      List<DashboardItem> cachedAlbums = const [];
      List<DashboardItem> cachedUndiscovered = const [];

      if (_dashboardCache != null) {
        cachedMadeForYou =
            await _dashboardCache.getMadeForYou(
              page: 0,
              limit: 72,
              ttl: _madeForYouCacheTtl,
            ) ??
            const [];

        cachedTrending =
            await _dashboardCache.getTrending(
              page: 0,
              limit: 60,
              ttl: _madeForYouCacheTtl,
            ) ??
            const [];

        cachedAlbums =
            await _dashboardCache.getAlbumsForYou(
              page: 0,
              limit: 30,
              ttl: _madeForYouCacheTtl,
            ) ??
            const [];

        cachedUndiscovered =
            await _dashboardCache.getUndiscoveredGems(
              page: 0,
              limit: 30,
              ttl: _madeForYouCacheTtl,
            ) ??
            const [];
      }

      emit(
        state.copyWith(
          recentlyPlayed: recentlyPlayed,
          mostPlayed: mostPlayed,
          madeForYou: cachedMadeForYou,
          trending: cachedTrending,
          albumsForYou: cachedAlbums,
          undiscoveredGems: cachedUndiscovered,
        ),
      );
    } catch (_) {
      // Cache errors are non-fatal, just continue
    }
  }

  /// Refresh recently played from cache (call after playing a track)
  Future<void> refreshRecentlyPlayed() async {
    if (_trackCache == null) return;

    try {
      final recentlyPlayed = await _trackCache.getRecentlyPlayed(limit: 10);
      emit(
        state.copyWith(
          recentlyPlayed: recentlyPlayed,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  Future<List<DashboardItem>> fetchSuggestedTracks({
    int page = 0,
    int limit = 50,
  }) async {
    List<DashboardItem> madeForYouTracks = const [];
    List<DashboardItem> trendingTracks = const [];

    try {
      final result = await _listMadeForYou(page: page, limit: limit);
      madeForYouTracks = result.items
          .where((item) => item.type == DashboardItemType.track)
          .toList();
    } catch (_) {}

    try {
      final result = await _listTrending(page: page, limit: limit);
      trendingTracks = result.items
          .where((item) => item.type == DashboardItemType.track)
          .toList();
    } catch (_) {}

    final combined = <DashboardItem>[
      ...state.recommendations.where(
        (item) => item.type == DashboardItemType.track,
      ),
      ...state.trending.where((item) => item.type == DashboardItemType.track),
      ...state.madeForYou.where((item) => item.type == DashboardItemType.track),
      ...trendingTracks,
      ...madeForYouTracks,
    ];

    final seen = <String>{};
    final unique = <DashboardItem>[];
    for (final item in combined) {
      final key = item.trackId ?? item.id;
      if (seen.add(key)) {
        unique.add(item);
      }
    }

    return _decorateWithCacheState(unique);
  }

  Future<List<DashboardItem>> fetchAlbumsForYou({
    int page = 0,
    int limit = 50,
  }) async {
    try {
      final result = await _listAlbumsForYou(page: page, limit: limit);
      final albums = result.items
          .where((item) => item.type == DashboardItemType.album)
          .toList();

      final combined = <DashboardItem>[...state.albumsForYou, ...albums];

      final seen = <String>{};
      final unique = <DashboardItem>[];
      for (final item in combined) {
        final key = item.albumId ?? item.id;
        if (seen.add(key)) {
          unique.add(item);
        }
      }

      return _decorateWithCacheState(unique);
    } catch (_) {
      return _decorateWithCacheState(state.albumsForYou);
    }
  }

  Future<bool> pingBackend() async {
    try {
      await _listTrending(page: 0, limit: 1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
