import 'package:musee/features/cast/domain/entities/cast_receiver_device.dart';

class CastReceiverDeviceModel extends CastReceiverDevice {
  const CastReceiverDeviceModel({
    required super.id,
    required super.sessionId,
    required super.deviceName,
    required super.joinedAt,
  });

  factory CastReceiverDeviceModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return CastReceiverDeviceModel(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? 'Web Receiver',
      joinedAt: parseDate(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'device_name': deviceName,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
