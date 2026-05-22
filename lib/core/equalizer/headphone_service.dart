import 'dart:async';
import 'package:flutter/foundation.dart';

// headphones_detection is Android-only; guard with a try-catch at runtime.
// We use a conditional import pattern to stay compile-safe on all platforms.
import 'package:musee/core/equalizer/headphone_detection_stub.dart'
    if (dart.library.io) 'package:musee/core/equalizer/headphone_detection_native.dart'
    as hp;

/// Singleton service that exposes the current headphone connection state.
///
/// UI widgets can listen to [isConnectedStream] with a [StreamBuilder] to
/// show/hide the surround sound slider reactively.
class HeadphoneService {
  HeadphoneService._();
  static final instance = HeadphoneService._();

  final _controller = StreamController<bool>.broadcast();
  bool _connected = false;

  /// Current headphone connection state (synchronous).
  bool get isConnected => _connected;

  /// Stream that emits whenever the headphone connection state changes.
  Stream<bool> get isConnectedStream => _controller.stream;

  /// Initialise the service. Call once from [initDependencies].
  Future<void> initialize() async {
    try {
      _connected = await hp.isHeadphonesConnected();
      _controller.add(_connected);

      hp.headphonesStream().listen((connected) {
        if (_connected != connected) {
          _connected = connected;
          _controller.add(_connected);
          if (kDebugMode) {
            debugPrint('[HeadphoneService] Headphones connected: $connected');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HeadphoneService] init error (non-fatal): $e');
      }
      // Default to false — surround slider stays hidden
      _connected = false;
    }
  }

  void dispose() => _controller.close();
}
