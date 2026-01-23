/// User-friendly error display widgets for consistent error presentation.
/// Shows errors as snackbars, dialogs, or inline banners without raw exception details.
library;

import 'package:flutter/material.dart';
import 'app_errors.dart';

/// Displays errors as a Material snackbar with optional retry action.
class ErrorSnackbar {
  ErrorSnackbar._();

  /// Show an error snackbar from an AppError
  static void show(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.userMessage),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: error.isRetryable && onRetry != null
            ? SnackBarAction(label: 'Retry', onPressed: onRetry)
            : null,
      ),
    );
  }

  /// Show a simple error message
  static void showMessage(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(label: 'Retry', onPressed: onRetry)
            : null,
      ),
    );
  }

  /// Show a network error with offline suggestion
  static void showNetworkError(BuildContext context, {VoidCallback? onRetry}) {
    show(context, NetworkError.noConnection(), onRetry: onRetry);
  }
}

/// Full-page error view with icon, message, and retry button.
class ErrorView extends StatelessWidget {
  final AppError? error;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  factory ErrorView.network({VoidCallback? onRetry}) => ErrorView(
    error: NetworkError.noConnection(),
    onRetry: onRetry,
    icon: Icons.wifi_off,
  );

  factory ErrorView.notFound({String? message}) => ErrorView(
    error: ApiError.notFound(),
    message: message,
    icon: Icons.search_off,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage =
        message ?? error?.userMessage ?? 'Something went wrong';
    final canRetry = (error?.isRetryable ?? true) && onRetry != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (canRetry) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error banner for non-blocking error display.
class InlineErrorBanner extends StatelessWidget {
  final AppError? error;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const InlineErrorBanner({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage = message ?? error?.userMessage ?? 'An error occurred';
    final canRetry = (error?.isRetryable ?? true) && onRetry != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (canRetry)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Mixin for handling errors in StatefulWidgets
mixin ErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  AppError? _error;
  bool get hasError => _error != null;
  AppError? get currentError => _error;

  void setError(Object error) {
    setState(() {
      _error = error.toAppError();
    });
  }

  void clearError() {
    setState(() {
      _error = null;
    });
  }

  /// Show error as snackbar
  void showErrorSnackbar(Object error, {VoidCallback? onRetry}) {
    final appError = error.toAppError();
    if (mounted) {
      ErrorSnackbar.show(context, appError, onRetry: onRetry);
    }
  }
}
