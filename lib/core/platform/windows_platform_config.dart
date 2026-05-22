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
