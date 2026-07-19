import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/log_entry_model.dart';

Stream<LogEntry> getLogsStream({
  required Dio dio,
  required String baseUrl,
  required SupabaseClient supabaseClient,
}) {
  throw UnsupportedError('Cannot create logs stream without platform helper.');
}
