import '../models/listening_history_models.dart';
import '../datasources/listening_history_remote_data_source.dart';

abstract class ListeningHistoryRepository {
  Future<void> logTrackPlay(TrackPlayData data);
  Future<void> likeTrack(String trackId, {List<String>? mood});
  Future<void> dislikeTrack(String trackId);
  Future<void> clearTrackPreference(String trackId);
  Future<Recommendation> getRecommendations({
    int limit = 50,
    String type = 'discovery',
    bool includeReasons = false,
  });
  Future<void> saveOnboardingPreferences(UserOnboardingPreferences preferences);
  Future<UserOnboardingPreferences> getOnboardingPreferences();
  Future<ListeningStats> getListeningStats();
}

class ListeningHistoryRepositoryImpl implements ListeningHistoryRepository {
  final ListeningHistoryRemoteDataSource remoteDataSource;

  ListeningHistoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> logTrackPlay(TrackPlayData data) async {
    try {
      await remoteDataSource.logTrackPlay(data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> likeTrack(String trackId, {List<String>? mood}) async {
    try {
      await remoteDataSource.likeTrack(trackId, mood: mood);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> dislikeTrack(String trackId) async {
    try {
      await remoteDataSource.dislikeTrack(trackId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearTrackPreference(String trackId) async {
    try {
      await remoteDataSource.clearTrackPreference(trackId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Recommendation> getRecommendations({
    int limit = 50,
    String type = 'discovery',
    bool includeReasons = false,
  }) async {
    try {
      return await remoteDataSource.getRecommendations(
        limit: limit,
        type: type,
        includeReasons: includeReasons,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveOnboardingPreferences(UserOnboardingPreferences preferences) async {
    try {
      await remoteDataSource.saveOnboardingPreferences(preferences);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserOnboardingPreferences> getOnboardingPreferences() async {
    try {
      return await remoteDataSource.getOnboardingPreferences();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ListeningStats> getListeningStats() async {
    try {
      return await remoteDataSource.getListeningStats();
    } catch (e) {
      rethrow;
    }
  }
}
