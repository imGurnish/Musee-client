import 'package:equatable/equatable.dart';

/// Model for queue preferences
class QueuePreferences extends Equatable {
  final String userId;
  final int minQueueSize; // Min tracks to keep in queue
  final int smartFillThreshold; // When to auto-fill
  final String preferredRecommendationType; // 'discovery', 'similar', 'trending', 'mood'
  final bool allowRepeatTracks;
  final bool prioritizeNewReleases;
  final bool prioritizeLikedTracks;
  final bool respectUserLanguagePreference;
  final bool respectUserMoodPreference;

  const QueuePreferences({
    required this.userId,
    this.minQueueSize = 30,
    this.smartFillThreshold = 10,
    this.preferredRecommendationType = 'discovery',
    this.allowRepeatTracks = false,
    this.prioritizeNewReleases = true,
    this.prioritizeLikedTracks = true,
    this.respectUserLanguagePreference = true,
    this.respectUserMoodPreference = true,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'min_queue_size': minQueueSize,
    'smart_fill_threshold': smartFillThreshold,
    'preferred_recommendation_type': preferredRecommendationType,
    'allow_repeat_tracks': allowRepeatTracks,
    'prioritize_new_releases': prioritizeNewReleases,
    'prioritize_liked_tracks': prioritizeLikedTracks,
    'respect_user_language_preference': respectUserLanguagePreference,
    'respect_user_mood_preference': respectUserMoodPreference,
  };

  @override
  List<Object?> get props => [
    userId,
    minQueueSize,
    smartFillThreshold,
    preferredRecommendationType,
    allowRepeatTracks,
    prioritizeNewReleases,
    prioritizeLikedTracks,
    respectUserLanguagePreference,
    respectUserMoodPreference,
  ];
}
