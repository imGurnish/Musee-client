import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listening_history_models.dart';

abstract class ListeningHistoryRemoteDataSource {
  /// Log a track play with engagement metrics
  Future<void> logTrackPlay(TrackPlayData data);
  
  /// Like a track
  Future<void> likeTrack(String trackId, {List<String>? mood});
  
  /// Dislike a track
  Future<void> dislikeTrack(String trackId);
  
  /// Remove preference for a track
  Future<void> clearTrackPreference(String trackId);
  
  /// Get personalized recommendations
  Future<Recommendation> getRecommendations({
    int limit = 50,
    String type = 'discovery',
    bool includeReasons = false,
  });
  
  /// Save user onboarding preferences
  Future<void> saveOnboardingPreferences(UserOnboardingPreferences preferences);
  
  /// Get user onboarding preferences
  Future<UserOnboardingPreferences> getOnboardingPreferences();
  
  /// Get listening history stats
  Future<ListeningStats> getListeningStats();
}

class ListeningHistoryRemoteDataSourceImpl implements ListeningHistoryRemoteDataSource {
  final Dio dio;
  final String baseUrl;
  final SupabaseClient supabaseClient;

  ListeningHistoryRemoteDataSourceImpl({
    required this.dio,
    required this.baseUrl,
    required this.supabaseClient,
  });

  Map<String, String> _headers() {
    final token = supabaseClient.auth.currentSession?.accessToken;
    final base = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    return token == null ? base : {...base, 'Authorization': 'Bearer $token'};
  }

  @override
  Future<void> logTrackPlay(TrackPlayData data) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/log-play',
        data: data.toJson(),
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> likeTrack(String trackId, {List<String>? mood}) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/track/$trackId/like',
        data: mood != null ? {'mood': mood} : null,
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> dislikeTrack(String trackId) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/track/$trackId/dislike',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> clearTrackPreference(String trackId) async {
    try {
      await dio.delete(
        '$baseUrl/api/listening/track/$trackId/preference',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<Recommendation> getRecommendations({
    int limit = 50,
    String type = 'discovery',
    bool includeReasons = false,
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/recommendations',
        queryParameters: {
          'limit': limit,
          'type': type,
          'includeReasons': includeReasons,
        },
        options: Options(headers: _headers()),
      );

      return Recommendation.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> saveOnboardingPreferences(UserOnboardingPreferences preferences) async {
    try {
      await dio.post(
        '$baseUrl/api/user/onboarding/preferences',
        data: preferences.toJson(),
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<UserOnboardingPreferences> getOnboardingPreferences() async {
    try {
      final response = await dio.get(
        '$baseUrl/api/user/onboarding/preferences',
        options: Options(headers: _headers()),
      );

      return UserOnboardingPreferences.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<ListeningStats> getListeningStats() async {
    try {
      final response = await dio.get(
        '$baseUrl/api/user/listening-stats',
        options: Options(headers: _headers()),
      );

      return _parseListeningStats(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Parse listening stats API response
  ListeningStats _parseListeningStats(Map<String, dynamic> json) {
    return ListeningStats(
      totalTracksPlayed: json['total_tracks_played'] ?? 0,
      totalListeningTimeSeconds: json['total_listening_time_seconds'] ?? 0,
      averageCompletionPercentage: (json['average_completion_percentage'] ?? 0).toDouble(),
      skipCount: json['skip_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      dislikeCount: json['dislike_count'] ?? 0,
      topGenres: List<String>.from(json['top_genres'] ?? []),
      topArtists: List<String>.from(json['top_artists'] ?? []),
      lastPlayedAt: json['last_played_at'] != null
        ? DateTime.parse(json['last_played_at'])
        : DateTime.now(),
    );
  }

  Exception _handleDioException(DioException e) {
    String message = 'An error occurred';
    
    if (e.response != null) {
      message = e.response?.data?['message'] ?? e.response?.statusMessage ?? message;
    } else if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      message = 'Response timeout';
    } else if (e.type == DioExceptionType.unknown) {
      message = 'Network error: ${e.message}';
    }
    
    return Exception(message);
  }
}
