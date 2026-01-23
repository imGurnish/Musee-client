abstract interface class PlayerRepository {
  Future<List<String>> getQueueIds({bool expand = false});
  Future<List<Map<String, dynamic>>> getQueueExpanded();
  Future<void> addToQueue({
    required List<String> trackIds,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? metadataList,
  });
  Future<void> removeFromQueue({required String trackId});
  Future<List<String>> reorderQueue({
    required int fromIndex,
    required int toIndex,
  });
  Future<void> clearQueue();
  Future<List<Map<String, dynamic>>> playQueueFrom({
    required String trackId,
    bool expand = false,
    Map<String, dynamic>? metadata,
  });
}
