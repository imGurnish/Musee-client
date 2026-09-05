import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CastRemoteDataSource {
  Future<Map<String, dynamic>> createCastSession({String? deviceName});
  Future<Map<String, dynamic>> joinCastSessionByCode(String sessionCode);
  Future<Map<String, dynamic>> getSession(String sessionId);
  Future<void> endCastSession(String sessionId);
  Future<Map<String, dynamic>> getSessionState(String sessionId);
  Future<void> updateSessionState({
    required String sessionId,
    String? currentTrackId,
    String? currentTrackTitle,
    String? currentTrackArtist,
    String? currentTrackAlbum,
    String? currentTrackImageUrl,
    int? currentTrackDurationMs,
    List<String>? queue,
    int? queueIndex,
    int? positionMs,
    bool? isPlaying,
    double? volume,
    bool? shuffle,
    String? repeatMode,
    bool? eqEnabled,
    String? eqPreset,
    List<double>? eqBands,
    int? bassLevel,
    int? surroundLevel,
    bool? crossfadeEnabled,
    bool? normalizeVolume,
  });
  Future<void> broadcastEvent({
    required String sessionId,
    required String event,
    required Map<String, dynamic> payload,
  });
  Stream<Map<String, dynamic>> watchSessionState(String sessionId);
  Stream<Map<String, dynamic>> watchBroadcastEvents(String sessionId);
  Future<Map<String, dynamic>> createDeviceAuthToken({String? deviceName});
  Future<void> approveDeviceAuth(String token);
  Stream<Map<String, dynamic>> watchDeviceAuthToken(String token);
  Future<void> registerReceiver({
    required String sessionId,
    String? deviceName,
  });
  Future<void> unregisterReceiver(String sessionId);
  Future<List<Map<String, dynamic>>> getConnectedReceivers(String sessionId);
  Stream<List<Map<String, dynamic>>> watchConnectedReceivers(String sessionId);
}

class CastRemoteDataSourceImpl implements CastRemoteDataSource {
  final SupabaseClient supabaseClient;
  final Map<String, RealtimeChannel> _activeChannels = {};
  final Set<String> _subscribedChannels = {};
  String? _currentReceiverRecordId;

  CastRemoteDataSourceImpl({required this.supabaseClient});

  String? get _userId => supabaseClient.auth.currentUser?.id;

  static const _sessionCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

  String _generateSessionCode() {
    final rng = Random.secure();
    final letters = List.generate(
      4,
      (_) => _sessionCodeChars[rng.nextInt(_sessionCodeChars.length)],
    ).join();
    final digits = (rng.nextInt(90) + 10).toString();
    return '$letters$digits';
  }

  RealtimeChannel _getOrCreateChannel(String name) {
    if (!_activeChannels.containsKey(name)) {
      _activeChannels[name] = supabaseClient.channel(name);
    }
    return _activeChannels[name]!;
  }

  @override
  Future<Map<String, dynamic>> createCastSession({String? deviceName}) async {
    final code = _generateSessionCode();
    final userId = _userId;

    final sessionRow = await supabaseClient
        .from('cast_sessions')
        .insert({
          if (userId != null) 'owner_id': userId,
          'session_code': code,
          if (deviceName != null) 'device_name': deviceName,
          'status': 'active',
        })
        .select()
        .single();

    final sessionId = sessionRow['id'] as String;

    await supabaseClient.from('cast_session_state').insert({
      'session_id': sessionId,
      'is_playing': false,
      'volume': 1.0,
      'shuffle': false,
      'repeat_mode': 'none',
      'eq_enabled': true,
      'eq_preset': 'normal',
      'eq_bands': [0.0, 0.0, 0.0, 0.0, 0.0],
      'bass_level': 0,
      'surround_level': 0,
      'crossfade_enabled': false,
      'normalize_volume': false,
      'queue': <String>[],
      'queue_index': 0,
      'position_ms': 0,
    });

    return Map<String, dynamic>.from(sessionRow);
  }

