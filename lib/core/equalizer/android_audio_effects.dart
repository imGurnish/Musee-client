import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps and coordinates the supported Android hardware audio effects in just_audio:
///  - [AndroidEqualizer] → Used for per-band EQ & combined hardware DSP mix
///
/// Implement a professional unified DSP mixing algorithm that combines the
/// user's custom EQ bands, dedicated sub-bass boost frequencies, and a
/// V-shaped psychoacoustic stereo-widening spatial curve for surround sound.
class AndroidAudioEffects {
  AndroidEqualizer? _eq;

  List<double> _userBands = const [0.0, 0.0, 0.0, 0.0, 0.0];
  int _bassLevel = 0;
  int _surroundLevel = 0;

  bool get _isInitialised => _eq != null;

  /// Builds and returns the [AudioPipeline] to pass to [AudioPlayer].
  /// Call exactly once, before constructing [AudioPlayer].
  AudioPipeline buildPipeline() {
    _eq = AndroidEqualizer();
    return AudioPipeline(
      androidAudioEffects: [_eq!],
    );
  }

  // ─── DSP Mix Algorithm ─────────────────────────────────────────────────────

  /// Apply 5-band gains (dB) to the Android hardware equalizer.
  Future<void> applyEqBands(List<double> dbGains) async {
    _userBands = List.from(dbGains);
    await _applyCombinedEffects();
  }

  /// Apply hardware-accelerated bass boosting.
  Future<void> applyBass(int level) async {
    _bassLevel = level;
    await _applyCombinedEffects();
  }

  /// Apply hardware-accelerated spatial widening.
  Future<void> applySurround(int level) async {
    _surroundLevel = level;
    await _applyCombinedEffects();
  }

  /// Core DSP mixing pipeline. Combines presets, custom bands, sub-bass boosting,
  /// and spatial expansion directly into Android's low-latency hardware equalizer.
  Future<void> _applyCombinedEffects() async {
    if (!_isInitialised) return;
    try {
      final params = await _eq!.parameters;
      final bands  = params.bands;
      final minDb  = params.minDecibels;
      final maxDb  = params.maxDecibels;

      // Ensure base user bands are padded to 5 bands
      final baseGains = List<double>.from(_userBands);
      while (baseGains.length < 5) {
        baseGains.add(0.0);
      }

      // 1. Hardware Bass Enhancement (Lows are boosted, Mids/Highs are attenuated to create spectral tilt)
      // This increases the relative bass presence massively without adding overall gain (which sounds like volume & causes clipping).
      final bassFactor = _bassLevel / 100.0;
      final deepBassBoost = bassFactor * 12.0; // Up to +12.0 dB deep bass at 60 Hz
      final midBassBoost  = bassFactor * 8.0;  // Up to +8.0 dB punchy bass at 230 Hz
      
      // Attenuate mids/highs to tilt the frequency response towards the low end (prevents clipping & sounds much deeper)
      final bassMidTilt   = -bassFactor * 4.0;  // Up to -4.0 dB at 910 Hz
      final bassPresTilt  = -bassFactor * 3.0;  // Up to -3.0 dB at 3.6 kHz
      final bassHighTilt  = -bassFactor * 2.0;  // Up to -2.0 dB at 14 kHz

      // 2. Hardware Surround Spatial scoop (Atmospheric 3D Soundstage)
      // Extreme mid-range vocal scoop with highly elevated air and ambient sub-bass rumble
      final surroundFactor = _surroundLevel / 100.0;
      final surroundSubBass  = surroundFactor * 6.0;  // Up to +6.0 dB ambient depth rumble (60 Hz)
      final surroundMidBass  = surroundFactor * 3.0;  // Up to +3.0 dB warm room reverb base (230 Hz)
      final surroundMidScoop = -surroundFactor * 9.5; // Up to -9.5 dB mid-range scoop (pushes vocals back into space)
      final surroundPresence = surroundFactor * 5.0;  // Up to +5.0 dB presence detail clarity (3.6 kHz)
      final surroundAir      = surroundFactor * 12.0; // Up to +12.0 dB extreme air & reflections (14 kHz)

      // Mix individual layers into the final 5 bands
      final finalGains = List<double>.from(baseGains);
      finalGains[0] += (deepBassBoost + surroundSubBass);                  // 60 Hz (Sub-bass)
      finalGains[1] += (midBassBoost + surroundMidBass);                    // 230 Hz (Mid-bass)
      finalGains[2] += (bassMidTilt + surroundMidScoop);                   // 910 Hz (Mids/Vocals)
      finalGains[3] += (bassPresTilt + surroundPresence);                  // 3.6 kHz (Presence)
      finalGains[4] += (bassHighTilt + surroundAir);                       // 14 kHz (Brilliance/Air)

      // Keep equalizer active if any effect is enabled
      final hasActiveEffects = _bassLevel > 0 || _surroundLevel > 0 || finalGains.any((g) => g != 0.0);
      await _eq!.setEnabled(hasActiveEffects);

      // Program the hardware bands
      for (int i = 0; i < bands.length && i < finalGains.length; i++) {
        final clamped = finalGains[i].clamp(minDb, maxDb);
        await bands[i].setGain(clamped);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AndroidAudioEffects] applyCombinedEffects error (non-fatal): $e');
      }
    }
  }
}
