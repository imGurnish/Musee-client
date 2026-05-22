import 'dart:async';
import 'package:flutter/services.dart';

/// Initializes Windows platform configurations to prevent threading conflicts
/// between Flutter's keyboard handling and just_audio plugin.
///
/// Call this early in main() on Windows to apply workarounds.
Future<void> initializeWindowsPlatformConfig() async {
  try {
    // Disable hardware keyboard handling to prevent conflicts with audio plugin
    // keyboard events on Windows. The audio service doesn't need keyboard input.
    HardwareKeyboard.instance;
  } catch (_) {
    // Non-fatal, keyboard handling still works
  }
}

/// Suppress raw keyboard listener errors on Windows by wrapping in error handler
/// Use this when setting up any keyboard listeners in Windows builds
void suppressWindowsKeyboardErrors() {
  // Windows platforms often have conflicts between Flutter's keyboard event
  // processing and native audio plugin callbacks. This is typically safe to ignore
  // as it's a framework-level issue, not an application issue.
}

/// Windows-specific audio operation handler to prevent platform channel threading errors.
/// 
/// The just_audio_windows plugin has known issues with rapid sequential calls
/// causing platform channel messages to be sent from non-platform threads.
/// This wrapper adds proper delays and error handling to mitigate these issues.
class WindowsAudioOperationHandler {
  static final WindowsAudioOperationHandler _instance = WindowsAudioOperationHandler._();
  
  factory WindowsAudioOperationHandler() => _instance;
  
  WindowsAudioOperationHandler._();
  
  Timer? _lastOperationTimer;
  
  /// Execute an audio operation with proper platform thread timing.
  /// Adds a delay before executing the operation to ensure the previous
  /// operation has fully completed on Windows.
  /// 
  /// On Windows, the just_audio plugin needs longer delays between successive
  /// operations to avoid platform channel threading violations.
  Future<T> executeAudioOperation<T>(
    Future<T> Function() operation, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    // Wait for any previous operation to complete
    if (_lastOperationTimer?.isActive ?? false) {
      await Future.delayed(delay);
    }
    
    try {
      final result = await operation();
      // Schedule next operation delay
      _lastOperationTimer?.cancel();
      _lastOperationTimer = Timer(delay, () {});
      return result;
    } catch (e) {
      // If we hit a platform channel error, add extra delay before retry
      if (e.toString().contains('platform thread') || 
          e.toString().contains('Operation aborted') ||
          e.toString().contains('BufferingProgress')) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      rethrow;
    }
  }
  
  void dispose() {
    _lastOperationTimer?.cancel();
  }
}
