// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/log_entry_model.dart';

Stream<LogEntry> getLogsStream({
  required Dio dio,
  required String baseUrl,
  required SupabaseClient supabaseClient,
}) {
  final controller = StreamController<LogEntry>();
  final token = supabaseClient.auth.currentSession?.accessToken;
  final url = '$baseUrl/api/admin/logs/stream?token=${Uri.encodeComponent(token ?? "")}';

  final eventSource = html.EventSource(url);

  eventSource.onMessage.listen((event) {
    final line = event.data?.toString() ?? '';
    if (line.isNotEmpty) {
      try {
        final Map<String, dynamic> data = json.decode(line);
        controller.add(LogEntry.fromJson(data));
      } catch (e) {
        controller.add(
          LogEntry(
            timestamp: DateTime.now(),
            level: 'ERROR',
            message: 'Failed to parse stream event: $line. Error: $e',
          ),
        );
      }
    }
  });

  eventSource.onError.listen((event) {
    controller.addError(Exception('EventSource connection error'));
  });

  controller.onCancel = () {
    eventSource.close();
  };

  return controller.stream;
}
