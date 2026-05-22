import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'android_audio_effects.dart';

/// Platform-agnostic equalizer controller.
///
/// On Android: delegates to [AndroidAudioEffects] (real hardware DSP).
/// On Windows / Web / other: all calls are silent no-ops.
///
/// Usage:
/// ```dart
/// final controller = EqualizerController();
/// final pipeline = controller.buildAndroidPipeline(); // null on non-Android
/// final player = AudioPlayer(audioPipeline: pipeline ?? AudioPipeline());
/// await controller.applyEqBands([7, 5, 0, -1, -1]);
/// await controller.applyBass(60);
/// await controller.applySurround(40);
/// controller.dispose();
/// ```
class EqualizerController {
  AndroidAudioEffects? _androidEffects;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call this once before constructing [AudioPlayer].
  /// Returns a configured [AudioPipeline] on Android, null elsewhere.
  AudioPipeline? buildAndroidPipeline() {
    if (!_isAndroid) return null;
    _androidEffects = AndroidAudioEffects();
    return _androidEffects!.buildPipeline();
  }

  /// Apply 5-band EQ gains (dB). No-op on non-Android.
  Future<void> applyEqBands(List<double> bands) async {
    await _androidEffects?.applyEqBands(bands);
  }

  /// Apply bass enhancement level 0–100. No-op on non-Android.
  Future<void> applyBass(int level) async {
    await _androidEffects?.applyBass(level);
  }

  /// Apply surround/stereo widening level 0–100. No-op on non-Android.
  Future<void> applySurround(int level) async {
    await _androidEffects?.applySurround(level);
  }

  /// Release all resources. Safe to call on all platforms.
  /// Audio effects are lifecycle-managed by the AudioPlayer.
  void dispose() {
    _androidEffects = null;
  }
}
