import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/listening_history_models.dart';
import '../../data/repositories/listening_history_repository.dart';

part 'listening_history_event.dart';
part 'listening_history_state.dart';

class ListeningHistoryBloc extends Bloc<ListeningHistoryEvent, ListeningHistoryState> {
  final ListeningHistoryRepository repository;
  String? _currentUserId;

  ListeningHistoryBloc({required this.repository}) : super(const ListeningHistoryInitial()) {
    on<LogTrackPlayEvent>(_onLogTrackPlay);
    on<LikeTrackEvent>(_onLikeTrack);
    on<DislikeTrackEvent>(_onDislikeTrack);
    on<ClearTrackPreferenceEvent>(_onClearTrackPreference);
    on<FetchRecommendationsEvent>(_onFetchRecommendations);
    on<FetchListeningStatsEvent>(_onFetchListeningStats);
    on<SaveOnboardingPreferencesEvent>(_onSaveOnboardingPreferences);
    on<FetchOnboardingPreferencesEvent>(_onFetchOnboardingPreferences);
    on<RefreshRecommendationCacheEvent>(_onRefreshRecommendationCache);
  }

  void setUserId(String userId) {
    _currentUserId = userId;
  }

  /// Handle track play logging
  Future<void> _onLogTrackPlay(LogTrackPlayEvent event, Emitter<ListeningHistoryState> emit) async {
    emit(const LoggingTrackPlay());

    try {
      if (_currentUserId == null) {
        emit(const TrackPlayLoggingError('User not authenticated'));
        return;
      }

      final playData = TrackPlayData(
        userId: _currentUserId!,
        trackId: event.trackId,
        timeListenedSeconds: event.timeListenedSeconds,
        totalDurationSeconds: event.totalDurationSeconds,
        completionPercentage: event.completionPercentage,
        wasSkipped: event.wasSkipped,
        skipAtSeconds: event.skipAtSeconds,
        listeningContext: event.listeningContext ?? 'library',
        contextId: event.contextId,
      );

      repository.logTrackPlay(playData);
      emit(const TrackPlayLogged());
    } catch (e) {
      emit(TrackPlayLoggingError(_getErrorMessage(e)));
    }
  }

  /// Handle liking a track
  Future<void> _onLikeTrack(LikeTrackEvent event, Emitter<ListeningHistoryState> emit) async {
    emit(const UpdatingPreference());

    try {
      await repository.likeTrack(event.trackId, mood: event.mood);
      emit(const PreferenceUpdated());
      
      // Invalidate recommendation cache when preference changes
      add(const RefreshRecommendationCacheEvent());
    } catch (e) {
      emit(PreferenceUpdateError(_getErrorMessage(e)));
    }
  }

  /// Handle disliking a track
  Future<void> _onDislikeTrack(DislikeTrackEvent event, Emitter<ListeningHistoryState> emit) async {
    emit(const UpdatingPreference());

    try {
      await repository.dislikeTrack(event.trackId);
      emit(const PreferenceUpdated());
      
      // Invalidate recommendation cache
      add(const RefreshRecommendationCacheEvent());
    } catch (e) {
      emit(PreferenceUpdateError(_getErrorMessage(e)));
    }
  }

  /// Handle clearing track preference
  Future<void> _onClearTrackPreference(
    ClearTrackPreferenceEvent event,
    Emitter<ListeningHistoryState> emit,
  ) async {
    emit(const UpdatingPreference());

    try {
      await repository.clearTrackPreference(event.trackId);
      emit(const PreferenceUpdated());
    } catch (e) {
      emit(PreferenceUpdateError(_getErrorMessage(e)));
    }
  }

  /// Handle fetching recommendations
  Future<void> _onFetchRecommendations(
    FetchRecommendationsEvent event,
    Emitter<ListeningHistoryState> emit,
  ) async {
    emit(const FetchingRecommendations());

    try {
      final recommendation = await repository.getRecommendations(
        limit: event.limit,
        type: event.type,
        includeReasons: event.includeReasons,
      );

      emit(RecommendationsLoaded(
        recommendation: recommendation,
        isCached: recommendation.fromCache,
      ));
    } catch (e) {
      emit(RecommendationsError(_getErrorMessage(e)));
    }
  }

  /// Handle fetching listening stats
  Future<void> _onFetchListeningStats(
    FetchListeningStatsEvent event,
    Emitter<ListeningHistoryState> emit,
  ) async {
    emit(const FetchingListeningStats());

    try {
      final stats = await repository.getListeningStats();
      emit(ListeningStatsLoaded(stats));
    } catch (e) {
      emit(ListeningStatsError(_getErrorMessage(e)));
    }
  }

  /// Handle saving onboarding preferences
  Future<void> _onSaveOnboardingPreferences(
    SaveOnboardingPreferencesEvent event,
    Emitter<ListeningHistoryState> emit,
  ) async {
    emit(const SavingOnboardingPreferences());

    try {
      await repository.saveOnboardingPreferences(event.preferences);
      emit(const OnboardingPreferencesSaved());
    } catch (e) {
      emit(PreferenceUpdateError(_getErrorMessage(e)));
    }
  }

  /// Handle fetching onboarding preferences
  Future<void> _onFetchOnboardingPreferences(
    FetchOnboardingPreferencesEvent event,
    Emitter<ListeningHistoryState> emit,
  ) async {
    emit(const FetchingOnboardingPreferences());

    try {
      final preferences = await repository.getOnboardingPreferences();
      emit(OnboardingPreferencesLoaded(preferences));
    } catch (e) {
      emit(OnboardingPreferencesError(_getErrorMessage(e)));
    }
  }

  /// Handle cache refresh (for internal use)
  Future<void> _onRefreshRecommendationCache(
    RefreshRecommendationCacheEvent event,
    Emitter<ListeningHistoryState> emit,
  ) async {
    // Silently clear old state to allow new fetch
    // This doesn't emit a new state, just invalidates cache via backend API
    try {
      // Backend will make system delete the cache automatically
      // when next recommendation request comes in
      // No action needed on client side
    } catch (e) {
      // Ignore cache refresh errors
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      String msg = error.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      return msg;
    }
    return 'An unknown error occurred';
  }
}
