import 'package:equatable/equatable.dart';

/// Track play event with engagement metrics
class TrackPlayData extends Equatable {
  final String userId;
  final String trackId;
  final int timeListenedSeconds;
  final int totalDurationSeconds;
  final double completionPercentage;
  final bool wasSkipped;
  final int? skipAtSeconds;
  final String listeningContext; // 'playlist', 'album', 'search', 'recommendation', 'radio'
  final String? contextId; // playlist_id or album_id
  final String deviceType; // 'mobile', 'web', 'desktop'

  const TrackPlayData({
    required this.userId,
    required this.trackId,
    required this.timeListenedSeconds,
    required this.totalDurationSeconds,
    required this.completionPercentage,
    this.wasSkipped = false,
    this.skipAtSeconds,
    this.listeningContext = 'library',
    this.contextId,
    this.deviceType = 'mobile',
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'trackId': trackId,
    'timeListenedSeconds': timeListenedSeconds,
    'totalDurationSeconds': totalDurationSeconds,
    'completionPercentage': completionPercentage,
    'wasSkipped': wasSkipped,
    'skipAtSeconds': skipAtSeconds,
    'listeningContext': listeningContext,
    'contextId': contextId,
    'deviceType': deviceType,
  };

  @override
  List<Object?> get props => [
    userId,
    trackId,
    timeListenedSeconds,
    totalDurationSeconds,
    completionPercentage,
    wasSkipped,
    skipAtSeconds,
    listeningContext,
    contextId,
    deviceType,
  ];
}

/// User preference for a track
class TrackPreferenceData extends Equatable {
  final String userId;
  final String trackId;
  final int preference; // -1 (dislike), 0 (neutral), 1 (like)
  final List<String>? mood;

  const TrackPreferenceData({
    required this.userId,
    required this.trackId,
    required this.preference,
    this.mood,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'trackId': trackId,
    'preference': preference,
    'mood': mood,
  };

  @override
  List<Object?> get props => [userId, trackId, preference, mood];
}

/// Recommendation response from backend
class Recommendation extends Equatable {
  final List<String> trackIds;
  final List<String> albumIds;
  final List<String> artistIds;
  final String recommendationType;
  final bool fromCache;
  final DateTime? cachedUntil;
  final List<String>? reasons;

  const Recommendation({
    required this.trackIds,
    required this.albumIds,
    required this.artistIds,
    required this.recommendationType,
    this.fromCache = false,
    this.cachedUntil,
    this.reasons,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      trackIds: List<String>.from(json['track_ids'] ?? []),
      albumIds: List<String>.from(json['recommended_album_ids'] ?? []),
      artistIds: List<String>.from(json['recommended_artist_ids'] ?? []),
      recommendationType: json['recommendation_type'] ?? 'discovery',
      fromCache: json['from_cache'] ?? false,
      cachedUntil: json['cached_until'] != null 
        ? DateTime.parse(json['cached_until']) 
        : null,
      reasons: json['reasons'] != null 
        ? List<String>.from(json['reasons']) 
        : null,
    );
  }

  @override
  List<Object?> get props => [
    trackIds,
    albumIds,
    artistIds,
    recommendationType,
    fromCache,
    cachedUntil,
    reasons,
  ];
}

/// Queue preferences from user onboarding
class UserOnboardingPreferences extends Equatable {
  final String userId;
  final String? preferredLanguage;
  final String? preferredRegionId;
  final List<String> favoriteGenres;
  final List<String> favoriteMoods;
  final List<String> favoriteArtistIds;
  final bool allowRecommendations;
  final bool includeRandomSongs;
  final double randomnessPercentage; // 0-100, default 15%
  final bool allowNewReleases;
  final bool allowTrendingTracks;

