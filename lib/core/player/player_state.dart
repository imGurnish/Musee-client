import 'package:equatable/equatable.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

enum PlayerRepeatMode { off, all, one }

class PlayerTrack extends Equatable {
  final String? trackId; // nullable when playing ad-hoc URL not from queue
  final String url;
  final String title;
  final String artist;
  final String? album;
  final String? imageUrl;
  final String? localImagePath;
  final Map<String, String>? headers;

  const PlayerTrack({
    this.trackId,
    required this.url,
    required this.title,
    required this.artist,
    this.album,
    this.imageUrl,
    this.localImagePath,
    this.headers,
  });

  PlayerTrack copyWith({
    String? trackId,
    String? url,
    String? title,
    String? artist,
    String? album,
    String? imageUrl,
    String? localImagePath,
    Map<String, String>? headers,
  }) => PlayerTrack(
    trackId: trackId ?? this.trackId,
    url: url ?? this.url,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    imageUrl: imageUrl ?? this.imageUrl,
    localImagePath: localImagePath ?? this.localImagePath,
    headers: headers ?? this.headers,
  );

  @override
  List<Object?> get props => [
    trackId,
    url,
    title,
    artist,
    album,
    imageUrl,
    localImagePath,
    headers,
  ];
}

class PlayerViewState extends Equatable {
  final PlayerTrack? track;
  final bool playing;
  final bool buffering;
  final bool resolvingUrl;
  final bool isTransitioning;
  final String? errorMessage;
  final Duration position;
  final Duration duration;
  final double volume;
  final List<QueueItem> queue;
  final int currentIndex; // index within queue for currently playing track
  final bool shuffleEnabled;
  final PlayerRepeatMode repeatMode;

  const PlayerViewState({
    this.track,
    this.playing = false,
    this.buffering = false,
    this.resolvingUrl = false,
    this.isTransitioning = false,
    this.errorMessage,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.queue = const <QueueItem>[],
    this.currentIndex = -1,
    this.shuffleEnabled = false,
    this.repeatMode = PlayerRepeatMode.off,
  });

  PlayerViewState copyWith({
    PlayerTrack? track,
    bool? playing,
    bool? buffering,
    bool? resolvingUrl,
    bool? isTransitioning,
    String? errorMessage,
    bool clearErrorMessage = false,
    Duration? position,
    Duration? duration,
    double? volume,
    List<QueueItem>? queue,
    int? currentIndex,
    bool? shuffleEnabled,
    PlayerRepeatMode? repeatMode,
  }) {
    return PlayerViewState(
      track: track ?? this.track,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
        resolvingUrl: resolvingUrl ?? this.resolvingUrl,
        isTransitioning: isTransitioning ?? this.isTransitioning,
        errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  @override
  List<Object?> get props => [
    track,
    playing,
    buffering,
    resolvingUrl,
    isTransitioning,
    errorMessage,
    position,
    duration,
    volume,
    queue,
    currentIndex,
    shuffleEnabled,
    repeatMode,
  ];
}
