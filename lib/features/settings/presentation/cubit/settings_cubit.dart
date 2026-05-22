import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:musee/core/equalizer/eq_presets.dart';
import 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setThemeMode(ThemeMode mode) {
    emit(state.copyWith(themeMode: mode));
  }

  void setDownloadQuality(DownloadQuality quality) {
    emit(state.copyWith(downloadQuality: quality));
  }

  void setWifiOnlyDownloads(bool value) {
    emit(state.copyWith(wifiOnlyDownloads: value));
  }

  void setMaxCacheSize(MaxCacheSize size) {
    emit(state.copyWith(maxCacheSize: size));
  }

  void setAutoPlay(bool value) {
    emit(state.copyWith(autoPlayEnabled: value));
  }

  void setCrossfade(bool value) {
    emit(state.copyWith(crossfadeEnabled: value));
  }

  void setShowExplicitContent(bool value) {
    emit(state.copyWith(showExplicitContent: value));
  }

  void setNormalizeVolume(bool value) {
    emit(state.copyWith(normalizeVolume: value));
  }

  // ─── Equalizer & Sound ────────────────────────────────────────────────────────

  /// Switch to a named preset — updates both the preset key and the band gains.
  void setEqualizerPreset(String preset) {
    final bands = kEqPresets[preset] ?? List<double>.filled(5, 0.0);
    emit(state.copyWith(equalizerPreset: preset, equalizerBands: bands));
  }

  /// Update band gains directly (moves preset to 'custom').
  void setEqualizerBands(List<double> bands) {
    emit(state.copyWith(equalizerPreset: 'custom', equalizerBands: bands));
  }

  /// Set bass enhancement level 0–100.
  void setBassLevel(int level) {
    emit(state.copyWith(bassLevel: level.clamp(0, 100)));
  }

  /// Set surround/stereo widening level 0–100.
  void setSurroundLevel(int level) {
    emit(state.copyWith(surroundLevel: level.clamp(0, 100)));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    try {
      return SettingsState.fromJson(json);
    } catch (_) {
      return const SettingsState();
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    return state.toJson();
  }
}
