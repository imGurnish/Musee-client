import 'package:dio/dio.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PlayerDataSource {
  Future<List<String>> getQueueIds();
  Future<List<Map<String, dynamic>>> getQueueExpanded();
  Future<void> addToQueue(
    List<String> trackIds, {
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? metadataList,
  });
  Future<void> removeFromQueue(String trackId);
  Future<List<String>> reorderQueue(int from, int to);
  Future<void> clearQueue();
  Future<List<Map<String, dynamic>>> playFrom(
    String trackId, {
    bool expand = false,
    Map<String, dynamic>? metadata,
  });
}

class PlayerDataSourceImpl implements PlayerDataSource {
  final Dio _dio;
  final SupabaseClient _supabase;
  PlayerDataSourceImpl(this._dio, this._supabase);

  Map<String, String> _headers() {
    final token = _supabase.auth.currentSession?.accessToken;
    final base = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    return token == null ? base : {...base, 'Authorization': 'Bearer $token'};
  }

  @override
  Future<List<String>> getQueueIds() async {
    final res = await _dio.get(
      '${AppSecrets.backendUrl}/api/user/queue',
      options: Options(headers: _headers()),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
    return items.map((e) => e.toString()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getQueueExpanded() async {
    final res = await _dio.get(
      '${AppSecrets.backendUrl}/api/user/queue',
      queryParameters: {'expand': '1'},
      options: Options(headers: _headers()),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  @override
  Future<void> addToQueue(
    List<String> trackIds, {
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? metadataList,
  }) async {
    if (trackIds.isEmpty) return;
    final Map<String, dynamic> body;
    if (trackIds.length == 1) {
      body = {'track_id': trackIds.first};
      if (metadata != null) {
        body['metadata'] = metadata;
      }
    } else {
      body = {'track_ids': trackIds};
      if (metadataList != null) {
        body['metadata_list'] = metadataList;
      }
    }
    await _dio.post(
      '${AppSecrets.backendUrl}/api/user/queue/add',
      data: body,
      options: Options(headers: _headers()),
    );
  }

  @override
  Future<void> removeFromQueue(String trackId) async {
    await _dio.delete(
      '${AppSecrets.backendUrl}/api/user/queue/$trackId',
      options: Options(headers: _headers()),
    );
  }

  @override
  Future<List<String>> reorderQueue(int from, int to) async {
    final res = await _dio.post(
      '${AppSecrets.backendUrl}/api/user/queue/reorder',
      data: {'fromIndex': from, 'toIndex': to},
      options: Options(headers: _headers()),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
    return items.map((e) => e.toString()).toList();
  }

  @override
  Future<void> clearQueue() async {
    await _dio.post(
      '${AppSecrets.backendUrl}/api/user/queue/clear',
      options: Options(headers: _headers()),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> playFrom(
    String trackId, {
    bool expand = false,
    Map<String, dynamic>? metadata,
  }) async {
    final Map<String, dynamic> body = {'track_id': trackId};
    if (metadata != null) {
      body['metadata'] = metadata;
    }
    final res = await _dio.post(
      '${AppSecrets.backendUrl}/api/user/queue/play',
      data: body,
      queryParameters: expand ? {'expand': '1'} : null,
      options: Options(headers: _headers()),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
