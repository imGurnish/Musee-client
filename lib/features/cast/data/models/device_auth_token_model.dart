import 'package:musee/features/cast/domain/entities/device_auth_token.dart';

class DeviceAuthTokenModel extends DeviceAuthToken {
  const DeviceAuthTokenModel({
    required super.token,
    super.userId,
    super.deviceName,
    super.status,
    required super.createdAt,
    required super.expiresAt,
    super.approvedAt,
  });

  factory DeviceAuthTokenModel.fromJson(Map<String, dynamic> json) {
    return DeviceAuthTokenModel(
      token: json['token'] as String,
      userId: json['user_id'] as String?,
      deviceName: json['device_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user_id': userId,
      'device_name': deviceName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}
