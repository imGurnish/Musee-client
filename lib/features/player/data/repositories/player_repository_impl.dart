import 'package:musee/features/player/data/datasources/player_remote_data_source.dart';
import 'package:musee/features/player/domain/repository/player_repository.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final PlayerDataSource _remote;
  PlayerRepositoryImpl(this._remote);

  @override
  Future<void> addToQueue({
    required List<String> trackIds,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? metadataList,
  }) => _remote.addToQueue(
    trackIds,
    metadata: metadata,
    metadataList: metadataList,
  );

  @override
  Future<void> clearQueue() => _remote.clearQueue();

  @override
  Future<List<Map<String, dynamic>>> getQueueExpanded() =>
      _remote.getQueueExpanded();

  @override
  Future<List<String>> getQueueIds({bool expand = false}) =>
      _remote.getQueueIds();

  @override
  Future<void> removeFromQueue({required String trackId}) =>
      _remote.removeFromQueue(trackId);

  @override
  Future<List<String>> reorderQueue({
    required int fromIndex,
    required int toIndex,
  }) => _remote.reorderQueue(fromIndex, toIndex);

  @override
  Future<List<Map<String, dynamic>>> playQueueFrom({
    required String trackId,
    bool expand = false,
    Map<String, dynamic>? metadata,
  }) => _remote.playFrom(trackId, expand: expand, metadata: metadata);
}
