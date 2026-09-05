import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class SyncPlaybackStateParams {
  final String sessionId;
  final String? currentTrackId;
  final String? currentTrackTitle;
  final String? currentTrackArtist;
  final String? currentTrackAlbum;
  final String? currentTrackImageUrl;
  final int? currentTrackDurationMs;
  final List<String>? queue;
  final int? queueIndex;
  final int? positionMs;
  final bool? isPlaying;
  final double? volume;
  final bool? shuffle;
  final String? repeatMode;
  final bool? eqEnabled;
  final String? eqPreset;
  final List<double>? eqBands;
  final int? bassLevel;
  final int? surroundLevel;
  final bool? crossfadeEnabled;
  final bool? normalizeVolume;

  const SyncPlaybackStateParams({
    required this.sessionId,
    this.currentTrackId,
    this.currentTrackTitle,
    this.currentTrackArtist,
    this.currentTrackAlbum,
    this.currentTrackImageUrl,
    this.currentTrackDurationMs,
    this.queue,
    this.queueIndex,
    this.positionMs,
    this.isPlaying,
    this.volume,
    this.shuffle,
    this.repeatMode,
    this.eqEnabled,
    this.eqPreset,
    this.eqBands,
    this.bassLevel,
    this.surroundLevel,
    this.crossfadeEnabled,
    this.normalizeVolume,
  });
}

class SyncPlaybackState implements UseCase<Unit, SyncPlaybackStateParams> {
  final CastRepository repository;
  const SyncPlaybackState(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SyncPlaybackStateParams params) {
    return repository.updateSessionState(
      sessionId: params.sessionId,
      currentTrackId: params.currentTrackId,
      currentTrackTitle: params.currentTrackTitle,
      currentTrackArtist: params.currentTrackArtist,
      currentTrackAlbum: params.currentTrackAlbum,
      currentTrackImageUrl: params.currentTrackImageUrl,
      currentTrackDurationMs: params.currentTrackDurationMs,
      queue: params.queue,
      queueIndex: params.queueIndex,
      positionMs: params.positionMs,
      isPlaying: params.isPlaying,
      volume: params.volume,
      shuffle: params.shuffle,
      repeatMode: params.repeatMode,
      eqEnabled: params.eqEnabled,
      eqPreset: params.eqPreset,
      eqBands: params.eqBands,
      bassLevel: params.bassLevel,
      surroundLevel: params.surroundLevel,
      crossfadeEnabled: params.crossfadeEnabled,
      normalizeVolume: params.normalizeVolume,
    );
  }
}
