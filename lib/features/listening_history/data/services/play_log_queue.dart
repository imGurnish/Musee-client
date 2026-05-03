import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/listening_history_models.dart';
import '../datasources/listening_history_remote_data_source.dart';

/// Non-blocking, in-memory queue that batches [TrackPlayData] entries
/// and flushes them to the backend periodically. This prevents slow
/// network calls from blocking track transitions.
class PlayLogQueue {
  final ListeningHistoryRemoteDataSource _remote;

  /// How often the queue flushes pending entries to the backend.
  static const Duration _flushInterval = Duration(seconds: 15);

  /// Maximum batch size per flush cycle.
  static const int _maxBatchSize = 20;

  /// Entries waiting to be sent.
  final List<TrackPlayData> _pending = [];

  /// Entries currently being sent (in flight).
  final List<TrackPlayData> _inFlight = [];

  Timer? _flushTimer;
  bool _flushing = false;
  bool _disposed = false;

  PlayLogQueue({required ListeningHistoryRemoteDataSource remote})
      : _remote = remote {
    _startTimer();
  }

  /// Enqueue a play-log entry. This returns immediately and never blocks.
  void enqueue(TrackPlayData data) {
    if (_disposed) return;
    _pending.add(data);

    if (kDebugMode) {
      debugPrint(
        '[PlayLogQueue] Enqueued log for track ${data.trackId} '
        '(pending: ${_pending.length})',
      );
    }
  }

  /// Force an immediate flush (e.g. on app close). Returns a Future that
  /// completes when the current batch finishes sending.
  Future<void> flush() async {
    if (_disposed) return;
    await _doFlush();
  }

  void _startTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      if (!_flushing && _pending.isNotEmpty) {
        unawaited(_doFlush());
      }
    });
  }

  Future<void> _doFlush() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;

    // Move up to _maxBatchSize entries to in-flight
    final batchSize = _pending.length.clamp(0, _maxBatchSize);
    _inFlight.addAll(_pending.take(batchSize));
    _pending.removeRange(0, batchSize);

    if (kDebugMode) {
      debugPrint(
        '[PlayLogQueue] Flushing ${_inFlight.length} entries '
        '(remaining: ${_pending.length})',
      );
    }

    // Send each entry individually (the backend API expects one at a time).
    // Use Future.wait so all entries in the batch send in parallel.
    final futures = <Future<void>>[];
    for (final entry in _inFlight) {
      futures.add(_sendSingle(entry));
    }

    await Future.wait(futures, eagerError: false);

    _inFlight.clear();
    _flushing = false;
  }

  Future<void> _sendSingle(TrackPlayData data) async {
    try {
      await _remote.logTrackPlay(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PlayLogQueue] Failed to send log for ${data.trackId}: $e',
        );
      }
      // Re-enqueue so it gets retried on the next flush cycle.
      if (!_disposed) {
        _pending.add(data);
      }
    }
  }

  /// Flush remaining entries and release resources.
  Future<void> dispose() async {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Best-effort final flush
    if (_pending.isNotEmpty) {
      await _doFlush();
    }
  }
}
