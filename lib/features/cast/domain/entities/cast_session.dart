import 'package:equatable/equatable.dart';

class CastSession extends Equatable {
  final String id;
  final String? ownerId;
  final String? sessionCode;
  final String? deviceName;
  final String status; // active | ended
  final DateTime createdAt;
  final DateTime? endedAt;

  const CastSession({
    required this.id,
    this.ownerId,
    this.sessionCode,
    this.deviceName,
    this.status = 'active',
    required this.createdAt,
    this.endedAt,
  });

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [id, ownerId, sessionCode, deviceName, status, createdAt, endedAt];
}
