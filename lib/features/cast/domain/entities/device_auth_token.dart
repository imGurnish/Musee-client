import 'package:equatable/equatable.dart';

class DeviceAuthToken extends Equatable {
  final String token;
  final String? userId;
  final String? deviceName;
  final String status; // pending | approved | expired
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? approvedAt;

  const DeviceAuthToken({
    required this.token,
    this.userId,
    this.deviceName,
    this.status = 'pending',
    required this.createdAt,
    required this.expiresAt,
    this.approvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isExpired => status == 'expired' || DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [token, userId, deviceName, status, createdAt, expiresAt, approvedAt];
}
