import 'dart:async';
import 'dart:io';
import 'package:headphones_detection/headphones_detection.dart';

/// Native implementation using the headphones_detection package.
/// Only compilable on dart:io platforms. Guards against MissingPluginException
/// on non-mobile (Desktop/Windows) platforms.
 
Future<bool> isHeadphonesConnected() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    // On Windows/macOS/Linux, default to true so the user can interact
    // with the Surround Sound slider in UI-only mode.
    return true;
  }
  try {
    return await HeadphonesDetection.isHeadphonesConnected();
  } catch (_) {
    return false;
  }
}

Stream<bool> headphonesStream() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const Stream<bool>.empty();
  }
  return HeadphonesDetection.headphonesStream;
}
