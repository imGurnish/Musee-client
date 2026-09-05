import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:musee/features/cast/data/models/cast_receiver_device_model.dart';
import 'package:musee/features/cast/data/models/cast_session_model.dart';
import 'package:musee/features/cast/data/models/cast_session_state_model.dart';
import 'package:musee/features/cast/data/models/device_auth_token_model.dart';

void main() {
  group('CastSessionModel', () {
    test('parses complete json correctly', () {
      final json = {
        'id': 'session-123',
        'owner_id': 'user-456',
        'session_code': 'ABCD12',
        'device_name': 'Living Room TV',
        'status': 'active',
        'created_at': '2026-09-05T10:00:00.000Z',
        'ended_at': null,
      };

      final model = CastSessionModel.fromJson(json);
      expect(model.id, 'session-123');
      expect(model.ownerId, 'user-456');
      expect(model.sessionCode, 'ABCD12');
      expect(model.deviceName, 'Living Room TV');
      expect(model.isActive, isTrue);
      expect(model.endedAt, isNull);
    });

    test('handles null owner_id gracefully (unauthenticated receiver)', () {
      final json = {
        'id': 'session-789',
        'owner_id': null,
        'session_code': 'WXYZ99',
        'device_name': 'Chromecast',
        'status': 'active',
        'created_at': '2026-09-05T10:00:00.000Z',
      };

      final model = CastSessionModel.fromJson(json);
      expect(model.id, 'session-789');
      expect(model.ownerId, isNull);
      expect(model.sessionCode, 'WXYZ99');
    });

    test('toJson serializes correctly', () {
      final model = CastSessionModel(
        id: 's-1',
        sessionCode: 'ABCD12',
        createdAt: DateTime.parse('2026-09-05T10:00:00.000Z'),
      );
      final json = model.toJson();
      expect(json['id'], 's-1');
      expect(json['session_code'], 'ABCD12');
      expect(json['created_at'], '2026-09-05T10:00:00.000Z');
    });
  });

  group('CastSessionStateModel', () {
    test('parses numeric and list types accurately from Map', () {
      final json = {
        'session_id': 'sess-1',
        'current_track_id': 'trk-100',
        'current_track_title': 'Song 1',
        'current_track_artist': 'Artist 1',
        'current_track_album': 'Album 1',
        'current_track_image_url': 'https://example.com/art.jpg',
        'current_track_duration_ms': 180000,
        'queue': ['trk-100', 'trk-101'],
        'queue_index': 0,
        'position_ms': 54000,
        'is_playing': true,
        'volume': 0.85,
        'shuffle': false,
        'repeat_mode': 'all',
        'eq_enabled': true,
        'eq_preset': 'rock',
        'eq_bands': [1.0, 2.0, 0.0, -1.0, 3.0],
        'bass_level': 4,
        'surround_level': 2,
        'crossfade_enabled': true,
        'normalize_volume': true,
      };

      final model = CastSessionStateModel.fromJson(json);
      expect(model.sessionId, 'sess-1');
      expect(model.currentTrackTitle, 'Song 1');
      expect(model.currentTrackDurationMs, 180000);
      expect(model.queue, ['trk-100', 'trk-101']);
      expect(model.positionMs, 54000);
      expect(model.isPlaying, isTrue);
      expect(model.volume, 0.85);
      expect(model.eqBands, [1.0, 2.0, 0.0, -1.0, 3.0]);
      expect(model.bassLevel, 4);
      expect(model.surroundLevel, 2);
    });

    test('safely parses JSON string encoded queue and eqBands', () {
      final json = {
        'session_id': 'sess-2',
        'queue': jsonEncode(['trk-A', 'trk-B']),
        'eq_bands': jsonEncode([0.5, -0.5, 1.2, 0.0, -1.0]),
        'current_track_duration_ms': 210000.0, // num float instead of int
        'position_ms': 15000.0,
        'queue_index': 1.0,
      };

      final model = CastSessionStateModel.fromJson(json);
      expect(model.queue, ['trk-A', 'trk-B']);
      expect(model.eqBands, [0.5, -0.5, 1.2, 0.0, -1.0]);
      expect(model.currentTrackDurationMs, 210000);
      expect(model.positionMs, 15000);
      expect(model.queueIndex, 1);
    });

    test('toJson serializes correctly', () {
      final model = CastSessionStateModel(
        sessionId: 'sess-test',
        currentTrackTitle: 'Test Song',
        queue: const ['1', '2'],
        eqBands: const [0.0, 1.0, 2.0, 3.0, 4.0],
      );
      final json = model.toJson();
      expect(json['session_id'], 'sess-test');
      expect(json['current_track_title'], 'Test Song');
      expect(json['queue'], ['1', '2']);
      expect(json['eq_bands'], [0.0, 1.0, 2.0, 3.0, 4.0]);
    });
  });

  group('CastReceiverDeviceModel', () {
    test('parses json correctly and provides fallback defaults', () {
      final json = {
        'id': 'rec-1',
        'session_id': 'sess-1',
        'device_name': 'Living Room Apple TV',
        'joined_at': '2026-09-05T10:05:00.000Z',
      };

      final model = CastReceiverDeviceModel.fromJson(json);
      expect(model.id, 'rec-1');
      expect(model.sessionId, 'sess-1');
      expect(model.deviceName, 'Living Room Apple TV');
      expect(model.joinedAt, DateTime.parse('2026-09-05T10:05:00.000Z'));
    });
  });

  group('DeviceAuthTokenModel', () {
    test('parses valid token model json', () {
      final json = {
        'token': 'tok-abc',
        'user_id': 'user-123',
        'device_name': 'Samsung Smart TV',
        'status': 'approved',
        'created_at': '2026-09-05T10:00:00.000Z',
        'expires_at': '2026-09-05T10:05:00.000Z',
        'approved_at': '2026-09-05T10:01:00.000Z',
      };

      final model = DeviceAuthTokenModel.fromJson(json);
      expect(model.token, 'tok-abc');
      expect(model.isApproved, isTrue);
      expect(model.userId, 'user-123');
      expect(model.deviceName, 'Samsung Smart TV');
    });

    test('handles fallback dates gracefully on malformed strings', () {
      final json = {
        'token': 'tok-fallback',
        'created_at': 'invalid-date',
        'expires_at': 'invalid-date',
      };

      final model = DeviceAuthTokenModel.fromJson(json);
      expect(model.token, 'tok-fallback');
      expect(model.status, 'pending');
      expect(model.createdAt, isA<DateTime>());
      expect(model.expiresAt, isA<DateTime>());
    });
  });
}