  @override
  Future<Map<String, dynamic>> joinCastSessionByCode(String sessionCode) async {
    final row = await supabaseClient
        .from('cast_sessions')
        .select()
        .eq('session_code', sessionCode.toUpperCase().trim())
        .eq('status', 'active')
        .single();

    return Map<String, dynamic>.from(row);
  }

  @override
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final row = await supabaseClient
        .from('cast_sessions')
        .select()
        .eq('id', sessionId)
        .single();

    return Map<String, dynamic>.from(row);
  }

  @override
  Future<void> endCastSession(String sessionId) async {
    await supabaseClient
        .from('cast_sessions')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);

    // Also broadcast session ended to all subscribers
    await broadcastEvent(
      sessionId: sessionId,
      event: 'session_ended',
      payload: {},
    );
  }

  @override
  Future<Map<String, dynamic>> getSessionState(String sessionId) async {
    final row = await supabaseClient
        .from('cast_session_state')
        .select()
        .eq('session_id', sessionId)
        .single();

    return Map<String, dynamic>.from(row);
  }

  @override
  Future<void> updateSessionState({
    required String sessionId,
    String? currentTrackId,
    String? currentTrackTitle,
    String? currentTrackArtist,
    String? currentTrackAlbum,
    String? currentTrackImageUrl,
    int? currentTrackDurationMs,
    List<String>? queue,
    int? queueIndex,
    int? positionMs,
    bool? isPlaying,
    double? volume,
    bool? shuffle,
    String? repeatMode,
    bool? eqEnabled,
    String? eqPreset,
    List<double>? eqBands,
    int? bassLevel,
    int? surroundLevel,
    bool? crossfadeEnabled,
    bool? normalizeVolume,
  }) async {
    final updates = <String, dynamic>{
      'session_id': sessionId,
      'updated_at': DateTime.now().toIso8601String(),
      if (currentTrackId != null) 'current_track_id': currentTrackId,
      if (currentTrackTitle != null) 'current_track_title': currentTrackTitle,
      if (currentTrackArtist != null) 'current_track_artist': currentTrackArtist,
      if (currentTrackAlbum != null) 'current_track_album': currentTrackAlbum,
      if (currentTrackImageUrl != null) 'current_track_image_url': currentTrackImageUrl,
      if (currentTrackDurationMs != null) 'current_track_duration_ms': currentTrackDurationMs,
      if (queue != null) 'queue': queue,
      if (queueIndex != null) 'queue_index': queueIndex,
      if (positionMs != null) 'position_ms': positionMs,
      if (isPlaying != null) 'is_playing': isPlaying,
      if (volume != null) 'volume': volume,
      if (shuffle != null) 'shuffle': shuffle,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (eqEnabled != null) 'eq_enabled': eqEnabled,
      if (eqPreset != null) 'eq_preset': eqPreset,
      if (eqBands != null) 'eq_bands': eqBands,
      if (bassLevel != null) 'bass_level': bassLevel,
      if (surroundLevel != null) 'surround_level': surroundLevel,
      if (crossfadeEnabled != null) 'crossfade_enabled': crossfadeEnabled,
      if (normalizeVolume != null) 'normalize_volume': normalizeVolume,
    };

    try {
      await supabaseClient
          .from('cast_session_state')
          .upsert(updates, onConflict: 'session_id');
    } catch (_) {
      // Fallback in case schema migration has not yet added track metadata columns
      final fallbackUpdates = Map<String, dynamic>.from(updates)
        ..remove('current_track_title')
        ..remove('current_track_artist')
        ..remove('current_track_album')
        ..remove('current_track_image_url')
        ..remove('current_track_duration_ms');
      await supabaseClient
          .from('cast_session_state')
          .upsert(fallbackUpdates, onConflict: 'session_id');
    }
  }

  @override
  Future<void> broadcastEvent({
    required String sessionId,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    final channelName = 'cast_broadcast:$sessionId';
    final channel = _getOrCreateChannel(channelName);
    if (!_subscribedChannels.contains(channelName)) {
      channel.subscribe();
      _subscribedChannels.add(channelName);
    }
    await channel.sendBroadcastMessage(
      event: event,
      payload: payload,
    );
  }

  @override
  Stream<Map<String, dynamic>> watchSessionState(String sessionId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = supabaseClient.channel('session_state:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cast_session_state',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty && !controller.isClosed) {
              controller.add(Map<String, dynamic>.from(record));
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      supabaseClient.removeChannel(channel);
    };

    return controller.stream;
  }

  @override
  Stream<Map<String, dynamic>> watchBroadcastEvents(String sessionId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channelName = 'cast_broadcast:$sessionId';
    final channel = _getOrCreateChannel(channelName);
    channel.onBroadcast(
      event: '*',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(Map<String, dynamic>.from(payload));
        }
      },
    );
    if (!_subscribedChannels.contains(channelName)) {
      channel.subscribe();
      _subscribedChannels.add(channelName);
    }

    controller.onCancel = () {
      supabaseClient.removeChannel(channel);
      _activeChannels.remove(channelName);
      _subscribedChannels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> createDeviceAuthToken({String? deviceName}) async {
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    final row = await supabaseClient
        .from('device_auth_tokens')
        .insert({
          if (deviceName != null) 'device_name': deviceName,
          'status': 'pending',
          'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  @override
  Future<void> approveDeviceAuth(String token) async {
    final userId = _userId;
    await supabaseClient
        .from('device_auth_tokens')
        .update({
          if (userId != null) 'user_id': userId,
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('token', token)
        .eq('status', 'pending');
  }

  @override
  Stream<Map<String, dynamic>> watchDeviceAuthToken(String token) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = supabaseClient.channel('device_auth:$token');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'device_auth_tokens',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'token',
            value: token,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty && !controller.isClosed) {
              controller.add(Map<String, dynamic>.from(record));
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      supabaseClient.removeChannel(channel);
    };

    return controller.stream;
  }

  @override
  Future<void> registerReceiver({
    required String sessionId,
    String? deviceName,
  }) async {
    final effectiveDeviceName = deviceName ?? 'Web Receiver';
    Map<String, dynamic>? row;
    try {
      final res = await supabaseClient.from('cast_session_receivers').insert({
        'session_id': sessionId,
        if (_userId != null) 'user_id': _userId,
        'device_name': effectiveDeviceName,
      }).select().maybeSingle();
      if (res != null) {
        row = Map<String, dynamic>.from(res);
        _currentReceiverRecordId = row['id'] as String?;
      }
    } catch (_) {}

    // Broadcast instant receiver_joined event so controllers see the device in 0ms
    try {
      await broadcastEvent(
        sessionId: sessionId,
        event: 'receiver_joined',
        payload: {
          'id': row?['id'] ?? '',
          'device_name': effectiveDeviceName,
          'session_id': sessionId,
          'joined_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  @override
  Future<void> unregisterReceiver(String sessionId) async {
    try {
      if (_currentReceiverRecordId != null) {
        await supabaseClient
            .from('cast_session_receivers')
            .update({'left_at': DateTime.now().toIso8601String()})
            .eq('id', _currentReceiverRecordId!);
        _currentReceiverRecordId = null;
      } else if (_userId != null) {
        await supabaseClient
            .from('cast_session_receivers')
            .update({'left_at': DateTime.now().toIso8601String()})
            .eq('session_id', sessionId)
            .eq('user_id', _userId as Object);
      }
      await broadcastEvent(
        sessionId: sessionId,
        event: 'receiver_left',
        payload: {'session_id': sessionId},
      );
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getConnectedReceivers(String sessionId) async {
    try {
      final rows = await supabaseClient
          .from('cast_session_receivers')
          .select()
          .eq('session_id', sessionId)
          .isFilter('left_at', null)
          .order('joined_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchConnectedReceivers(String sessionId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    void fetchAndEmit() async {
      final list = await getConnectedReceivers(sessionId);
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    fetchAndEmit();

    final channel = supabaseClient.channel('receivers_watch:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cast_session_receivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (_) => fetchAndEmit(),
        )
        .subscribe();

    controller.onCancel = () {
      supabaseClient.removeChannel(channel);
    };

    return controller.stream;
  }
}
