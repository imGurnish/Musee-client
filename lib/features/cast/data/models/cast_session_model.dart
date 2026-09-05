import 'package:musee/features/cast/domain/entities/cast_session.dart';

class CastSessionModel extends CastSession {
  const CastSessionModel({
    required super.id,
    super.ownerId,
    super.sessionCode,
    super.deviceName,
    super.status,
    required super.createdAt,
    super.endedAt,
  });

  factory CastSessionModel.fromJson(Map<String, dynamic> json) {
    return CastSessionModel(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String?,
      sessionCode: json['session_code'] as String?,
      deviceName: json['device_name'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'session_code': sessionCode,
      'device_name': deviceName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    };
  }
}
