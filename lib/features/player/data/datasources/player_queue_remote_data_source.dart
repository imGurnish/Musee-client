import 'package:dio/dio.dart';
import '../../../listening_history/data/models/listening_history_models.dart';

abstract class PlayerQueueRemoteDataSource {
  Future<List<String>> getQueue();
  Future<void> addTracksToQueue(List<String> trackIds, {int? position});
  Future<void> removeTrackFromQueue(String trackId);
  Future<void> reorderQueue(int fromIndex, int toIndex);
  Future<Recommendation> getSmartRecommendations({
    required String type,
    required int limit,
    UserOnboardingPreferences? userPreferences,
  });
  Future<void> saveQueuePreferences(Map<String, dynamic> preferences);
  Future<void> prioritizeTrack(String trackId, int position);
}

class PlayerQueueRemoteDataSourceImpl implements PlayerQueueRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  PlayerQueueRemoteDataSourceImpl({
    required this.dio,
    required this.baseUrl,
  });

  @override
  Future<List<String>> getQueue() async {
    try {
      final response = await dio.get('$baseUrl/api/user/queue');
      final items = response.data['items'] as List;
      return items.map((item) => item['track_id']?.toString() ?? item.toString()).toList();
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> addTracksToQueue(List<String> trackIds, {int? position}) async {
    try {
      await dio.post(
        '$baseUrl/api/user/queue/add',
        data: {
          'track_ids': trackIds,
          'position': position,
        },
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> removeTrackFromQueue(String trackId) async {
    try {
      await dio.delete('$baseUrl/api/user/queue/$trackId');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> reorderQueue(int fromIndex, int toIndex) async {
    try {
      await dio.post(
        '$baseUrl/api/user/queue/reorder',
        data: {
          'fromIndex': fromIndex,
          'toIndex': toIndex,
        },
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<Recommendation> getSmartRecommendations({
    required String type,
    required int limit,
    UserOnboardingPreferences? userPreferences,
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/recommendations',
        queryParameters: {
          'type': type,
          'limit': limit,
          'includeReasons': true,
        },
      );

      return Recommendation.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> saveQueuePreferences(Map<String, dynamic> preferences) async {
    try {
      await dio.post(
        '$baseUrl/api/user/queue/preferences',
        data: preferences,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> prioritizeTrack(String trackId, int position) async {
    try {
      // Get current queue
      final queueResponse = await dio.get('$baseUrl/api/user/queue');
      final queue = queueResponse.data['items'] as List? ?? [];
      
      // Find current position
      int currentIndex = -1;
      for (int i = 0; i < queue.length; i++) {
        final item = queue[i];
        final id = item is Map ? item['track_id']?.toString() ?? item.toString() : item.toString();
        if (id == trackId) {
          currentIndex = i;
          break;
        }
      }

      if (currentIndex == -1) {
        throw Exception('Track not found in queue');
      }

      // Reorder if needed
      if (currentIndex != position) {
        await reorderQueue(currentIndex, position);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
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
