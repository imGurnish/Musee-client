import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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
