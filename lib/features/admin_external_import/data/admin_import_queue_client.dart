import 'package:dio/dio.dart' as dio;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImportJobStatus {
  final String jobId;
  final String type;
  final String sourceId;
  final String status;
  final int progress;
  final String? error;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<String> logs;
  final Map<String, dynamic>? result;

  const ImportJobStatus({
    required this.jobId,
    required this.type,
    required this.sourceId,
    required this.status,
    required this.progress,
    this.error,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.logs = const [],
    this.result,
  });

  bool get isTerminal => status == 'success' || status == 'failed' || status == 'not_found';

  factory ImportJobStatus.fromJson(Map<String, dynamic> json) {
    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final rawLogs = (json['logs'] as List?) ?? const [];
    final logs = rawLogs
        .whereType<Map>()
        .map((entry) => entry['message']?.toString() ?? '')
        .where((message) => message.isNotEmpty)
        .toList();

    return ImportJobStatus(
      jobId: json['jobId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      progress: int.tryParse('${json['progress'] ?? 0}') ?? 0,
      error: json['error']?.toString(),
      createdAt: toDate(json['createdAt']),
      startedAt: toDate(json['startedAt']),
      finishedAt: toDate(json['finishedAt']),
      logs: logs,
      result: json['result'] is Map<String, dynamic>
          ? json['result'] as Map<String, dynamic>
          : null,
    );
  }
}

class AdminImportQueueClient {
  final dio.Dio _dio;
  final SupabaseClient _supabase;

  AdminImportQueueClient({
    required dio.Dio dioClient,
    required SupabaseClient supabase,
  })  : _dio = dioClient,
        _supabase = supabase;

  String get _baseUrl => '${AppSecrets.backendUrl}/api/admin/import';

  Map<String, String> _authHeaders() {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Admin session not found. Please sign in again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<ImportJobStatus> enqueueTrack(String trackId) {
    return _enqueue(type: 'track', sourceId: trackId);
  }

  Future<ImportJobStatus> enqueueAlbum(String albumId) {
    return _enqueue(type: 'album', sourceId: albumId);
  }

  Future<ImportJobStatus> enqueuePlaylist(String playlistId) {
    return _enqueue(type: 'playlist', sourceId: playlistId);
  }

  Future<ImportJobStatus> _enqueue({
    required String type,
    required String sourceId,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/$type/$sourceId',
      options: dio.Options(headers: _authHeaders()),
    );

    if ((response.statusCode ?? 500) < 200 || (response.statusCode ?? 500) > 299) {
      throw Exception('Failed to queue $type import.');
    }

    final payload = response.data as Map<String, dynamic>;
    return ImportJobStatus(
      jobId: payload['jobId']?.toString() ?? '',
      type: payload['type']?.toString() ?? type,
      sourceId: payload['sourceId']?.toString() ?? sourceId,
      status: payload['status']?.toString() ?? 'queued',
      progress: 0,
      createdAt: DateTime.now(),
    );
  }

  Future<ImportJobStatus> getStatus(String jobId) async {
    final response = await _dio.get(
      '$_baseUrl/status/$jobId',
      options: dio.Options(headers: _authHeaders()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch import status for $jobId');
    }

    final payload = response.data as Map<String, dynamic>;
    return ImportJobStatus.fromJson(payload);
  }
}
