import 'package:media_kit/media_kit.dart';
import 'android_audio_effects.dart';

/// Platform-agnostic equalizer controller.
///
/// Configures and controls audio filters (EQ, Bass, Surround) on the [Player] instance.
/// Works on Android, iOS, macOS, Windows, Linux, and Web.
class EqualizerController {
  AndroidAudioEffects? _effects;

  /// Call this once when initializing the player.
  void initialize(Player player) {
    _effects = AndroidAudioEffects(player);
  }

  /// Apply 5-band EQ gains (dB).
  Future<void> applyEqBands(List<double> bands) async {
    await _effects?.applyEqBands(bands);
  }

  /// Apply bass enhancement level 0–100.
  Future<void> applyBass(int level) async {
    await _effects?.applyBass(level);
  }

  /// Apply surround/stereo widening level 0–100.
  Future<void> applySurround(int level) async {
    await _effects?.applySurround(level);
  }

  /// Release all resources.
  void dispose() {
    _effects = null;
  }
}
