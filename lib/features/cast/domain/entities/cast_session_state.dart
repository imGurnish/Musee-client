import 'package:equatable/equatable.dart';

class CastSessionState extends Equatable {
  final String sessionId;
  final String? currentTrackId;
  final String? currentTrackTitle;
  final String? currentTrackArtist;
  final String? currentTrackAlbum;
  final String? currentTrackImageUrl;
  final int? currentTrackDurationMs;
  final List<String> queue;
  final int queueIndex;
  final int positionMs;
  final bool isPlaying;
  final double volume;
  final bool shuffle;
  final String repeatMode; // none | one | all

  // Audio / EQ controls
  final bool eqEnabled;
  final String eqPreset;
  final List<double> eqBands;
  final int bassLevel;
  final int surroundLevel;
  final bool crossfadeEnabled;
  final bool normalizeVolume;

  const CastSessionState({
    required this.sessionId,
    this.currentTrackId,
    this.currentTrackTitle,
    this.currentTrackArtist,
    this.currentTrackAlbum,
    this.currentTrackImageUrl,
    this.currentTrackDurationMs,
    this.queue = const [],
    this.queueIndex = 0,
    this.positionMs = 0,
    this.isPlaying = false,
    this.volume = 1.0,
    this.shuffle = false,
    this.repeatMode = 'none',
    this.eqEnabled = true,
    this.eqPreset = 'normal',
    this.eqBands = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.bassLevel = 0,
    this.surroundLevel = 0,
    this.crossfadeEnabled = false,
    this.normalizeVolume = false,
  });

  CastSessionState copyWith({
    String? sessionId,
    String? currentTrackId,
    String? currentTrackTitle,
    String? currentTrackArtist,
    String? currentTrackAlbum,
    String? currentTrackImageUrl,
    int? currentTrackDurationMs,
    List<String>? queue,
    int? queueIndex,
    int? positionMs,
    bool? isPlaying,
    double? volume,
    bool? shuffle,
    String? repeatMode,
    bool? eqEnabled,
    String? eqPreset,
    List<double>? eqBands,
    int? bassLevel,
    int? surroundLevel,
    bool? crossfadeEnabled,
    bool? normalizeVolume,
  }) {
    return CastSessionState(
      sessionId: sessionId ?? this.sessionId,
      currentTrackId: currentTrackId ?? this.currentTrackId,
      currentTrackTitle: currentTrackTitle ?? this.currentTrackTitle,
      currentTrackArtist: currentTrackArtist ?? this.currentTrackArtist,
      currentTrackAlbum: currentTrackAlbum ?? this.currentTrackAlbum,
      currentTrackImageUrl: currentTrackImageUrl ?? this.currentTrackImageUrl,
      currentTrackDurationMs: currentTrackDurationMs ?? this.currentTrackDurationMs,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqPreset: eqPreset ?? this.eqPreset,
      eqBands: eqBands ?? this.eqBands,
      bassLevel: bassLevel ?? this.bassLevel,
      surroundLevel: surroundLevel ?? this.surroundLevel,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      normalizeVolume: normalizeVolume ?? this.normalizeVolume,
    );
  }

  @override
  List<Object?> get props => [
    sessionId, currentTrackId, currentTrackTitle, currentTrackArtist,
    currentTrackAlbum, currentTrackImageUrl, currentTrackDurationMs,
    queue, queueIndex, positionMs,
    isPlaying, volume, shuffle, repeatMode,
    eqEnabled, eqPreset, eqBands, bassLevel, surroundLevel,
    crossfadeEnabled, normalizeVolume,
  ];
}
