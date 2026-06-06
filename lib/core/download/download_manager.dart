import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/image_cache_service.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/core/providers/provider_models.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';

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
  final ImageCacheService _imageCache;
  final SettingsCubit _settingsCubit;

  // Track active cancel tokens
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadManager(
    this._audioCache,
    this._trackCache,
    this._registry,
    this._imageCache,
    this._settingsCubit,
  ) : super(DownloadState.initial());

  @override
  void onChange(Change<DownloadState> change) {
    super.onChange(change);
    final hasActive = change.nextState.status.values.any((s) => s == DownloadStatus.downloading);
    _audioCache.isBulkDownloading = hasActive;
  }

  Future<void> addToQueue(String trackId) async {
    if (state.status[trackId] == DownloadStatus.downloading) return;

    // Set initial status
    _updateStatus(trackId, DownloadStatus.pending);
    _updateProgress(trackId, 0.0);

    try {
      // Fetch track details and cache them first
      final providerTrack = await _registry.getTrack(trackId);
      if (providerTrack == null) {
        _fail(trackId, 'Could not resolve track metadata');
        return;
      }

      String? localImagePath;
      if (providerTrack.imageUrl != null && providerTrack.imageUrl!.isNotEmpty) {
        try {
          localImagePath = await _imageCache.cacheImage(providerTrack.imageUrl!);
        } catch (e) {
          if (kDebugMode) {
            print('[DownloadManager] Failed to cache track artwork: $e');
          }
        }
      }

      final existingTrack = await _trackCache.getTrack(trackId);
      final cachedTrack = (existingTrack ?? CachedTrack())
        ..trackId = trackId
        ..title = providerTrack.title
        ..albumId = providerTrack.albumId
        ..albumTitle = providerTrack.albumTitle
        ..albumCoverUrl = providerTrack.imageUrl
        ..artistName = providerTrack.artistName
        ..durationSeconds = providerTrack.durationSeconds ?? 0
        ..isExplicit = providerTrack.isExplicit
        ..cachedAt = existingTrack?.cachedAt ?? DateTime.now()
        ..lastPlayedAt = DateTime.now()
        ..sourceProvider = providerTrack.source.name
        ..localImagePath = localImagePath ?? existingTrack?.localImagePath;

      await _trackCache.cacheTrack(cachedTrack);

      // Fetch URL with download quality selection
      final downloadQuality = _settingsCubit.state.downloadQuality;
      final targetBitrate = downloadQuality.targetBitrate;

      // Find preferred variant matching target bitrate
      ProviderAudioVariant? preferredVariant;
      for (final variant in providerTrack.hlsVariants) {
        if (variant.bitrate == targetBitrate) {
          preferredVariant = variant;
          break;
        }
      }
      if (preferredVariant == null && providerTrack.hlsVariants.isNotEmpty) {
        int maxBitrate = -1;
        for (final variant in providerTrack.hlsVariants) {
          if (variant.bitrate > maxBitrate) {
            maxBitrate = variant.bitrate;
            preferredVariant = variant;
          }
        }
      }

      final downloadUrl = preferredVariant?.url ?? await _registry.getDownloadUrl(trackId, targetBitrate: targetBitrate);
      if (downloadUrl == null) {
        _fail(trackId, 'Could not resolve stream URL');
        return;
      }

      // Start Download
      _updateStatus(trackId, DownloadStatus.downloading);
      final cancelToken = CancelToken();
      _cancelTokens[trackId] = cancelToken;

      final List<String> protectedTrackIds = [trackId];
      if (GetIt.instance.isRegistered<PlayerCubit>()) {
        final player = GetIt.instance<PlayerCubit>();
        final currentTrackId = player.state.track?.trackId;
        if (currentTrackId != null) {
          protectedTrackIds.add(currentTrackId);
        }
        final queue = player.state.queue;
        final currentIndex = player.state.currentIndex;
        if (queue.isNotEmpty && currentIndex >= 0 && currentIndex + 1 < queue.length) {
          final nextTrackId = queue[currentIndex + 1].trackId;
          protectedTrackIds.add(nextTrackId);
        }
      }

      final filePath = await _audioCache.downloadAndCache(
        trackId: trackId,
        remoteUrl: downloadUrl,
        trackCache: _trackCache,
        preferredHlsBitrate: preferredVariant?.bitrate ?? targetBitrate,
        maxCacheSizeBytes: _settingsCubit.state.maxCacheSize.bytes,
        onProgress: (received, total) {
          if (total > 0) {
            final p = received / total;
            _updateProgress(trackId, p);
          }
        },
        cancelToken: cancelToken,
        protectedTrackIds: protectedTrackIds,
        isDownload: true,
      );

      if (filePath == null) {
        _fail(trackId, 'Download failed to save file');
      } else {
        _finish(trackId);
      }
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
