/// Structured logging service for the Musee app.
/// Provides consistent logging with context and proper formatting.

import 'package:flutter/foundation.dart';

/// Log levels
enum LogLevel { debug, info, warning, error }

/// Singleton logger service for structured logging.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  /// Minimum log level to output (configurable)
  LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Log a debug message (development only)
  void debug(String message, {Map<String, dynamic>? context, String? tag}) {
    _log(LogLevel.debug, message, context: context, tag: tag);
  }

  /// Log an info message
  void info(String message, {Map<String, dynamic>? context, String? tag}) {
    _log(LogLevel.info, message, context: context, tag: tag);
  }

  /// Log a warning message
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? tag,
  }) {
    _log(
      LogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      tag: tag,
    );
  }

  /// Log an error message
  void error(
    String message, {
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? tag,
  }) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      tag: tag,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? tag,
  }) {
    if (level.index < minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';

    final buffer = StringBuffer();
    buffer.writeln('$timestamp $levelStr $tagStr$message');

    if (context != null && context.isNotEmpty) {
      buffer.writeln('  Context: $context');
    }

    if (error != null) {
      buffer.writeln('  Error: $error');
    }

    if (stackTrace != null && level == LogLevel.error) {
      buffer.writeln('  Stack: $stackTrace');
    }

    // In debug mode, print to console
    // In release mode, this could be sent to a logging service (Sentry, etc.)
    if (kDebugMode) {
      // Use different print levels for visibility
      switch (level) {
        case LogLevel.debug:
          debugPrint(buffer.toString());
        case LogLevel.info:
          debugPrint(buffer.toString());
        case LogLevel.warning:
          debugPrint('⚠️ ${buffer.toString()}');
        case LogLevel.error:
          debugPrint('❌ ${buffer.toString()}');
      }
    }

    // TODO: In production, send to remote logging service
    // Example: Sentry.captureMessage(message, level: level);
  }
}

/// Global logger instance for easy access
final appLogger = AppLogger();
