import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/stream_logs_usecase.dart';
import 'admin_logs_state.dart';
import '../../data/models/log_entry_model.dart';

class AdminLogsCubit extends Cubit<AdminLogsState> {
  final StreamLogsUseCase _streamLogsUseCase;
  StreamSubscription<LogEntry>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;

  AdminLogsCubit({required StreamLogsUseCase streamLogsUseCase})
      : _streamLogsUseCase = streamLogsUseCase,
        super(AdminLogsState.initial());

  void startStreaming() {
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _connect();
  }

  void _connect() {
    if (_subscription != null) {
      return;
    }

    emit(state.copyWith(
      status: AdminLogsStatus.connecting,
      errorMessage: () => null,
    ));

    try {
      _subscription = _streamLogsUseCase().listen(
        (logEntry) {
          _reconnectAttempts = 0; // Reset attempts on successful event
          final updatedLogs = List<LogEntry>.from(state.logs)..add(logEntry);
          
          // Cap UI log list at 1000 items to prevent client-side memory leakage
          if (updatedLogs.length > 1000) {
            updatedLogs.removeAt(0);
          }

          emit(state.copyWith(
            logs: updatedLogs,
            status: AdminLogsStatus.connected,
          ));
        },
        onError: (error) {
          emit(state.copyWith(
            status: AdminLogsStatus.error,
            errorMessage: () => error.toString(),
          ));
          _handleDisconnect();
        },
        onDone: () {
          emit(state.copyWith(status: AdminLogsStatus.disconnected));
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      emit(state.copyWith(
        status: AdminLogsStatus.error,
        errorMessage: () => e.toString(),
      ));
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;

    if (!_shouldReconnect) return;

    // Exponential backoff: 1s, 2s, 4s, 8s, max 16s
    final delaySeconds = _reconnectAttempts < 5 ? (1 << _reconnectAttempts) : 16;
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect) {
        _connect();
      }
    });
  }

  void stopStreaming() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    emit(state.copyWith(status: AdminLogsStatus.disconnected));
  }

  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void toggleLevelFilter(String level) {
    final updatedFilters = Set<String>.from(state.levelFilters);
    if (updatedFilters.contains(level)) {
      updatedFilters.remove(level);
    } else {
      updatedFilters.add(level);
    }
    emit(state.copyWith(levelFilters: updatedFilters));
  }

  void selectLog(LogEntry? log) {
    emit(state.copyWith(selectedLog: () => log));
  }

  void clearDisplay() {
    emit(state.copyWith(
      logs: [],
      selectedLog: () => null,
    ));
  }

  @override
  Future<void> close() {
    stopStreaming();
    return super.close();
  }
}
