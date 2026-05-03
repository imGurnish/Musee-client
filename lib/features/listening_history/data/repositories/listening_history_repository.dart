import '../models/listening_history_models.dart';
import '../datasources/listening_history_remote_data_source.dart';
import '../services/play_log_queue.dart';

abstract class ListeningHistoryRepository {
  /// Log a track play. This is non-blocking — entries are batched and
  /// sent to the backend in the background.
  void logTrackPlay(TrackPlayData data);
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

  /// Flush any pending play-log entries to the backend immediately.
  Future<void> flushPlayLogs();

  /// Release resources. Should be called on app shutdown.
  Future<void> dispose();
}

class ListeningHistoryRepositoryImpl implements ListeningHistoryRepository {
  final ListeningHistoryRemoteDataSource remoteDataSource;
  final PlayLogQueue _playLogQueue;

  ListeningHistoryRepositoryImpl({required this.remoteDataSource})
      : _playLogQueue = PlayLogQueue(remote: remoteDataSource);

  @override
  void logTrackPlay(TrackPlayData data) {
    // Fully non-blocking — the entry is added to an in-memory queue
    // and flushed to the backend in periodic batches.
    _playLogQueue.enqueue(data);
  }

  @override
  Future<void> flushPlayLogs() => _playLogQueue.flush();

  @override
  Future<void> dispose() => _playLogQueue.dispose();

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
