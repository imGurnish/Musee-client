import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:musee/core/equalizer/eq_presets.dart';

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

  // ─── Equalizer & Sound ───────────────────────────────────────────────────
  /// Active preset key — one of [kEqPresets] keys or 'custom'.
  final String equalizerPreset;
  /// Per-band dB gains (5 bands). Range: −12.0 to +12.0 per band.
  final List<double> equalizerBands;
  /// Bass enhancement level 0–100.
  final int bassLevel;
  /// Surround/stereo widening level 0–100 (active only when earphones connected).
  final int surroundLevel;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.downloadQuality = DownloadQuality.high,
    this.wifiOnlyDownloads = true,
    this.maxCacheSize = MaxCacheSize.mb500,
    this.autoPlayEnabled = true,
    this.crossfadeEnabled = false,
    this.showExplicitContent = true,
    this.normalizeVolume = false,
    this.equalizerPreset = 'normal',
    this.equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.bassLevel = 0,
    this.surroundLevel = 0,
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
    String? equalizerPreset,
    List<double>? equalizerBands,
    int? bassLevel,
    int? surroundLevel,
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
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      equalizerBands: equalizerBands ?? this.equalizerBands,
      bassLevel: bassLevel ?? this.bassLevel,
      surroundLevel: surroundLevel ?? this.surroundLevel,
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
      'equalizerPreset': equalizerPreset,
      'equalizerBands': equalizerBands,
      'bassLevel': bassLevel,
      'surroundLevel': surroundLevel,
    };
  }

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    // Safely parse equalizerBands — stored as List<dynamic> in JSON
    List<double> parseBands(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return const [0.0, 0.0, 0.0, 0.0, 0.0];
    }

    final preset = json['equalizerPreset'] as String? ?? 'normal';
    return SettingsState(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      downloadQuality: DownloadQuality.values[json['downloadQuality'] as int? ?? 2],
      wifiOnlyDownloads: json['wifiOnlyDownloads'] as bool? ?? true,
      maxCacheSize: MaxCacheSize.values[json['maxCacheSize'] as int? ?? 2],
      autoPlayEnabled: json['autoPlayEnabled'] as bool? ?? true,
      crossfadeEnabled: json['crossfadeEnabled'] as bool? ?? false,
      showExplicitContent: json['showExplicitContent'] as bool? ?? true,
      normalizeVolume: json['normalizeVolume'] as bool? ?? false,
      equalizerPreset: preset,
      equalizerBands: parseBands(json['equalizerBands']) ,
      bassLevel: (json['bassLevel'] as int?) ?? 0,
      surroundLevel: (json['surroundLevel'] as int?) ?? 0,
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
    equalizerPreset,
    equalizerBands,
    bassLevel,
    surroundLevel,
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
