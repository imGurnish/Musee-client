import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musee/core/cache/cache_config.dart';
import 'package:musee/core/cache/models/queue_item_hive.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

/// Persists queue state (items, current index, playback position) using Hive.
abstract class QueuePersistenceService {
  /// Initialize Hive boxes
  Future<void> init();

  /// Save the full queue and current index
  Future<void> saveQueue(List<QueueItem> queue, int currentIndex);

  /// Save the current playback position (debounced internally)
  void savePosition(Duration position);

  /// Save position immediately (e.g. on app close)
  Future<void> savePositionImmediate(Duration position);

  /// Load persisted queue, current index, and last playback position
  Future<QueueSnapshot> loadQueue();

  /// Clear all persisted queue data
  Future<void> clearQueue();

  /// Dispose resources
  void dispose();
}

/// Snapshot of persisted queue state
class QueueSnapshot {
  final List<QueueItem> queue;
  final int currentIndex;
  final Duration position;

  const QueueSnapshot({
    this.queue = const [],
    this.currentIndex = -1,
    this.position = Duration.zero,
  });

  bool get isEmpty => queue.isEmpty;
}

class QueuePersistenceServiceImpl implements QueuePersistenceService {
  Box<HiveQueueItem>? _queueBox;
  Box? _settingsBox;
  Timer? _positionDebounce;

  static const _currentIndexKey = 'current_index';
  static const _positionMsKey = 'position_ms';

  @override
  Future<void> init() async {
    if (_queueBox != null && _settingsBox != null) return;

    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveQueueItemAdapter());
    }

    _queueBox = await Hive.openBox<HiveQueueItem>(CacheConfig.queueBoxName);
    _settingsBox = await Hive.openBox(CacheConfig.queueSettingsBoxName);
  }

  Box<HiveQueueItem> get _queue {
    if (_queueBox == null) {
      throw StateError(
        'QueuePersistenceService not initialized. Call init() first.',
      );
    }
    return _queueBox!;
  }

  Box get _settings {
    if (_settingsBox == null) {
      throw StateError(
        'QueuePersistenceService not initialized. Call init() first.',
      );
    }
    return _settingsBox!;
  }

  @override
  Future<void> saveQueue(List<QueueItem> queue, int currentIndex) async {
    try {
      // Clear and re-write to maintain order
      await _queue.clear();

      // Write items in order using sequential integer keys
      for (int i = 0; i < queue.length; i++) {
        await _queue.put(i, HiveQueueItem.fromQueueItem(queue[i]));
      }

      await _settings.put(_currentIndexKey, currentIndex);

      if (kDebugMode) {
        debugPrint(
          '[QueuePersistence] Saved ${queue.length} items, index=$currentIndex',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QueuePersistence] Error saving queue: $e');
      }
    }
  }

  @override
  void savePosition(Duration position) {
    // Debounce: only write every 5 seconds to avoid excessive I/O
    _positionDebounce?.cancel();
    _positionDebounce = Timer(const Duration(seconds: 5), () {
      savePositionImmediate(position);
    });
  }

  @override
  Future<void> savePositionImmediate(Duration position) async {
    try {
      await _settings.put(_positionMsKey, position.inMilliseconds);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QueuePersistence] Error saving position: $e');
      }
    }
  }

  @override
  Future<QueueSnapshot> loadQueue() async {
    try {
      // Read items in key order (0, 1, 2, ...)
      final keys = _queue.keys.toList()..sort();
      final items = <QueueItem>[];
      for (final key in keys) {
        final hiveItem = _queue.get(key);
        if (hiveItem != null) {
          items.add(hiveItem.toQueueItem());
        }
      }

      final currentIndex =
          (_settings.get(_currentIndexKey) as int?) ?? -1;
      final positionMs =
          (_settings.get(_positionMsKey) as int?) ?? 0;

      if (kDebugMode) {
        debugPrint(
          '[QueuePersistence] Loaded ${items.length} items, '
          'index=$currentIndex, position=${positionMs}ms',
        );
      }

      return QueueSnapshot(
        queue: items,
        currentIndex: currentIndex.clamp(-1, items.length - 1),
        position: Duration(milliseconds: positionMs),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QueuePersistence] Error loading queue: $e');
      }
      return const QueueSnapshot();
    }
  }

  @override
  Future<void> clearQueue() async {
    await _queue.clear();
    await _settings.delete(_currentIndexKey);
    await _settings.delete(_positionMsKey);
  }

  @override
  void dispose() {
    _positionDebounce?.cancel();
  }
}
