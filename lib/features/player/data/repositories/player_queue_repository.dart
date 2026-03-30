import '../../../listening_history/data/models/listening_history_models.dart';
import '../datasources/player_queue_remote_data_source.dart';

abstract class PlayerQueueRepository {
  /// Get current queue
  Future<List<String>> getQueue();
  
  /// Add tracks to queue
  Future<void> addTracksToQueue(List<String> trackIds, {int? position});
  
  /// Remove track from queue
  Future<void> removeTrackFromQueue(String trackId);
  
  /// Reorder queue
  Future<void> reorderQueue(int fromIndex, int toIndex);
  
  /// Get smart recommendations based on user preferences
  Future<Recommendation> getSmartRecommendations({
    required String type,
    required int limit,
    UserOnboardingPreferences? userPreferences,
  });
  
  /// Save queue preferences
  Future<void> saveQueuePreferences(Map<String, dynamic> preferences);
  
  /// Prioritize a track (move to specific position)
  Future<void> prioritizeTrack(String trackId, int position);
}

class PlayerQueueRepositoryImpl implements PlayerQueueRepository {
  final PlayerQueueRemoteDataSource remoteDataSource;

  PlayerQueueRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<String>> getQueue() async {
    try {
      return await remoteDataSource.getQueue();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addTracksToQueue(List<String> trackIds, {int? position}) async {
    try {
      await remoteDataSource.addTracksToQueue(trackIds, position: position);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> removeTrackFromQueue(String trackId) async {
    try {
      await remoteDataSource.removeTrackFromQueue(trackId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> reorderQueue(int fromIndex, int toIndex) async {
    try {
      await remoteDataSource.reorderQueue(fromIndex, toIndex);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Recommendation> getSmartRecommendations({
    required String type,
    required int limit,
    UserOnboardingPreferences? userPreferences,
  }) async {
    try {
      return await remoteDataSource.getSmartRecommendations(
        type: type,
        limit: limit,
        userPreferences: userPreferences,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveQueuePreferences(Map<String, dynamic> preferences) async {
    try {
      await remoteDataSource.saveQueuePreferences(preferences);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> prioritizeTrack(String trackId, int position) async {
    try {
      await remoteDataSource.prioritizeTrack(trackId, position);
    } catch (e) {
      rethrow;
    }
  }
}
