import 'package:equatable/equatable.dart';
import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';
import 'package:musee/features/cast/domain/entities/cast_session_state.dart';

abstract class CastEvent extends Equatable {
  const CastEvent();
  @override
  List<Object?> get props => [];
}

/// Controller: start a new cast session (phone becomes controller)
class StartCastSessionEvent extends CastEvent {
  final String? deviceName;
  const StartCastSessionEvent({this.deviceName});
  @override
  List<Object?> get props => [deviceName];
}

/// Join an existing session by code
class JoinCastSessionByCodeEvent extends CastEvent {
  final String sessionCode;
  const JoinCastSessionByCodeEvent({required this.sessionCode});
  @override
  List<Object?> get props => [sessionCode];
}

/// Stop casting and end the session
class EndCastSessionEvent extends CastEvent {
  const EndCastSessionEvent();
}

/// Receiver: start a new session as receiver (TV/car displays QR code & session code)
class StartReceiverSessionEvent extends CastEvent {
  final String? deviceName;
  const StartReceiverSessionEvent({this.deviceName});
  @override
  List<Object?> get props => [deviceName];
}

/// Receiver: join an existing session as a receiver (TV/car)
class JoinAsReceiverEvent extends CastEvent {
  final String sessionId;
  final String? deviceName;
  const JoinAsReceiverEvent({required this.sessionId, this.deviceName});
  @override
  List<Object?> get props => [sessionId, deviceName];
}

/// Internal/Realtime: update connected receivers list
class UpdateConnectedReceiversEvent extends CastEvent {
  final List<CastReceiverDevice> receivers;
  const UpdateConnectedReceiversEvent({required this.receivers});
  @override
  List<Object?> get props => [receivers];
}

/// Internal/Realtime: update remote session state
class UpdateCastRemoteStateEvent extends CastEvent {
  final CastSessionState remoteState;
  const UpdateCastRemoteStateEvent({required this.remoteState});
  @override
  List<Object?> get props => [remoteState];
}

/// Controller pushes playback / EQ update
class SyncStateToReceiverEvent extends CastEvent {
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

  const SyncStateToReceiverEvent({
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

  @override
  List<Object?> get props => [
    currentTrackId, currentTrackTitle, currentTrackArtist, currentTrackAlbum,
    currentTrackImageUrl, currentTrackDurationMs,
    queue, queueIndex, positionMs, isPlaying, volume,
    shuffle, repeatMode, eqEnabled, eqPreset, eqBands,
    bassLevel, surroundLevel, crossfadeEnabled, normalizeVolume,
  ];
}

/// Broadcast a fast ephemeral event (position tick)
class BroadcastPositionTickEvent extends CastEvent {
  final int positionMs;
  const BroadcastPositionTickEvent({required this.positionMs});
  @override
  List<Object?> get props => [positionMs];
}

/// Controller remote control actions
class RemotePlayEvent extends CastEvent {
  const RemotePlayEvent();
}

class RemotePauseEvent extends CastEvent {
  const RemotePauseEvent();
}

class RemoteSeekEvent extends CastEvent {
  final int positionMs;
  const RemoteSeekEvent({required this.positionMs});
  @override
  List<Object?> get props => [positionMs];
}

class RemoteNextEvent extends CastEvent {
  const RemoteNextEvent();
}

class RemotePreviousEvent extends CastEvent {
  const RemotePreviousEvent();
}

class RemoteSetVolumeEvent extends CastEvent {
  final double volume;
  const RemoteSetVolumeEvent({required this.volume});
  @override
  List<Object?> get props => [volume];
}

/// Remote EQ changes
class RemoteSetEqBandsEvent extends CastEvent {
  final List<double> bands;
  const RemoteSetEqBandsEvent({required this.bands});
  @override
  List<Object?> get props => [bands];
}

class RemoteSetBassEvent extends CastEvent {
  final int level;
  const RemoteSetBassEvent({required this.level});
  @override
  List<Object?> get props => [level];
}

class RemoteSetSurroundEvent extends CastEvent {
  final int level;
  const RemoteSetSurroundEvent({required this.level});
  @override
  List<Object?> get props => [level];
}

class RemoteToggleEqEvent extends CastEvent {
  final bool enabled;
  const RemoteToggleEqEvent({required this.enabled});
  @override
  List<Object?> get props => [enabled];
}

/// Phone approves a TV's QR sign-in token
class ApproveDeviceAuthEvent extends CastEvent {
  final String token;
  const ApproveDeviceAuthEvent({required this.token});
  @override
  List<Object?> get props => [token];
}

/// TV/Car: create a device auth token and show QR
class CreateDeviceAuthTokenEvent extends CastEvent {
  final String? deviceName;
  const CreateDeviceAuthTokenEvent({this.deviceName});
  @override
  List<Object?> get props => [deviceName];
}
