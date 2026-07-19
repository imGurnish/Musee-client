import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/log_entry_model.dart';

import 'admin_logs_helper_stub.dart'
    if (dart.library.html) 'admin_logs_web_helper.dart'
    if (dart.library.io) 'admin_logs_vm_helper.dart';

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

  @override
  Stream<LogEntry> streamLogs() {
    return getLogsStream(
      dio: dio,
      baseUrl: baseUrl,
      supabaseClient: supabaseClient,
    );
  }
}
