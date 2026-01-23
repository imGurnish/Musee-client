/// Comprehensive error type hierarchy for the Musee app.
/// Provides user-friendly error messages and structured error information
/// for logging and debugging.

import 'package:dio/dio.dart' as dio;
import 'dart:io';

/// Base class for all app errors with user-friendly messaging.
sealed class AppError {
  /// User-friendly error message to display in UI
  String get userMessage;

  /// Technical details for logging (not shown to users)
  String get technicalDetails;

  /// Whether this error can potentially be resolved by retrying
  bool get isRetryable;

  /// Error code for tracking/analytics
  String get errorCode;
}

/// Network-related errors (no connection, timeout, etc.)
class NetworkError extends AppError {
  final String? _message;
  final Object? originalError;

  NetworkError({String? message, this.originalError}) : _message = message;

  @override
  String get userMessage =>
      _message ?? 'Unable to connect. Please check your internet connection.';

  @override
  String get technicalDetails =>
      'NetworkError: ${originalError?.toString() ?? 'Unknown network issue'}';

  @override
  bool get isRetryable => true;

  @override
  String get errorCode => 'NETWORK_ERROR';

  factory NetworkError.noConnection() => NetworkError(
    message: 'No internet connection. Please check your network settings.',
  );

  factory NetworkError.timeout() =>
      NetworkError(message: 'Request timed out. Please try again.');

  factory NetworkError.fromException(Object error) {
    if (error is SocketException) {
      return NetworkError.noConnection();
    }
    if (error is dio.DioException) {
      switch (error.type) {
        case dio.DioExceptionType.connectionTimeout:
        case dio.DioExceptionType.sendTimeout:
        case dio.DioExceptionType.receiveTimeout:
          return NetworkError.timeout();
        case dio.DioExceptionType.connectionError:
          return NetworkError.noConnection();
        default:
          return NetworkError(
            message: 'Connection error. Please try again.',
            originalError: error,
          );
      }
    }
    return NetworkError(originalError: error);
  }
}

/// Server/API errors (4xx, 5xx responses)
class ApiError extends AppError {
  final int? statusCode;
  final String? serverMessage;
  final Object? originalError;

  ApiError({this.statusCode, this.serverMessage, this.originalError});

  @override
  String get userMessage {
    if (statusCode == 401) return 'Please sign in to continue.';
    if (statusCode == 403) return 'You don\'t have permission to access this.';
    if (statusCode == 404) return 'The requested content was not found.';
    if (statusCode == 429) return 'Too many requests. Please wait a moment.';
    if (statusCode != null && statusCode! >= 500) {
      return 'Server error. Please try again later.';
    }
    return serverMessage ?? 'Something went wrong. Please try again.';
  }

  @override
  String get technicalDetails =>
      'ApiError: status=$statusCode, message=$serverMessage, error=$originalError';

  @override
  bool get isRetryable =>
      statusCode == null || statusCode! >= 500 || statusCode == 429;

  @override
  String get errorCode => 'API_ERROR_${statusCode ?? 'UNKNOWN'}';

  factory ApiError.fromDioError(dio.DioException error) {
    final response = error.response;
    String? serverMessage;

    if (response?.data is Map) {
      serverMessage =
          response!.data['message']?.toString() ??
          response.data['error']?.toString();
    }

    return ApiError(
      statusCode: response?.statusCode,
      serverMessage: serverMessage,
      originalError: error,
    );
  }

  factory ApiError.unauthorized() => ApiError(statusCode: 401);
  factory ApiError.forbidden() => ApiError(statusCode: 403);
  factory ApiError.notFound() => ApiError(statusCode: 404);
}

/// Playback-related errors
class PlaybackError extends AppError {
  final String? _message;
  final PlaybackErrorType type;
  final Object? originalError;

  PlaybackError({String? message, required this.type, this.originalError})
    : _message = message;

  @override
  String get userMessage {
    return _message ??
        switch (type) {
          PlaybackErrorType.trackNotFound => 'Track not found or unavailable.',
          PlaybackErrorType.streamingFailed =>
            'Unable to play. Please try again.',
          PlaybackErrorType.formatNotSupported => 'Audio format not supported.',
          PlaybackErrorType.permissionDenied => 'Playback permission denied.',
          PlaybackErrorType.unknown => 'Playback error. Please try again.',
        };
  }

  @override
  String get technicalDetails =>
      'PlaybackError: type=$type, error=$originalError';

  @override
  bool get isRetryable =>
      type == PlaybackErrorType.streamingFailed ||
      type == PlaybackErrorType.unknown;

  @override
  String get errorCode => 'PLAYBACK_${type.name.toUpperCase()}';
}

enum PlaybackErrorType {
  trackNotFound,
  streamingFailed,
  formatNotSupported,
  permissionDenied,
  unknown,
}

/// Cache-related errors
class CacheError extends AppError {
  final String? _message;
  final CacheErrorType type;
  final Object? originalError;

  CacheError({String? message, required this.type, this.originalError})
    : _message = message;

  @override
  String get userMessage {
    return _message ??
        switch (type) {
          CacheErrorType.notFound => 'Content not available offline.',
          CacheErrorType.corrupted => 'Cached data is corrupted. Refreshing...',
          CacheErrorType.storageFull => 'Storage is full. Free up some space.',
          CacheErrorType.writeFailed => 'Failed to save to cache.',
          CacheErrorType.readFailed => 'Failed to read from cache.',
        };
  }

  @override
  String get technicalDetails => 'CacheError: type=$type, error=$originalError';

  @override
  bool get isRetryable =>
      type == CacheErrorType.writeFailed || type == CacheErrorType.readFailed;

  @override
  String get errorCode => 'CACHE_${type.name.toUpperCase()}';
}

enum CacheErrorType {
  notFound,
  corrupted,
  storageFull,
  writeFailed,
  readFailed,
}

/// Validation errors (invalid input, etc.)
class ValidationError extends AppError {
  final String field;
  final String _message;

  ValidationError({required this.field, required String message})
    : _message = message;

  @override
  String get userMessage => _message;

  @override
  String get technicalDetails =>
      'ValidationError: field=$field, message=$_message';

  @override
  bool get isRetryable => false;

  @override
  String get errorCode => 'VALIDATION_ERROR';
}

/// Extension to convert exceptions to AppError
extension ExceptionToAppError on Object {
  AppError toAppError() {
    if (this is AppError) return this as AppError;
    if (this is dio.DioException) {
      final dioError = this as dio.DioException;
      if (dioError.type == dio.DioExceptionType.connectionError ||
          dioError.type == dio.DioExceptionType.connectionTimeout) {
        return NetworkError.fromException(this);
      }
      return ApiError.fromDioError(dioError);
    }
    if (this is SocketException) {
      return NetworkError.noConnection();
    }
    return NetworkError(originalError: this);
  }
}
