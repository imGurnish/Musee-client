import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  ];
}

class UserDashboardCubit extends Cubit<UserDashboardState> {
  final ListMadeForYou _listMadeForYou;
  final ListTrending _listTrending;
  final TrackCacheService? _trackCache;

  UserDashboardCubit(
    this._listMadeForYou,
    this._listTrending, {
    TrackCacheService? trackCache,
  }) : _trackCache = trackCache,
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
      emit(
        state.copyWith(
          loadingMadeForYou: false,
          loadingTrending: false,
          madeForYou: results[0].items,
          trending: results[1].items,
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
}
