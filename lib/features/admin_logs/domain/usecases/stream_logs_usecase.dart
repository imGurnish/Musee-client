import '../../data/models/log_entry_model.dart';
import '../repository/admin_logs_repository.dart';

class StreamLogsUseCase {
  final AdminLogsRepository repository;

  StreamLogsUseCase({required this.repository});

  Stream<LogEntry> call() {
    return repository.streamLogs();
  }
}
