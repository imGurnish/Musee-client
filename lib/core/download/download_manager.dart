import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/providers/music_provider_registry.dart';

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class DownloadState {
  final Map<String, DownloadStatus> status;
  final Map<String, double> progress;
  final Map<String, String?> errors;

  const DownloadState({
    required this.status,
    required this.progress,
    required this.errors,
  });

  factory DownloadState.initial() =>
      const DownloadState(status: {}, progress: {}, errors: {});

  DownloadState copyWith({
    Map<String, DownloadStatus>? status,
    Map<String, double>? progress,
    Map<String, String?>? errors,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errors: errors ?? this.errors,
    );
  }
}

class DownloadManager extends Cubit<DownloadState> {
  final AudioCacheService _audioCache;
  final TrackCacheService _trackCache;
  final MusicProviderRegistry _registry;

  // Track active cancel tokens
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadManager(this._audioCache, this._trackCache, this._registry)
    : super(DownloadState.initial());

  Future<void> addToQueue(String trackId) async {
    if (state.status[trackId] == DownloadStatus.downloading) return;

    // Set initial status
    _updateStatus(trackId, DownloadStatus.pending);
    _updateProgress(trackId, 0.0);

    try {
      // Fetch URL
      final url = await _registry.getDownloadUrl(trackId);
      if (url == null) {
        _fail(trackId, 'Could not resolve stream URL');
        return;
      }

      // Start Download
      _updateStatus(trackId, DownloadStatus.downloading);
      final cancelToken = CancelToken();
      _cancelTokens[trackId] = cancelToken;

      await _audioCache.downloadAndCache(
        trackId: trackId,
        remoteUrl: url,
        trackCache: _trackCache,
        onProgress: (received, total) {
          if (total > 0) {
            final p = received / total;
            _updateProgress(trackId, p);
          }
        },
        cancelToken: cancelToken,
      );

      _finish(trackId);
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        _updateStatus(trackId, DownloadStatus.cancelled);
      } else {
        _fail(trackId, e.toString());
      }
    } finally {
      _cancelTokens.remove(trackId);
    }
  }

  void cancel(String trackId) {
    final token = _cancelTokens[trackId];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
    _cancelTokens.remove(trackId);
    _updateStatus(trackId, DownloadStatus.cancelled);
    _updateProgress(trackId, 0.0);
  }

  void _updateStatus(String trackId, DownloadStatus status) {
    final newStatus = Map<String, DownloadStatus>.from(state.status);
    final newErrors = Map<String, String?>.from(state.errors);

    newStatus[trackId] = status;
    if (status != DownloadStatus.failed) {
      newErrors.remove(trackId);
    }

    emit(state.copyWith(status: newStatus, errors: newErrors));
  }

  void _updateProgress(String trackId, double progress) {
    final newProgress = Map<String, double>.from(state.progress);
    newProgress[trackId] = progress;
    emit(state.copyWith(progress: newProgress));
  }

  void _fail(String trackId, String message) {
    final newStatus = Map<String, DownloadStatus>.from(state.status);
    final newErrors = Map<String, String?>.from(state.errors);

    newStatus[trackId] = DownloadStatus.failed;
    newErrors[trackId] = message;

    emit(state.copyWith(status: newStatus, errors: newErrors));
  }

  void _finish(String trackId) {
    final newStatus = Map<String, DownloadStatus>.from(state.status);
    newStatus[trackId] = DownloadStatus.completed;

    // Clear progress from state to keep it clean, or keep it at 1.0?
    // Keeping it at 1.0 is nice for UI to show "Done".
    final newProgress = Map<String, double>.from(state.progress);
    newProgress[trackId] = 1.0;

    emit(state.copyWith(status: newStatus, progress: newProgress));
  }
}
