import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Wraps and coordinates the media_kit audio filters to implement:
///  - 5-band equalizer
///  - Bass boosting
///  - Surround widening
///
/// Implements a unified DSP mixing algorithm that combines the
/// user's custom EQ bands, dedicated sub-bass boost frequencies, and a
/// V-shaped psychoacoustic stereo-widening spatial curve for surround sound.
class AndroidAudioEffects {
  final Player _player;

  List<double> _userBands = const [0.0, 0.0, 0.0, 0.0, 0.0];
  int _bassLevel = 0;
  int _surroundLevel = 0;

  AndroidAudioEffects(this._player);

  // ─── DSP Mix Algorithm ─────────────────────────────────────────────────────

  /// Apply 5-band gains (dB) to the equalizer.
  Future<void> applyEqBands(List<double> dbGains) async {
    _userBands = List.from(dbGains);
    await _applyCombinedEffects();
  }

  /// Apply bass boosting.
  Future<void> applyBass(int level) async {
    _bassLevel = level;
    await _applyCombinedEffects();
  }

  /// Apply surround/stereo widening.
  Future<void> applySurround(int level) async {
    _surroundLevel = level;
    await _applyCombinedEffects();
  }

  /// Core DSP mixing pipeline. Combines presets, custom bands, sub-bass boosting,
  /// and spatial expansion directly into MPV's audio filters.
  Future<void> _applyCombinedEffects() async {
    try {
      // Ensure base user bands are padded to 5 bands
      final baseGains = List<double>.from(_userBands);
      while (baseGains.length < 5) {
        baseGains.add(0.0);
      }

      // 1. Bass Enhancement (Lows are boosted, Mids/Highs are attenuated to create spectral tilt)
      final bassFactor = _bassLevel / 100.0;
      final deepBassBoost = bassFactor * 12.0; // Up to +12.0 dB deep bass at 60 Hz
      final midBassBoost  = bassFactor * 8.0;  // Up to +8.0 dB punchy bass at 230 Hz
      
      // Attenuate mids/highs to tilt the frequency response towards the low end (prevents clipping & sounds much deeper)
      final bassMidTilt   = -bassFactor * 4.0;  // Up to -4.0 dB at 910 Hz
      final bassPresTilt  = -bassFactor * 3.0;  // Up to -3.0 dB at 3.6 kHz
      final bassHighTilt  = -bassFactor * 2.0;  // Up to -2.0 dB at 14 kHz

      // 2. Surround Spatial scoop (Atmospheric 3D Soundstage)
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

      // Clamp gains to standard equalizer range of -15.0 to 15.0 dB
      final clampedGains = finalGains.map((g) => g.clamp(-15.0, 15.0)).toList();

      // Construct libmpv equalizer audio filter string using the lavfi wrapper.
      // Correct parameter names: width_type (not t), width (not w), g for gain.
      // Each band uses Q=0.7 for a musically natural bandwidth overlap.
      // Wrapping in lavfi= is required for FFmpeg filter graph syntax in libmpv.
      final bands = [
        'equalizer=f=60:width_type=q:width=0.7:g=${clampedGains[0].toStringAsFixed(2)}',
        'equalizer=f=230:width_type=q:width=0.7:g=${clampedGains[1].toStringAsFixed(2)}',
        'equalizer=f=910:width_type=q:width=0.7:g=${clampedGains[2].toStringAsFixed(2)}',
        'equalizer=f=3600:width_type=q:width=0.7:g=${clampedGains[3].toStringAsFixed(2)}',
        'equalizer=f=14000:width_type=q:width=0.7:g=${clampedGains[4].toStringAsFixed(2)}',
      ];
      final filterString = 'lavfi=[${bands.join(',')}]';

      if (!kIsWeb && _player.platform is NativePlayer) {
        await (_player.platform as dynamic).setProperty('af', filterString);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AndroidAudioEffects] applyCombinedEffects error (non-fatal): $e');
      }
    }
  }
}
