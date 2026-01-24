import 'package:equatable/equatable.dart';

/// Represents a device in the sync network
class SyncDevice extends Equatable {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final DateTime discoveredAt;
  final bool isHost;
  final double? latitude;
  final double? longitude;
  final int? signalStrength; // WiFi signal strength (-100 to 0 dBm)

  const SyncDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    required this.discoveredAt,
    this.isHost = false,
    this.latitude,
    this.longitude,
    this.signalStrength,
  });

  /// Create a copy of this device with modifications
  SyncDevice copyWith({
    String? deviceId,
    String? deviceName,
    String? ipAddress,
    int? port,
    DateTime? discoveredAt,
    bool? isHost,
    double? latitude,
    double? longitude,
    int? signalStrength,
  }) {
    return SyncDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      isHost: isHost ?? this.isHost,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ipAddress': ipAddress,
      'port': port,
      'discoveredAt': discoveredAt.toIso8601String(),
      'isHost': isHost,
      'latitude': latitude,
      'longitude': longitude,
      'signalStrength': signalStrength,
    };
  }

  /// Create from JSON
  factory SyncDevice.fromJson(Map<String, dynamic> json) {
    return SyncDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      discoveredAt: DateTime.parse(json['discoveredAt'] as String),
      isHost: json['isHost'] as bool? ?? false,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      signalStrength: json['signalStrength'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    deviceId,
    deviceName,
    ipAddress,
    port,
    discoveredAt,
    isHost,
    latitude,
    longitude,
    signalStrength,
  ];
}
