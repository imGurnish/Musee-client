import '../../data/models/log_entry_model.dart';

abstract class AdminLogsRepository {
  Stream<LogEntry> streamLogs();
}
