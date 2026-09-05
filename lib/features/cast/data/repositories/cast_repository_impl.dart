import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/cast/data/datasources/cast_remote_data_source.dart';
import 'package:musee/features/cast/data/models/cast_receiver_device_model.dart';
import 'package:musee/features/cast/data/models/cast_session_model.dart';
import 'package:musee/features/cast/data/models/cast_session_state_model.dart';
import 'package:musee/features/cast/data/models/device_auth_token_model.dart';
import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/domain/entities/cast_session_state.dart';
import 'package:musee/features/cast/domain/entities/device_auth_token.dart';
import 'package:musee/features/cast/domain/repository/cast_repository.dart';

class CastRepositoryImpl implements CastRepository {
  final CastRemoteDataSource remoteDataSource;

  const CastRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CastSession>> createCastSession({
    String? deviceName,
  }) async {
    try {
      final raw = await remoteDataSource.createCastSession(
        deviceName: deviceName,
      );
      return right(CastSessionModel.fromJson(raw));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CastSession>> joinCastSessionByCode(
    String sessionCode,
  ) async {
    try {
      final raw = await remoteDataSource.joinCastSessionByCode(sessionCode);
      return right(CastSessionModel.fromJson(raw));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CastSession>> getSession(String sessionId) async {
    try {
      final raw = await remoteDataSource.getSession(sessionId);
      return right(CastSessionModel.fromJson(raw));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> endCastSession(String sessionId) async {
    try {
      await remoteDataSource.endCastSession(sessionId);
      return right(unit);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CastSessionState>> getSessionState(
    String sessionId,
  ) async {
    try {
      final raw = await remoteDataSource.getSessionState(sessionId);
      return right(CastSessionStateModel.fromJson(raw));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      await remoteDataSource.updateSessionState(
        sessionId: sessionId,
        currentTrackId: currentTrackId,
        currentTrackTitle: currentTrackTitle,
        currentTrackArtist: currentTrackArtist,
        currentTrackAlbum: currentTrackAlbum,
        currentTrackImageUrl: currentTrackImageUrl,
        currentTrackDurationMs: currentTrackDurationMs,
        queue: queue,
        queueIndex: queueIndex,
        positionMs: positionMs,
        isPlaying: isPlaying,
        volume: volume,
        shuffle: shuffle,
        repeatMode: repeatMode,
        eqEnabled: eqEnabled,
        eqPreset: eqPreset,
        eqBands: eqBands,
        bassLevel: bassLevel,
        surroundLevel: surroundLevel,
        crossfadeEnabled: crossfadeEnabled,
        normalizeVolume: normalizeVolume,
      );
      return right(unit);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> broadcastEvent({
    required String sessionId,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await remoteDataSource.broadcastEvent(
        sessionId: sessionId,
        event: event,
        payload: payload,
      );
      return right(unit);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Stream<CastSessionState> watchSessionState(String sessionId) {
    return remoteDataSource
        .watchSessionState(sessionId)
        .map((raw) => CastSessionStateModel.fromJson(raw));
  }

  @override
  Stream<Map<String, dynamic>> watchBroadcastEvents(String sessionId) {
    return remoteDataSource.watchBroadcastEvents(sessionId);
  }

  @override
  Future<Either<Failure, DeviceAuthToken>> createDeviceAuthToken({
    String? deviceName,
  }) async {
    try {
      final raw = await remoteDataSource.createDeviceAuthToken(
        deviceName: deviceName,
      );
      return right(DeviceAuthTokenModel.fromJson(raw));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> approveDeviceAuth(String token) async {
    try {
      await remoteDataSource.approveDeviceAuth(token);
      return right(unit);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Stream<DeviceAuthToken> watchDeviceAuthToken(String token) {
    return remoteDataSource
        .watchDeviceAuthToken(token)
        .map((raw) => DeviceAuthTokenModel.fromJson(raw));
  }

  @override
  Future<Either<Failure, Unit>> registerReceiver({
    required String sessionId,
    String? deviceName,
  }) async {
    try {
      await remoteDataSource.registerReceiver(
        sessionId: sessionId,
        deviceName: deviceName,
      );
      return right(unit);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> unregisterReceiver(String sessionId) async {
    try {
      await remoteDataSource.unregisterReceiver(sessionId);
      return right(unit);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CastReceiverDevice>>> getConnectedReceivers(
    String sessionId,
  ) async {
    try {
      final list = await remoteDataSource.getConnectedReceivers(sessionId);
      final devices = list
          .map((m) => CastReceiverDeviceModel.fromJson(m))
          .toList();
      return right(devices);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Stream<List<CastReceiverDevice>> watchConnectedReceivers(String sessionId) {
    return remoteDataSource.watchConnectedReceivers(sessionId).map((list) {
      return list.map((m) => CastReceiverDeviceModel.fromJson(m)).toList();
    });
  }
}
