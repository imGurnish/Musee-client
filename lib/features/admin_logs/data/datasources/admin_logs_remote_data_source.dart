import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/log_entry_model.dart';

abstract class AdminLogsRemoteDataSource {
  Stream<LogEntry> streamLogs();
}

class AdminLogsRemoteDataSourceImpl implements AdminLogsRemoteDataSource {
  final Dio dio;
  final String baseUrl;
  final SupabaseClient supabaseClient;

  AdminLogsRemoteDataSourceImpl({
    required this.dio,
    required this.baseUrl,
    required this.supabaseClient,
  });

  Map<String, String> _headers() {
    final token = supabaseClient.auth.currentSession?.accessToken;
    final base = {
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
    return token == null ? base : {...base, 'Authorization': 'Bearer $token'};
  }

  @override
  Stream<LogEntry> streamLogs() async* {
    final response = await dio.get<ResponseBody>(
      '$baseUrl/api/admin/logs/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: _headers(),
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) {
      throw Exception('Failed to establish log stream: response body is null');
    }

    // Decode bytes to string lines
    final lineStream = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (line.startsWith('data: ')) {
        final jsonString = line.substring(6).trim();
        if (jsonString.isNotEmpty) {
          try {
            final Map<String, dynamic> data = json.decode(jsonString);
            yield LogEntry.fromJson(data);
          } catch (e) {
            yield LogEntry(
              timestamp: DateTime.now(),
              level: 'ERROR',
              message: 'Failed to parse stream event: $jsonString. Error: $e',
            );
          }
        }
      }
    }
  }
}