  const UserOnboardingPreferences({
    required this.userId,
    this.preferredLanguage,
    this.preferredRegionId,
    this.favoriteGenres = const [],
    this.favoriteMoods = const [],
    this.favoriteArtistIds = const [],
    this.allowRecommendations = true,
    this.includeRandomSongs = true,
    this.randomnessPercentage = 15,
    this.allowNewReleases = true,
    this.allowTrendingTracks = true,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'preferred_language': preferredLanguage,
    'preferred_region_id': preferredRegionId,
    'favorite_genres': favoriteGenres,
    'favorite_moods': favoriteMoods,
    'favorite_artists': favoriteArtistIds,
    'allow_recommendations': allowRecommendations,
    'include_random_songs': includeRandomSongs,
    'randomness_percentage': randomnessPercentage,
    'allow_new_releases': allowNewReleases,
    'allow_trending_tracks': allowTrendingTracks,
  };

  factory UserOnboardingPreferences.fromJson(Map<String, dynamic> json) {
    return UserOnboardingPreferences(
      userId: json['user_id'] ?? '',
      preferredLanguage: json['preferred_language'],
      preferredRegionId: json['preferred_region_id'],
      favoriteGenres: List<String>.from(json['favorite_genres'] ?? []),
      favoriteMoods: List<String>.from(json['favorite_moods'] ?? []),
      favoriteArtistIds: List<String>.from(json['favorite_artists'] ?? []),
      allowRecommendations: json['allow_recommendations'] ?? true,
      includeRandomSongs: json['include_random_songs'] ?? true,
      randomnessPercentage: (json['randomness_percentage'] ?? 15).toDouble(),
      allowNewReleases: json['allow_new_releases'] ?? true,
      allowTrendingTracks: json['allow_trending_tracks'] ?? true,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    preferredLanguage,
    preferredRegionId,
    favoriteGenres,
    favoriteMoods,
    favoriteArtistIds,
    allowRecommendations,
    includeRandomSongs,
    randomnessPercentage,
    allowNewReleases,
    allowTrendingTracks,
  ];
}

/// User's genre affinity profile
class GenreAffinity extends Equatable {
  final String genre;
  final double affinityScore; // -1.0 to 1.0
  final int trackCount;
  final int totalListenTimeSeconds;

  const GenreAffinity({
    required this.genre,
    required this.affinityScore,
    this.trackCount = 0,
    this.totalListenTimeSeconds = 0,
  });

  factory GenreAffinity.fromJson(Map<String, dynamic> json) {
    return GenreAffinity(
      genre: json['genre'] ?? '',
      affinityScore: (json['affinity_score'] ?? 0).toDouble(),
      trackCount: json['track_count'] ?? 0,
      totalListenTimeSeconds: json['total_listen_time_seconds'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [genre, affinityScore, trackCount, totalListenTimeSeconds];
}

/// Listening statistics for analytics
class ListeningStats extends Equatable {
  final int totalTracksPlayed;
  final int totalListeningTimeSeconds;
  final double averageCompletionPercentage;
  final int skipCount;
  final int likeCount;
  final int dislikeCount;
  final List<String> topGenres;
  final List<String> topArtists;
  final DateTime lastPlayedAt;

  const ListeningStats({
    required this.totalTracksPlayed,
    required this.totalListeningTimeSeconds,
    required this.averageCompletionPercentage,
    required this.skipCount,
    required this.likeCount,
    required this.dislikeCount,
    required this.topGenres,
    required this.topArtists,
    required this.lastPlayedAt,
  });

  String get totalListeningTimeFormatted {
    final hours = totalListeningTimeSeconds ~/ 3600;
    final minutes = (totalListeningTimeSeconds % 3600) ~/ 60;
    return '$hours h ${minutes}m';
  }

  @override
  List<Object?> get props => [
    totalTracksPlayed,
    totalListeningTimeSeconds,
    averageCompletionPercentage,
    skipCount,
    likeCount,
    dislikeCount,
    topGenres,
    topArtists,
    lastPlayedAt,
  ];
}
