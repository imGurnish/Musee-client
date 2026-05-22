import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum DownloadQuality { low, medium, high }

enum MaxCacheSize { mb100, mb250, mb500, gb1 }

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final DownloadQuality downloadQuality;
  final bool wifiOnlyDownloads;
  final MaxCacheSize maxCacheSize;
  final bool autoPlayEnabled;
  final bool crossfadeEnabled;
  final bool showExplicitContent;
  final bool normalizeVolume;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.downloadQuality = DownloadQuality.high,
    this.wifiOnlyDownloads = true,
    this.maxCacheSize = MaxCacheSize.mb500,
    this.autoPlayEnabled = true,
    this.crossfadeEnabled = false,
    this.showExplicitContent = true,
    this.normalizeVolume = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    DownloadQuality? downloadQuality,
    bool? wifiOnlyDownloads,
    MaxCacheSize? maxCacheSize,
    bool? autoPlayEnabled,
    bool? crossfadeEnabled,
    bool? showExplicitContent,
    bool? normalizeVolume,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      autoPlayEnabled: autoPlayEnabled ?? this.autoPlayEnabled,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      showExplicitContent: showExplicitContent ?? this.showExplicitContent,
      normalizeVolume: normalizeVolume ?? this.normalizeVolume,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'downloadQuality': downloadQuality.index,
      'wifiOnlyDownloads': wifiOnlyDownloads,
      'maxCacheSize': maxCacheSize.index,
      'autoPlayEnabled': autoPlayEnabled,
      'crossfadeEnabled': crossfadeEnabled,
      'showExplicitContent': showExplicitContent,
      'normalizeVolume': normalizeVolume,
    };
  }

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      downloadQuality: DownloadQuality.values[json['downloadQuality'] as int? ?? 2],
      wifiOnlyDownloads: json['wifiOnlyDownloads'] as bool? ?? true,
      maxCacheSize: MaxCacheSize.values[json['maxCacheSize'] as int? ?? 2],
      autoPlayEnabled: json['autoPlayEnabled'] as bool? ?? true,
      crossfadeEnabled: json['crossfadeEnabled'] as bool? ?? false,
      showExplicitContent: json['showExplicitContent'] as bool? ?? true,
      normalizeVolume: json['normalizeVolume'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    downloadQuality,
    wifiOnlyDownloads,
    maxCacheSize,
    autoPlayEnabled,
    crossfadeEnabled,
    showExplicitContent,
    normalizeVolume,
  ];
}

extension DownloadQualityLabel on DownloadQuality {
  String get label {
    switch (this) {
      case DownloadQuality.low:
        return 'Low (saves data)';
      case DownloadQuality.medium:
        return 'Medium';
      case DownloadQuality.high:
        return 'High (best quality)';
    }
  }

  String get shortLabel {
    switch (this) {
      case DownloadQuality.low:
        return 'Low';
      case DownloadQuality.medium:
        return 'Medium';
      case DownloadQuality.high:
        return 'High';
    }
  }
}

extension MaxCacheSizeLabel on MaxCacheSize {
  String get label {
    switch (this) {
      case MaxCacheSize.mb100:
        return '100 MB';
      case MaxCacheSize.mb250:
        return '250 MB';
      case MaxCacheSize.mb500:
        return '500 MB';
      case MaxCacheSize.gb1:
        return '1 GB';
    }
  }

  int get bytes {
    switch (this) {
      case MaxCacheSize.mb100:
        return 100 * 1024 * 1024;
      case MaxCacheSize.mb250:
        return 250 * 1024 * 1024;
      case MaxCacheSize.mb500:
        return 500 * 1024 * 1024;
      case MaxCacheSize.gb1:
        return 1024 * 1024 * 1024;
    }
  }
}
