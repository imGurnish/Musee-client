import 'package:equatable/equatable.dart';

class CastReceiverDevice extends Equatable {
  final String id;
  final String sessionId;
  final String deviceName;
  final DateTime joinedAt;

  const CastReceiverDevice({
    required this.id,
    required this.sessionId,
    required this.deviceName,
    required this.joinedAt,
  });

  @override
  List<Object?> get props => [id, sessionId, deviceName, joinedAt];
}
