import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_made_for_you.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_trending.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';

class UserDashboardState extends Equatable {
  final bool loadingMadeForYou;
  final bool loadingTrending;
  final List<DashboardItem> madeForYou;
  final List<DashboardItem> trending;
  final String? errorMadeForYou;
  final String? errorTrending;

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
    this.madeForYou = const [],
    this.trending = const [],
    this.errorMadeForYou,
    this.errorTrending,
    this.recentlyPlayed = const [],
    this.mostPlayed = const [],
    this.lastUpdated,
    this.recommendations = const [],
    this.recommendationTitle,
  });

  UserDashboardState copyWith({
    bool? loadingMadeForYou,
    bool? loadingTrending,
    List<DashboardItem>? madeForYou,
    List<DashboardItem>? trending,
    String? errorMadeForYou,
    String? errorTrending,
    List<CachedTrack>? recentlyPlayed,
    List<CachedTrack>? mostPlayed,
    DateTime? lastUpdated,
    List<DashboardItem>? recommendations,
    String? recommendationTitle,
  }) {
    return UserDashboardState(
      loadingMadeForYou: loadingMadeForYou ?? this.loadingMadeForYou,
      loadingTrending: loadingTrending ?? this.loadingTrending,
      madeForYou: madeForYou ?? this.madeForYou,
      trending: trending ?? this.trending,
      errorMadeForYou: errorMadeForYou,
      errorTrending: errorTrending,
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
    madeForYou,
    trending,
    errorMadeForYou,
    errorTrending,
    recentlyPlayed,
    mostPlayed,
    lastUpdated,
    recommendations,
    recommendationTitle,
  ];
}

class UserDashboardCubit extends Cubit<UserDashboardState> {
  final ListMadeForYou _listMadeForYou;
  final ListTrending _listTrending;
  final TrackCacheService? _trackCache;
  final MusicProviderRegistry? _musicProviderRegistry;

  UserDashboardCubit(
    this._listMadeForYou,
    this._listTrending, {
    TrackCacheService? trackCache,
    MusicProviderRegistry? musicProviderRegistry,
  }) : _trackCache = trackCache,
       _musicProviderRegistry = musicProviderRegistry,
       super(const UserDashboardState());

  Future<void> load({int page = 0, int limit = 20}) async {
    emit(
      state.copyWith(
        loadingMadeForYou: true,
        loadingTrending: true,
        errorMadeForYou: null,
        errorTrending: null,
      ),
    );

    // Load from cache first (instant display)
    await _loadFromCache();

    try {
      final results = await Future.wait([
        _listMadeForYou(page: page, limit: limit),
        _listTrending(page: page, limit: limit),
      ]);

      final madeForYouItems = results[0].items;
      final trending = results[1].items;
      final recommendations = state.recommendations;

      // Merge recommendations into madeForYou (deduplicated)
      final mergedItems = <DashboardItem>[];
      final seenIds = <String>{};

      void addUnique(DashboardItem item) {
        if (!seenIds.contains(item.id)) {
          seenIds.add(item.id);
          mergedItems.add(item);
        }
      }

      // Interleave: [Recommendation, MadeForYou, ...]
      final maxLen = recommendations.length > madeForYouItems.length
          ? recommendations.length
          : madeForYouItems.length;

      for (var i = 0; i < maxLen; i++) {
        if (i < recommendations.length) addUnique(recommendations[i]);
        if (i < madeForYouItems.length) addUnique(madeForYouItems[i]);
      }

      emit(
        state.copyWith(
          loadingMadeForYou: false,
          loadingTrending: false,
          madeForYou: mergedItems.isNotEmpty ? mergedItems : madeForYouItems,
          trending: trending,
          errorMadeForYou: null,
          errorTrending: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingMadeForYou: false,
          loadingTrending: false,
          errorMadeForYou: e.toString(),
          errorTrending: e.toString(),
        ),
      );
    }
  }

  Future<void> _loadFromCache() async {
    if (_trackCache == null) return;

    try {
      final recentlyPlayed = await _trackCache.getRecentlyPlayed(limit: 10);
      final mostPlayed = await _trackCache.getMostPlayed(limit: 10);

      emit(
        state.copyWith(recentlyPlayed: recentlyPlayed, mostPlayed: mostPlayed),
      );

      await _generateRecommendations(recentlyPlayed);
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
      // Update recommendations based on new history
      await _generateRecommendations(recentlyPlayed);
    } catch (_) {}
  }

  Future<void> _generateRecommendations(List<CachedTrack> history) async {
    if (_musicProviderRegistry == null || history.isEmpty) return;

    // Find most frequent artist
    final artistCounts = <String, int>{};
    for (final track in history) {
      final artist = track.artistName;
      if (artist.isNotEmpty && artist != 'Unknown Artist') {
        // Handle comma separated artists, take first
        final primary = artist.split(',').first.trim();
        if (primary.isNotEmpty) {
          artistCounts[primary] = (artistCounts[primary] ?? 0) + 1;
        }
      }
    }

    if (artistCounts.isEmpty) return;

    // Sort by count desc
    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bestArtistName = sortedArtists.first.key;

    try {
      // Search for this artist (External provider usually gives best variety)
      final results = await _musicProviderRegistry.search(
        bestArtistName,
        limitPerProvider: 5,
      );

      // Filter out tracks already in recently played
      final historyTitles = history.map((e) => e.title.toLowerCase()).toSet();

      final items = <DashboardItem>[];

      // Prefer tracks from search results
      for (final track in results.tracks) {
        if (historyTitles.contains(track.title.toLowerCase())) continue;

        items.add(
          DashboardItem(
            id: track.prefixedId,
            trackId: track.prefixedId,
            albumId: track.albumId,
            title: track.title,
            coverUrl: track.imageUrl,
            duration: track.durationSeconds,
            artists: track.artists
                .map(
                  (a) => DashboardArtist(artistId: a.prefixedId, name: a.name),
                )
                .toList(),
            type: DashboardItemType.track,
          ),
        );
      }

      // Also maybe albums?
      for (final album in results.albums) {
        items.add(
          DashboardItem(
            id: album.prefixedId,
            albumId: album.prefixedId,
            title: album.title,
            coverUrl: album.coverUrl,
            duration: null,
            artists: album.artists
                .map(
                  (a) => DashboardArtist(artistId: a.prefixedId, name: a.name),
                )
                .toList(),
            type: DashboardItemType.album,
          ),
        );
      }

      // Shuffle/Interleave or just take tracks first
      // Let's take top 10 items
      if (items.isNotEmpty) {
        emit(
          state.copyWith(
            recommendations: items.take(10).toList(),
            recommendationTitle: 'Because you listen to $bestArtistName',
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }
}
