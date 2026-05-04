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
  
  /// Get the user's preference for a track (1=like, -1=dislike, 0=none)
  Future<int> getTrackPreference(String trackId);
  
  // ==================== ALBUM PREFERENCES ====================
  
  /// Like an album
  Future<void> likeAlbum(String albumId);
  
  /// Dislike an album
  Future<void> dislikeAlbum(String albumId);
  
  /// Remove preference for an album
  Future<void> clearAlbumPreference(String albumId);

  /// Get the user's preference for an album (1=like, -1=dislike, 0=none)
  Future<int> getAlbumPreference(String albumId);
  
  // ==================== PLAYLIST PREFERENCES ====================
  
  /// Like a playlist
  Future<void> likePlaylist(String playlistId);
  
  /// Dislike a playlist
  Future<void> dislikePlaylist(String playlistId);
  
  /// Remove preference for a playlist
  Future<void> clearPlaylistPreference(String playlistId);

  /// Get the user's preference for a playlist (1=like, -1=dislike, 0=none)
  Future<int> getPlaylistPreference(String playlistId);
  
  // ==================== ADMIN ANALYTICS ====================
  
  /// Get engagement metrics (admin only)
  Future<EngagementMetrics> getEngagementMetrics();
  
  /// Refresh trending data and popularity scores (admin only)
  Future<RefreshTrendingResult> refreshTrending();
  
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
  Future<int> getTrackPreference(String trackId) async {
    final normalizedTrackId = trackId.trim();
    if (normalizedTrackId.isEmpty) return 0;

    try {
      return await _getPreferenceViaApi('/api/listening/track/$normalizedTrackId/preference');
    } catch (_) {
      // Fallback to direct DB read when API route is unavailable.
    }

    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) return 0;
      final response = await supabaseClient
          .from('user_track_preferences')
          .select('preference')
          .eq('user_id', userId)
          .eq('track_id', normalizedTrackId)
          .maybeSingle();
      return _extractPreferenceValue(response);
    } catch (_) {
      return 0;
    }
  }

  // ==================== ALBUM PREFERENCES ====================

  @override
  Future<void> likeAlbum(String albumId) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/album/$albumId/like',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> dislikeAlbum(String albumId) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/album/$albumId/dislike',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> clearAlbumPreference(String albumId) async {
    try {
      await dio.delete(
        '$baseUrl/api/listening/album/$albumId/preference',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<int> getAlbumPreference(String albumId) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) return 0;

    try {
      return await _getPreferenceViaApi('/api/listening/album/$normalizedAlbumId/preference');
    } catch (_) {
      // Fallback to direct DB read when API route is unavailable.
    }

    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) return 0;
      final response = await supabaseClient
          .from('user_album_preferences')
          .select('preference')
          .eq('user_id', userId)
          .eq('album_id', normalizedAlbumId)
          .maybeSingle();
      return _extractPreferenceValue(response);
    } catch (_) {
      return 0;
    }
  }

  // ==================== PLAYLIST PREFERENCES ====================

  @override
  Future<void> likePlaylist(String playlistId) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/playlist/$playlistId/like',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> dislikePlaylist(String playlistId) async {
    try {
      await dio.post(
        '$baseUrl/api/listening/playlist/$playlistId/dislike',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> clearPlaylistPreference(String playlistId) async {
    try {
      await dio.delete(
        '$baseUrl/api/listening/playlist/$playlistId/preference',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<int> getPlaylistPreference(String playlistId) async {
    final normalizedPlaylistId = playlistId.trim();
    if (normalizedPlaylistId.isEmpty) return 0;

    try {
      return await _getPreferenceViaApi('/api/listening/playlist/$normalizedPlaylistId/preference');
    } catch (_) {
      // Fallback to direct DB read when API route is unavailable.
    }

    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) return 0;
      final response = await supabaseClient
          .from('user_playlist_preferences')
          .select('preference')
          .eq('user_id', userId)
          .eq('playlist_id', normalizedPlaylistId)
          .maybeSingle();
      return _extractPreferenceValue(response);
    } catch (_) {
      return 0;
    }
  }

  // ==================== ADMIN ANALYTICS ====================

  @override
  Future<EngagementMetrics> getEngagementMetrics() async {
    try {
      final response = await dio.get(
        '$baseUrl/api/admin/metrics/engagement',
        options: Options(headers: _headers()),
      );
      return EngagementMetrics.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<RefreshTrendingResult> refreshTrending() async {
    try {
      final response = await dio.post(
        '$baseUrl/api/admin/metrics/refresh-trending',
        options: Options(headers: _headers()),
      );
      return RefreshTrendingResult.fromJson(response.data);
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

  Future<int> _getPreferenceViaApi(String path) async {
    final response = await dio.get(
      '$baseUrl$path',
      options: Options(headers: _headers()),
    );
    return _extractPreferenceValue(response.data);
  }

  int _extractPreferenceValue(dynamic payload) {
    if (payload == null) return 0;

    if (payload is num) {
      return payload.toInt();
    }

    if (payload is bool) {
      return payload ? 1 : 0;
    }

    if (payload is Map<String, dynamic>) {
      final directPreference = payload['preference'];
      if (directPreference is num) {
        return directPreference.toInt();
      }

      final nestedData = payload['data'];
      if (nestedData is Map<String, dynamic>) {
        final nestedPreference = nestedData['preference'];
        if (nestedPreference is num) {
          return nestedPreference.toInt();
        }
      }

      final isLiked = payload['is_liked'] ?? payload['liked'];
      if (isLiked is bool) {
        return isLiked ? 1 : 0;
      }
    }

    return 0;
  }
}
