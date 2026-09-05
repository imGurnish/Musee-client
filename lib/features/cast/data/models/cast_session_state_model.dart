import 'package:musee/features/cast/domain/entities/cast_session_state.dart';

class CastSessionStateModel extends CastSessionState {
  const CastSessionStateModel({
    required super.sessionId,
    super.currentTrackId,
    super.currentTrackTitle,
    super.currentTrackArtist,
    super.currentTrackAlbum,
    super.currentTrackImageUrl,
    super.currentTrackDurationMs,
    super.queue,
    super.queueIndex,
    super.positionMs,
    super.isPlaying,
    super.volume,
    super.shuffle,
    super.repeatMode,
    super.eqEnabled,
    super.eqPreset,
    super.eqBands,
    super.bassLevel,
    super.surroundLevel,
    super.crossfadeEnabled,
    super.normalizeVolume,
  });

  factory CastSessionStateModel.fromJson(Map<String, dynamic> json) {
    List<double> parseBands(dynamic raw) {
      if (raw is List) return raw.map((e) => (e as num).toDouble()).toList();
      return const [0.0, 0.0, 0.0, 0.0, 0.0];
    }

    List<String> parseQueue(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const [];
    }

    return CastSessionStateModel(
      sessionId: json['session_id'] as String,
      currentTrackId: json['current_track_id'] as String?,
      currentTrackTitle: json['current_track_title'] as String?,
      currentTrackArtist: json['current_track_artist'] as String?,
      currentTrackAlbum: json['current_track_album'] as String?,
      currentTrackImageUrl: json['current_track_image_url'] as String?,
      currentTrackDurationMs: (json['current_track_duration_ms'] as num?)?.toInt(),
      queue: parseQueue(json['queue']),
      queueIndex: json['queue_index'] as int? ?? 0,
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      isPlaying: json['is_playing'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      shuffle: json['shuffle'] as bool? ?? false,
      repeatMode: json['repeat_mode'] as String? ?? 'none',
      eqEnabled: json['eq_enabled'] as bool? ?? true,
      eqPreset: json['eq_preset'] as String? ?? 'normal',
      eqBands: parseBands(json['eq_bands']),
      bassLevel: json['bass_level'] as int? ?? 0,
      surroundLevel: json['surround_level'] as int? ?? 0,
      crossfadeEnabled: json['crossfade_enabled'] as bool? ?? false,
      normalizeVolume: json['normalize_volume'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'current_track_id': currentTrackId,
      'current_track_title': currentTrackTitle,
      'current_track_artist': currentTrackArtist,
      'current_track_album': currentTrackAlbum,
      'current_track_image_url': currentTrackImageUrl,
      'current_track_duration_ms': currentTrackDurationMs,
      'queue': queue,
      'queue_index': queueIndex,
      'position_ms': positionMs,
      'is_playing': isPlaying,
      'volume': volume,
      'shuffle': shuffle,
      'repeat_mode': repeatMode,
      'eq_enabled': eqEnabled,
      'eq_preset': eqPreset,
      'eq_bands': eqBands,
      'bass_level': bassLevel,
      'surround_level': surroundLevel,
      'crossfade_enabled': crossfadeEnabled,
      'normalize_volume': normalizeVolume,
    };
  }
}
