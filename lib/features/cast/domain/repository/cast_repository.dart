import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/domain/entities/cast_session_state.dart';
import 'package:musee/features/cast/domain/entities/device_auth_token.dart';

abstract class CastRepository {
  // --- Session management ---
  Future<Either<Failure, CastSession>> createCastSession({String? deviceName});
  Future<Either<Failure, CastSession>> joinCastSessionByCode(String sessionCode);
  Future<Either<Failure, CastSession>> getSession(String sessionId);
  Future<Either<Failure, Unit>> endCastSession(String sessionId);
  Future<Either<Failure, CastSessionState>> getSessionState(String sessionId);

  // --- State sync ---
  Future<Either<Failure, Unit>> updateSessionState({
    required String sessionId,
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
  });

  /// Broadcast a fast ephemeral event (no DB write).
  Future<Either<Failure, Unit>> broadcastEvent({
    required String sessionId,
    required String event,
    required Map<String, dynamic> payload,
  });

  // --- Realtime subscriptions ---
  Stream<CastSessionState> watchSessionState(String sessionId);
  Stream<Map<String, dynamic>> watchBroadcastEvents(String sessionId);

  // --- Device Auth (QR sign-in) ---
  Future<Either<Failure, DeviceAuthToken>> createDeviceAuthToken({String? deviceName});
  Future<Either<Failure, Unit>> approveDeviceAuth(String token);
  Stream<DeviceAuthToken> watchDeviceAuthToken(String token);

  // --- Receivers ---
  Future<Either<Failure, Unit>> registerReceiver({
    required String sessionId,
    String? deviceName,
  });
  Future<Either<Failure, Unit>> unregisterReceiver(String sessionId);
  Future<Either<Failure, List<CastReceiverDevice>>> getConnectedReceivers(String sessionId);
  Stream<List<CastReceiverDevice>> watchConnectedReceivers(String sessionId);
}
