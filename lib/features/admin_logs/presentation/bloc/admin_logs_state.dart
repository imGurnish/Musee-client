import 'package:equatable/equatable.dart';
import '../../data/models/log_entry_model.dart';

enum AdminLogsStatus { connecting, connected, disconnected, error }

class AdminLogsState extends Equatable {
  final List<LogEntry> logs;
  final AdminLogsStatus status;
  final String searchQuery;
  final Set<String> levelFilters;
  final LogEntry? selectedLog;
  final String? errorMessage;

  const AdminLogsState({
    required this.logs,
    required this.status,
    required this.searchQuery,
    required this.levelFilters,
    this.selectedLog,
    this.errorMessage,
  });

  factory AdminLogsState.initial() {
    return const AdminLogsState(
      logs: [],
      status: AdminLogsStatus.disconnected,
      searchQuery: '',
      levelFilters: {'INFO', 'WARN', 'ERROR', 'DEBUG'},
      selectedLog: null,
      errorMessage: null,
    );
  }

  AdminLogsState copyWith({
    List<LogEntry>? logs,
    AdminLogsStatus? status,
    String? searchQuery,
    Set<String>? levelFilters,
    LogEntry? Function()? selectedLog,
    String? Function()? errorMessage,
  }) {
    return AdminLogsState(
      logs: logs ?? this.logs,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      levelFilters: levelFilters ?? this.levelFilters,
      selectedLog: selectedLog != null ? selectedLog() : this.selectedLog,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  List<LogEntry> get filteredLogs {
    return logs.where((log) {
      if (!levelFilters.contains(log.level)) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return log.message.toLowerCase().contains(query) ||
            log.level.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  @override
  List<Object?> get props => [
        logs,
        status,
        searchQuery,
        levelFilters,
        selectedLog,
        errorMessage,
      ];
}
