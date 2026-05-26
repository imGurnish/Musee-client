import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/error/app_errors.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:musee/features/user__dashboard/data/services/user_dashboard_cache_service.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_albums_for_you.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_made_for_you.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_trending.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'dart:math';

class UserDashboardState extends Equatable {
  final bool loadingMadeForYou;
  final bool loadingTrending;
  final bool loadingAlbumsForYou;
  final bool hasRetryableError;
  final List<DashboardItem> madeForYou;
  final List<DashboardItem> trending;
  final List<DashboardItem> albumsForYou;
  final String? errorMadeForYou;
  final String? errorTrending;
  final String? errorAlbumsForYou;

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
    this.hasRetryableError = false,
    this.madeForYou = const [],
    this.trending = const [],
    this.albumsForYou = const [],
    this.errorMadeForYou,
    this.errorTrending,
    this.errorAlbumsForYou,
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
    bool? hasRetryableError,
    List<DashboardItem>? madeForYou,
    List<DashboardItem>? trending,
    List<DashboardItem>? albumsForYou,
    String? errorMadeForYou,
    String? errorTrending,
    String? errorAlbumsForYou,
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
      hasRetryableError: hasRetryableError ?? this.hasRetryableError,
      madeForYou: madeForYou ?? this.madeForYou,
      trending: trending ?? this.trending,
      albumsForYou: albumsForYou ?? this.albumsForYou,
      errorMadeForYou: errorMadeForYou,
      errorTrending: errorTrending,
      errorAlbumsForYou: errorAlbumsForYou,
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
    hasRetryableError,
    madeForYou,
    trending,
    albumsForYou,
    errorMadeForYou,
    errorTrending,
    errorAlbumsForYou,
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
  final TrackCacheService? _trackCache;
  final UserDashboardCacheService? _dashboardCache;

  UserDashboardCubit(
    this._listMadeForYou,
    this._listAlbumsForYou,
    this._listTrending, {
    TrackCacheService? trackCache,
    UserDashboardCacheService? dashboardCache,
  }) : _trackCache = trackCache,
       _dashboardCache = dashboardCache,
       super(const UserDashboardState());

  Future<void> load({
    int page = 0,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final usePersistentCache = !forceRefresh && _dashboardCache != null;

    emit(
      state.copyWith(
        loadingMadeForYou: !usePersistentCache,
        loadingTrending: !usePersistentCache,
        loadingAlbumsForYou: true,
        hasRetryableError: false,
        errorMadeForYou: null,
        errorTrending: null,
        errorAlbumsForYou: null,
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

    List<DashboardItem>? trending;
    String? trendingError;
    if (usePersistentCache) {
      try {
        trending = await _dashboardCache.getTrending(
          page: page,
          limit: limit,
          ttl: _madeForYouCacheTtl,
        );
      } catch (_) {
        trending = null;
      }
    }

    if (trending == null) {
      try {
        final trendingResult = await _listTrending(page: page, limit: limit);
        trending = trendingResult.items;
        await _dashboardCache?.cacheTrending(
          page: page,
          limit: limit,
          items: trending,
        );
      } catch (e) {
        final appError = e.toAppError();
        trendingError = appError.userMessage;
        hasRetryableError = hasRetryableError || appError.isRetryable;
      }
    }

    List<DashboardItem>? albumsForYou;
    String? albumsForYouError;
    try {
      final albumsResult = await _listAlbumsForYou(page: page, limit: limit);
      albumsForYou = albumsResult.items
          .where((item) => item.type == DashboardItemType.album)
          .toList();
    } catch (e) {
      final appError = e.toAppError();
      albumsForYouError = appError.userMessage;
      hasRetryableError = hasRetryableError || appError.isRetryable;
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
    final decoratedTrending = await _decorateWithCacheState(
      trending ?? state.trending,
    );

    final mixedMadeForYou = _mixMadeForYouWithRecommendations(
      decoratedMadeForYou,
      state.recommendations,
    );

    emit(
      state.copyWith(
        loadingMadeForYou: false,
        loadingTrending: false,
        loadingAlbumsForYou: false,
        hasRetryableError: hasRetryableError,
        madeForYou: mixedMadeForYou.isNotEmpty
            ? mixedMadeForYou
            : decoratedMadeForYou,
        trending: decoratedTrending,
        albumsForYou: await _decorateWithCacheState(
          albumsForYou ?? state.albumsForYou,
        ),
        errorMadeForYou: madeForYouError,
        errorTrending: trendingError,
        errorAlbumsForYou: albumsForYouError,
      ),
    );
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
    if (_trackCache == null) return;

    try {
      final recentlyPlayed = await _trackCache.getRecentlyPlayed(limit: 10);
      final mostPlayed = await _trackCache.getMostPlayed(limit: 10);

      emit(
        state.copyWith(recentlyPlayed: recentlyPlayed, mostPlayed: mostPlayed),
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
