import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:musee/core/platform/platform_io_stub.dart'
  if (dart.library.io) 'package:musee/core/platform/platform_io_native.dart'
  as platform_io;

class MediaControlCallbacks {
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function() onStop;

  const MediaControlCallbacks({
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.onStop,
  });
}

class MediaControlsService {
  MediaControlsService._();

  static final MediaControlsService instance = MediaControlsService._();

  _MuseeAudioHandler? _handler;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _handler = await AudioService.init(
      builder: _MuseeAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.musee.playback',
        androidNotificationChannelName: 'Musee Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    if (platform_io.isAndroidPlatform) {
      try {
        await AudioService.androidForceEnableMediaButtons();
      } catch (_) {}
    }

    _initialized = true;
  }

  void configureCallbacks(MediaControlCallbacks callbacks) {
    _handler?.callbacks = callbacks;
  }

  void updateMediaItem({
    required String id,
    required String title,
    required String artist,
    String? album,
    Uri? artUri,
    Duration? duration,
  }) {
    _handler?.mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        artUri: artUri,
        duration: duration,
      ),
    );
  }

  void clearMediaItem() {
    _handler?.mediaItem.add(null);
  }

  void updatePlaybackState({
    required bool playing,
    required bool buffering,
    required Duration position,
    required Duration bufferedPosition,
    required bool hasPrevious,
    required bool hasNext,
    Duration? duration,
    int? queueIndex,
  }) {
    final controls = <MediaControl>[
      if (hasPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    final compactActionIndices = <int>[];
    final playPauseIndex = hasPrevious ? 1 : 0;
    if (hasPrevious) {
      compactActionIndices.add(0);
    }
    compactActionIndices.add(playPauseIndex);
    if (hasNext) {
      compactActionIndices.add(playPauseIndex + 1);
    }

    final hasMediaItem = _handler?.mediaItem.value != null;

    final state = PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop,
      },
      androidCompactActionIndices: compactActionIndices,
      processingState: buffering
          ? AudioProcessingState.buffering
          : (hasMediaItem ? AudioProcessingState.ready : AudioProcessingState.idle),
      playing: playing,
      updatePosition: position,
      bufferedPosition: bufferedPosition,
      speed: 1.0,
      updateTime: DateTime.now(),
      queueIndex: queueIndex,
    );

    _handler?.playbackState.add(state);

    final current = _handler?.mediaItem.value;
    if (current != null && duration != null && current.duration != duration) {
      _handler?.mediaItem.add(current.copyWith(duration: duration));
    }
  }
}

class _MuseeAudioHandler extends BaseAudioHandler with SeekHandler {
  MediaControlCallbacks? callbacks;

  Future<void> _safeRun(Future<void> Function()? action) async {
    if (action == null) return;
    try {
      await action();
    } catch (_) {
      // Keep media session alive even if app callback fails.
    }
  }

  @override
  Future<void> play() async {
    await _safeRun(callbacks?.onPlay);
  }

  @override
  Future<void> pause() async {
    await _safeRun(callbacks?.onPause);
  }

  @override
  Future<void> skipToNext() async {
    await _safeRun(callbacks?.onNext);
  }

  @override
  Future<void> skipToPrevious() async {
    await _safeRun(callbacks?.onPrevious);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        final isPlaying = playbackState.hasValue ? playbackState.value.playing : false;
        if (isPlaying) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }

  @override
  Future<void> fastForward() async {
    await skipToNext();
  }

  @override
  Future<void> rewind() async {
    await skipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    final onSeekCallback = callbacks?.onSeek;
    if (onSeekCallback == null) return;
    await _safeRun(() => onSeekCallback(position));
  }

  @override
  Future<void> stop() async {
    await _safeRun(callbacks?.onStop);
  }
}
