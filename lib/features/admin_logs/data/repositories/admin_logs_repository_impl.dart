import '../../domain/repository/admin_logs_repository.dart';
import '../datasources/admin_logs_remote_data_source.dart';
import '../models/log_entry_model.dart';

class AdminLogsRepositoryImpl implements AdminLogsRepository {
  final AdminLogsRemoteDataSource remoteDataSource;

  AdminLogsRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<LogEntry> streamLogs() {
    return remoteDataSource.streamLogs();
  }
}
