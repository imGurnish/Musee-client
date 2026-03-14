// Player data source — local-only stub.
//
// Queue management is handled entirely in PlayerCubit with in-memory state.
// This file is retained for potential future persistence (Hive, SQLite, etc).
//
// The backend-synced implementation has been removed as part of the
// JioSaavn-only migration.

abstract interface class PlayerDataSource {
  Future<List<String>> getQueueIds();
  Future<List<Map<String, dynamic>>> getQueueExpanded();
  Future<void> addToQueue(
    List<String> trackIds, {
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? metadataList,
  });
  Future<void> removeFromQueue(String trackId);
  Future<List<String>> reorderQueue(int from, int to);
  Future<void> clearQueue();
  Future<List<Map<String, dynamic>>> playFrom(
    String trackId, {
    bool expand = false,
    Map<String, dynamic>? metadata,
  });
}

/// In-memory implementation for local-only queue management.
/// Queue state is managed by PlayerCubit; this is a no-op placeholder.
class PlayerDataSourceImpl implements PlayerDataSource {
  final List<Map<String, dynamic>> _queue = [];

  PlayerDataSourceImpl();

  @override
  Future<List<String>> getQueueIds() async {
    return _queue.map((e) => e['track_id']?.toString() ?? '').toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getQueueExpanded() async {
    return List.unmodifiable(_queue);
  }

  @override
  Future<void> addToQueue(
    List<String> trackIds, {
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? metadataList,
  }) async {
    for (var i = 0; i < trackIds.length; i++) {
      final meta = metadataList != null && i < metadataList.length
          ? metadataList[i]
          : metadata ?? {};
      _queue.add({'track_id': trackIds[i], ...meta});
    }
  }

  @override
  Future<void> removeFromQueue(String trackId) async {
    _queue.removeWhere((e) => e['track_id'] == trackId);
  }

  @override
  Future<List<String>> reorderQueue(int from, int to) async {
    if (from < 0 || from >= _queue.length || to < 0 || to >= _queue.length) {
      return getQueueIds();
    }
    final item = _queue.removeAt(from);
    _queue.insert(to, item);
    return getQueueIds();
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
  }

  @override
  Future<List<Map<String, dynamic>>> playFrom(
    String trackId, {
    bool expand = false,
    Map<String, dynamic>? metadata,
  }) async {
    return getQueueExpanded();
  }
}
