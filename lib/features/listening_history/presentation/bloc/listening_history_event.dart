part of 'listening_history_bloc.dart';

abstract class ListeningHistoryEvent extends Equatable {
  const ListeningHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Log track play when it completes or after N seconds
class LogTrackPlayEvent extends ListeningHistoryEvent {
  final String trackId;
  final int timeListenedSeconds;
  final int totalDurationSeconds;
  final double completionPercentage;
  final bool wasSkipped;
  final int? skipAtSeconds;
  final String? listeningContext;
  final String? contextId;

  const LogTrackPlayEvent({
    required this.trackId,
    required this.timeListenedSeconds,
    required this.totalDurationSeconds,
    required this.completionPercentage,
    this.wasSkipped = false,
    this.skipAtSeconds,
    this.listeningContext,
    this.contextId,
  });

  @override
  List<Object?> get props => [
    trackId,
    timeListenedSeconds,
    totalDurationSeconds,
    completionPercentage,
    wasSkipped,
    skipAtSeconds,
    listeningContext,
    contextId,
  ];
}

/// Like a track
class LikeTrackEvent extends ListeningHistoryEvent {
  final String trackId;
  final List<String>? mood;

  const LikeTrackEvent(this.trackId, {this.mood});

  @override
  List<Object?> get props => [trackId, mood];
}

/// Dislike a track
class DislikeTrackEvent extends ListeningHistoryEvent {
  final String trackId;

  const DislikeTrackEvent(this.trackId);

  @override
  List<Object?> get props => [trackId];
}

/// Remove preference for a track
class ClearTrackPreferenceEvent extends ListeningHistoryEvent {
  final String trackId;

  const ClearTrackPreferenceEvent(this.trackId);

  @override
  List<Object?> get props => [trackId];
}

/// Fetch recommendations
class FetchRecommendationsEvent extends ListeningHistoryEvent {
  final int limit;
  final String type; // 'discovery', 'similar_to_liked', 'trending', 'mood_based'
  final bool includeReasons;

  const FetchRecommendationsEvent({
    this.limit = 50,
    this.type = 'discovery',
    this.includeReasons = false,
  });

  @override
  List<Object?> get props => [limit, type, includeReasons];
}

/// Fetch listening stats
class FetchListeningStatsEvent extends ListeningHistoryEvent {
  const FetchListeningStatsEvent();
}

/// Save onboarding preferences
class SaveOnboardingPreferencesEvent extends ListeningHistoryEvent {
  final UserOnboardingPreferences preferences;

  const SaveOnboardingPreferencesEvent(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Fetch onboarding preferences
class FetchOnboardingPreferencesEvent extends ListeningHistoryEvent {
  const FetchOnboardingPreferencesEvent();
}

/// Refresh all recommendation caches
class RefreshRecommendationCacheEvent extends ListeningHistoryEvent {
  const RefreshRecommendationCacheEvent();
}
