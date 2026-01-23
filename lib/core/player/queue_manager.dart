/// Queue manager for handling queue operations with proper index synchronization.
/// Encapsulates all queue logic to ensure consistent state management.

import 'package:equatable/equatable.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

/// Immutable queue state with proper index tracking.
class QueueState extends Equatable {
  final List<QueueItem> items;
  final int currentIndex;

  const QueueState({this.items = const [], this.currentIndex = -1});

  /// Current item if index is valid
  QueueItem? get currentItem {
    if (currentIndex >= 0 && currentIndex < items.length) {
      return items[currentIndex];
    }
    return null;
  }

  /// Whether there are more tracks after current
  bool get hasNext => currentIndex < items.length - 1;

  /// Whether there are tracks before current
  bool get hasPrevious => currentIndex > 0;

  /// Remaining tracks after current
  int get remainingCount =>
      currentIndex >= 0 ? items.length - currentIndex - 1 : items.length;

  /// Total queue size
  int get length => items.length;

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items, currentIndex];
}

/// Manager for queue operations with proper index handling.
/// All operations return new immutable state rather than modifying in place.
class QueueManager {
  /// Add items to the end of the queue
  QueueState add(QueueState state, List<QueueItem> newItems) {
    if (newItems.isEmpty) return state;

    return QueueState(
      items: [...state.items, ...newItems],
      currentIndex: state.currentIndex,
    );
  }

  /// Insert items after the current track (play next)
  QueueState insertNext(QueueState state, List<QueueItem> newItems) {
    if (newItems.isEmpty) return state;

    final insertIndex = state.currentIndex >= 0 ? state.currentIndex + 1 : 0;

    final newList = [...state.items];
    newList.insertAll(insertIndex, newItems);

    return QueueState(items: newList, currentIndex: state.currentIndex);
  }

  /// Remove a track by ID
  QueueState remove(QueueState state, String trackId) {
    final index = state.items.indexWhere((item) => item.trackId == trackId);
    if (index < 0) return state;

    final newList = [...state.items]..removeAt(index);

    // Adjust currentIndex if needed
    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      // Removed item was before current, shift index back
      newIndex = state.currentIndex - 1;
    } else if (index == state.currentIndex) {
      // Removed current item; keep index (next item slides into position)
      // But clamp if we removed the last item
      newIndex = newIndex.clamp(-1, newList.length - 1);
    }
    // If removed after current, no change needed

    return QueueState(
      items: newList,
      currentIndex: newList.isEmpty ? -1 : newIndex,
    );
  }

  /// Reorder: move item from one position to another
  QueueState reorder(QueueState state, int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= state.items.length) return state;
    if (toIndex < 0 || toIndex >= state.items.length) return state;
    if (fromIndex == toIndex) return state;

    final newList = [...state.items];
    final item = newList.removeAt(fromIndex);
    newList.insert(toIndex, item);

    // Adjust currentIndex based on reorder
    int newIndex = state.currentIndex;
    if (state.currentIndex == fromIndex) {
      // Moving the current track
      newIndex = toIndex;
    } else if (fromIndex < state.currentIndex &&
        toIndex >= state.currentIndex) {
      // Moved something from before current to after/at current
      newIndex = state.currentIndex - 1;
    } else if (fromIndex > state.currentIndex &&
        toIndex <= state.currentIndex) {
      // Moved something from after current to before/at current
      newIndex = state.currentIndex + 1;
    }

    return QueueState(items: newList, currentIndex: newIndex);
  }

  /// Clear the entire queue
  QueueState clear(QueueState state) {
    return const QueueState(items: [], currentIndex: -1);
  }

  /// Set queue to a new list, optionally setting current index
  QueueState setQueue(List<QueueItem> items, {int currentIndex = -1}) {
    return QueueState(
      items: List.unmodifiable(items),
      currentIndex: currentIndex.clamp(-1, items.length - 1),
    );
  }

  /// Move to the next track
  QueueState next(QueueState state) {
    if (!state.hasNext) return state;
    return QueueState(items: state.items, currentIndex: state.currentIndex + 1);
  }

  /// Move to the previous track
  QueueState previous(QueueState state) {
    if (!state.hasPrevious) return state;
    return QueueState(items: state.items, currentIndex: state.currentIndex - 1);
  }

  /// Jump to a specific index
  QueueState jumpTo(QueueState state, int index) {
    if (index < 0 || index >= state.items.length) return state;
    return QueueState(items: state.items, currentIndex: index);
  }

  /// Jump to a specific track by ID
  QueueState jumpToTrack(QueueState state, String trackId) {
    final index = state.items.indexWhere((item) => item.trackId == trackId);
    if (index < 0) return state;
    return jumpTo(state, index);
  }

  /// Find index of a track by ID
  int findIndex(QueueState state, String trackId) {
    return state.items.indexWhere((item) => item.trackId == trackId);
  }

  /// Shuffle queue, keeping current track at current position
  QueueState shuffle(QueueState state) {
    if (state.items.length <= 1) return state;

    final current = state.currentItem;
    final otherItems =
        state.items.where((item) => item.trackId != current?.trackId).toList()
          ..shuffle();

    List<QueueItem> newList;
    int newIndex;

    if (current != null) {
      // Put current track at position 0, shuffled items after
      newList = [current, ...otherItems];
      newIndex = 0;
    } else {
      newList = otherItems..shuffle();
      newIndex = -1;
    }

    return QueueState(items: newList, currentIndex: newIndex);
  }
}

/// Global queue manager instance
final queueManager = QueueManager();
