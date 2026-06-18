/// Immutable snapshot of the player's internal state for the dev diagnostics
/// screen. Built on demand by [PlayerCubit.diagnostics] from live player,
/// network and cache state. Intentionally not part of [PlayerViewState] so it
/// never triggers UI rebuilds during normal playback.
library;

class PlayerDiagnosticsInfo {
  const PlayerDiagnosticsInfo({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.platformInitialized,
    required this.playing,
    required this.buffering,
    required this.resolvingUrl,
    required this.isTransitioning,
    required this.userPausedIntent,
    required this.errorMessage,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.volume,
    required this.streamingQualitySetting,
    required this.streamingTargetKbps,
    required this.recommendedKbps,
    required this.decodedAudioBitrateKbps,
    required this.sampleRateHz,
    required this.channels,
    required this.playbackSource,
    required this.playbackUrl,
    required this.connectionType,
    required this.estimatedThroughputKbps,
    required this.isOnline,
    required this.queueLength,
    required this.currentIndex,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.activeBackgroundCaches,
  });

  // ── Now playing ──
  final String? trackId;
  final String? title;
  final String? artist;
  final String? album;

  // ── Playback state ──
  final bool platformInitialized;
  final bool playing;
  final bool buffering;
  final bool resolvingUrl;
  final bool isTransitioning;
  final bool userPausedIntent;
  final String? errorMessage;

  // ── Position / buffer ──
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final double volume;

  // ── Quality / source ──
  final String streamingQualitySetting;
  /// Variant bitrate chosen for the current track (kbps), or null when playing
  /// the master playlist / a local file.
  final int? streamingTargetKbps;
  /// What Auto would pick right now for the current network (kbps).
  final int? recommendedKbps;
  /// Actual decoded audio bitrate reported by libmpv (kbps), if available.
  final double? decodedAudioBitrateKbps;
  final int? sampleRateHz;
  final int? channels;
  final String playbackSource;
  final String? playbackUrl;

  // ── Network ──
  final String connectionType;
  final double? estimatedThroughputKbps;
  final bool isOnline;

  // ── Queue / caching ──
  final int queueLength;
  final int currentIndex;
  final bool shuffleEnabled;
  final String repeatMode;
  final int activeBackgroundCaches;

  Duration get bufferAhead {
    final ahead = buffered - position;
    return ahead.isNegative ? Duration.zero : ahead;
  }

  /// Flat key/value report for copy-to-clipboard / bug reports.
  String toReportString() {
    String d(Duration v) {
      final m = v.inMinutes;
      final s = v.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return [
      '── Now Playing ──',
      'trackId: ${trackId ?? '—'}',
      'title: ${title ?? '—'}',
      'artist: ${artist ?? '—'}',
      'album: ${album ?? '—'}',
      '',
      '── Playback ──',
      'platformInitialized: $platformInitialized',
      'playing: $playing',
      'buffering: $buffering',
      'resolvingUrl: $resolvingUrl',
      'isTransitioning: $isTransitioning',
      'userPausedIntent: $userPausedIntent',
      'error: ${errorMessage ?? '—'}',
      'position: ${d(position)} / ${d(duration)}',
      'bufferedAhead: ${d(bufferAhead)}',
      'volume: ${(volume * 100).round()}%',
      '',
      '── Quality / Source ──',
      'streamingQualitySetting: $streamingQualitySetting',
      'streamingTargetKbps: ${streamingTargetKbps ?? '— (master/local)'}',
      'recommendedKbps(now): ${recommendedKbps ?? '—'}',
      'decodedAudioBitrateKbps: ${decodedAudioBitrateKbps?.toStringAsFixed(0) ?? '—'}',
      'sampleRate: ${sampleRateHz != null ? '$sampleRateHz Hz' : '—'}',
      'channels: ${channels ?? '—'}',
      'playbackSource: $playbackSource',
      'playbackUrl: ${playbackUrl ?? '—'}',
      '',
      '── Network ──',
      'connectionType: $connectionType',
      'isOnline: $isOnline',
      'estimatedThroughputKbps: ${estimatedThroughputKbps?.toStringAsFixed(0) ?? '— (no sample yet)'}',
      '',
      '── Queue ──',
      'currentIndex: $currentIndex / ${queueLength == 0 ? 0 : queueLength - 1}',
      'queueLength: $queueLength',
      'shuffle: $shuffleEnabled',
      'repeat: $repeatMode',
      'activeBackgroundCaches: $activeBackgroundCaches',
    ].join('\n');
  }
}
