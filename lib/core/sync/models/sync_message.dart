import 'package:equatable/equatable.dart';

/// Type of synchronization message
enum SyncMessageType {
  /// Device discovery message
  deviceDiscovery,

  /// Request to join sync session
  joinRequest,

  /// Approval to join session
  joinApproved,

  /// Rejection of join request
  joinRejected,

  /// Playback command (play, pause, seek)
  playbackCommand,

  /// Current playback state from host
  playbackState,

  /// Audio sync signal with timestamp and position
  syncSignal,

  /// Drift correction data
  driftCorrection,

  /// Heartbeat to keep connection alive
  heartbeat,

  /// Request to disconnect
  disconnect,
}

/// Base class for sync messages
class SyncMessage extends Equatable {
  final SyncMessageType type;
  final String senderId;
  final String sessionId;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const SyncMessage({
    required this.type,
    required this.senderId,
    required this.sessionId,
    required this.timestamp,
    required this.payload,
  });

  /// Convert to JSON for network transmission
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'senderId': senderId,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  /// Create from JSON
  factory SyncMessage.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String? ?? 'heartbeat';

    // Convert snake_case to camelCase for matching
    final normalizedType = _snakeToCamel(typeString);

    final type = SyncMessageType.values.firstWhere(
      (e) => e.toString().split('.').last == normalizedType,
      orElse: () => SyncMessageType.heartbeat,
    );

    // Handle messages that use deviceId instead of senderId (like join_request)
    final senderId =
        json['senderId'] as String? ?? json['deviceId'] as String? ?? '';
    final sessionId = json['sessionId'] as String? ?? '';
    final timestampStr = json['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.tryParse(timestampStr) ?? DateTime.now()
        : DateTime.now();

    // For join_request, populate payload from root fields
    Map<String, dynamic> payload =
        json['payload'] as Map<String, dynamic>? ?? {};
    if (typeString == 'join_request' && payload.isEmpty) {
      payload = {
        'deviceId': json['deviceId'],
        'deviceName': json['deviceName'],
      };
    }

    return SyncMessage(
      type: type,
      senderId: senderId,
      sessionId: sessionId,
      timestamp: timestamp,
      payload: payload,
    );
  }

  /// Convert snake_case to camelCase
  static String _snakeToCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
            .join();
  }

  @override
  List<Object?> get props => [type, senderId, sessionId, timestamp, payload];
}

/// Playback command message
class PlaybackCommandMessage extends SyncMessage {
  final String command; // 'play', 'pause', 'seek'
  final Duration? seekPosition;
  final String? trackId;

  PlaybackCommandMessage({
    required String senderId,
    required String sessionId,
    required this.command,
    this.seekPosition,
    this.trackId,
  }) : super(
         type: SyncMessageType.playbackCommand,
         senderId: senderId,
         sessionId: sessionId,
         timestamp: DateTime.now(),
         payload: {
           'command': command,
           'seekPosition': seekPosition?.inMilliseconds,
           'trackId': trackId,
         },
       );
}

/// Playback state message
class PlaybackStateMessage extends SyncMessage {
  final bool isPlaying;
  final String? currentTrackId;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackAlbum;
  final String? trackImageUrl;
  final Duration position;
  final Duration duration;

  PlaybackStateMessage({
    required String senderId,
    required String sessionId,
    required this.isPlaying,
    this.currentTrackId,
    this.trackTitle,
    this.trackArtist,
    this.trackAlbum,
    this.trackImageUrl,
    required this.position,
    required this.duration,
  }) : super(
         type: SyncMessageType.playbackState,
         senderId: senderId,
         sessionId: sessionId,
         timestamp: DateTime.now(),
         payload: {
           'isPlaying': isPlaying,
           'currentTrackId': currentTrackId,
           'trackTitle': trackTitle,
           'trackArtist': trackArtist,
           'trackAlbum': trackAlbum,
           'trackImageUrl': trackImageUrl,
           'position': position.inMilliseconds,
           'duration': duration.inMilliseconds,
         },
       );
}

/// Sync signal with drift information
class SyncSignalMessage extends SyncMessage {
  final Duration hostPosition;
  final int hostNtpTimestamp; // NTP timestamp in milliseconds
  final Duration clientPosition;
  final int clientNtpTimestamp;

  SyncSignalMessage({
    required String senderId,
    required String sessionId,
    required this.hostPosition,
    required this.hostNtpTimestamp,
    required this.clientPosition,
    required this.clientNtpTimestamp,
  }) : super(
         type: SyncMessageType.syncSignal,
         senderId: senderId,
         sessionId: sessionId,
         timestamp: DateTime.now(),
         payload: {
           'hostPosition': hostPosition.inMilliseconds,
           'hostNtpTimestamp': hostNtpTimestamp,
           'clientPosition': clientPosition.inMilliseconds,
           'clientNtpTimestamp': clientNtpTimestamp,
         },
       );
}

/// Drift correction message
class DriftCorrectionMessage extends SyncMessage {
  final Duration correctionDelta; // How much to adjust
  final DriftCorrectionStrategy strategy;

  DriftCorrectionMessage({
    required String senderId,
    required String sessionId,
    required this.correctionDelta,
    required this.strategy,
  }) : super(
         type: SyncMessageType.driftCorrection,
         senderId: senderId,
         sessionId: sessionId,
         timestamp: DateTime.now(),
         payload: {
           'correctionDelta': correctionDelta.inMilliseconds,
           'strategy': strategy.toString().split('.').last,
         },
       );
}

enum DriftCorrectionStrategy {
  /// Gradually adjust playback speed
  gradualSpeedAdjustment,

  /// Seek to correct position
  seek,

  /// Minor frame-by-frame adjustment
  microAdjustment,
}
