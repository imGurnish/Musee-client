import 'package:equatable/equatable.dart';
import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';
import 'package:musee/features/cast/domain/entities/cast_session.dart';
import 'package:musee/features/cast/domain/entities/cast_session_state.dart';
import 'package:musee/features/cast/domain/entities/device_auth_token.dart';

enum CastRole { none, controller, receiver }

abstract class CastState extends Equatable {
  const CastState();
  @override
  List<Object?> get props => [];
}

/// No cast session active
class CastIdle extends CastState {
  const CastIdle();
}

/// Loading/connecting
class CastLoading extends CastState {
  const CastLoading();
}

/// Active cast session — either as controller or receiver
class CastActive extends CastState {
  final CastSession session;
  final CastSessionState? remoteState;
  final CastRole role;
  final List<CastReceiverDevice> receivers;

  const CastActive({
    required this.session,
    this.remoteState,
    required this.role,
    this.receivers = const [],
  });

  bool get isController => role == CastRole.controller;
  bool get isReceiver => role == CastRole.receiver;

  CastActive copyWith({
    CastSession? session,
    CastSessionState? remoteState,
    CastRole? role,
    List<CastReceiverDevice>? receivers,
  }) {
    return CastActive(
      session: session ?? this.session,
      remoteState: remoteState ?? this.remoteState,
      role: role ?? this.role,
      receivers: receivers ?? this.receivers,
    );
  }

  @override
  List<Object?> get props => [session, remoteState, role, receivers];
}

/// TV/Car waiting for QR to be scanned and approved
class CastAwaitingDeviceAuth extends CastState {
  final DeviceAuthToken authToken;
  const CastAwaitingDeviceAuth({required this.authToken});
  @override
  List<Object?> get props => [authToken];
}

/// Error state
class CastError extends CastState {
  final String message;
  const CastError({required this.message});
  @override
  List<Object?> get props => [message];
}
