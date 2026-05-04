part of 'listening_history_bloc.dart';

abstract class ListeningHistoryState extends Equatable {
  const ListeningHistoryState();

  @override
  List<Object?> get props => [];
}

class ListeningHistoryInitial extends ListeningHistoryState {
  const ListeningHistoryInitial();
}

/// Track play logging states
class LoggingTrackPlay extends ListeningHistoryState {
  const LoggingTrackPlay();
}

class TrackPlayLogged extends ListeningHistoryState {
  const TrackPlayLogged();
}

class TrackPlayLoggingError extends ListeningHistoryState {
  final String message;

  const TrackPlayLoggingError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Preference update states
class UpdatingPreference extends ListeningHistoryState {
  const UpdatingPreference();
}

class PreferenceUpdated extends ListeningHistoryState {
  const PreferenceUpdated();
}

class PreferenceUpdateError extends ListeningHistoryState {
  final String message;

  const PreferenceUpdateError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Recommendations states
class FetchingRecommendations extends ListeningHistoryState {
  const FetchingRecommendations();
}

class RecommendationsLoaded extends ListeningHistoryState {
  final Recommendation recommendation;
  final bool isCached;

  const RecommendationsLoaded({
    required this.recommendation,
    this.isCached = false,
  });

  @override
  List<Object?> get props => [recommendation, isCached];
}

class RecommendationsError extends ListeningHistoryState {
  final String message;

  const RecommendationsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Listening stats states
class FetchingListeningStats extends ListeningHistoryState {
  const FetchingListeningStats();
}

class ListeningStatsLoaded extends ListeningHistoryState {
  final ListeningStats stats;

  const ListeningStatsLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class ListeningStatsError extends ListeningHistoryState {
  final String message;

  const ListeningStatsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Onboarding preferences states
class FetchingOnboardingPreferences extends ListeningHistoryState {
  const FetchingOnboardingPreferences();
}

class OnboardingPreferencesLoaded extends ListeningHistoryState {
  final UserOnboardingPreferences preferences;

  const OnboardingPreferencesLoaded(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

class OnboardingPreferencesError extends ListeningHistoryState {
  final String message;

  const OnboardingPreferencesError(this.message);

  @override
  List<Object?> get props => [message];
}

class SavingOnboardingPreferences extends ListeningHistoryState {
  const SavingOnboardingPreferences();
}

class OnboardingPreferencesSaved extends ListeningHistoryState {
  const OnboardingPreferencesSaved();
}

// ==================== ADMIN ANALYTICS STATES ====================

class FetchingEngagementMetrics extends ListeningHistoryState {
  const FetchingEngagementMetrics();
}

class EngagementMetricsLoaded extends ListeningHistoryState {
  final EngagementMetrics metrics;
  const EngagementMetricsLoaded(this.metrics);

  @override
  List<Object?> get props => [metrics];
}

class EngagementMetricsError extends ListeningHistoryState {
  final String message;
  const EngagementMetricsError(this.message);

  @override
  List<Object?> get props => [message];
}

class RefreshingTrending extends ListeningHistoryState {
  const RefreshingTrending();
}

class TrendingRefreshed extends ListeningHistoryState {
  final RefreshTrendingResult result;
  const TrendingRefreshed(this.result);

  @override
  List<Object?> get props => [result];
}

class TrendingRefreshError extends ListeningHistoryState {
  final String message;
  const TrendingRefreshError(this.message);

  @override
  List<Object?> get props => [message];
}

