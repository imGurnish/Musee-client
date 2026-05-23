import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musee/core/update/app_update_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _repoOwner = 'imGurnish';
  static const String _repoName = 'Musee-client';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
  static const String _releasePageBase =
      'https://github.com/$_repoOwner/$_repoName/releases/tag';

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || kDebugMode) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _normalizeVersion(packageInfo.version);
    if (currentVersion.isEmpty) {
      return null;
    }

    final response = await _client.get(
      Uri.parse(_latestReleaseApi),
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Musee-client',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final latestTag = _normalizeVersion(decoded['tag_name'] as String? ?? '');
    if (latestTag.isEmpty) {
      return null;
    }

    final comparison = _compareVersions(currentVersion, latestTag);
    if (comparison >= 0) {
      return null;
    }

    final releasePageUrl =
        decoded['html_url'] as String? ?? '$_releasePageBase/v$latestTag';
    final downloadUrl = _resolveDownloadUrl(decoded, releasePageUrl);
    final releaseNotes = decoded['body'] as String?;

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestTag,
      downloadUrl: downloadUrl,
      releaseUrl: releasePageUrl,
      isMandatory: _isMajorUpgrade(currentVersion, latestTag),
      releaseNotes: releaseNotes,
    );
  }

  String _resolveDownloadUrl(
    Map<String, dynamic> release,
    String releasePageUrl,
  ) {
    final assets = release['assets'];
    if (assets is List) {
      final platformHint = _platformAssetHint();
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) {
          continue;
        }

        final assetName = (asset['name'] as String? ?? '').toLowerCase();
        final assetUrl = asset['browser_download_url'] as String?;
        if (assetUrl == null || assetUrl.isEmpty) {
          continue;
        }

        if (platformHint != null && assetName.contains(platformHint)) {
          return assetUrl;
        }
      }

      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) {
          continue;
        }

        final assetUrl = asset['browser_download_url'] as String?;
        if (assetUrl != null && assetUrl.isNotEmpty) {
          return assetUrl;
        }
      }
    }

    return releasePageUrl;
  }

  String? _platformAssetHint() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '.apk';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return '.zip';
      case TargetPlatform.iOS:
        return '.ipa';
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  bool _isMajorUpgrade(String currentVersion, String latestVersion) {
    final current = _versionParts(currentVersion);
    final latest = _versionParts(latestVersion);
    return latest.first > current.first;
  }

  int _compareVersions(String currentVersion, String latestVersion) {
    final current = _versionParts(currentVersion);
    final latest = _versionParts(latestVersion);

    for (var i = 0; i < 3; i++) {
      final currentValue = current[i];
      final latestValue = latest[i];
      if (latestValue != currentValue) {
        return latestValue.compareTo(currentValue);
      }
    }

    return 0;
  }

  List<int> _versionParts(String version) {
    final cleaned = _normalizeVersion(version);
    final segments = cleaned.split('.');
    return List<int>.generate(3, (index) {
      if (index >= segments.length) {
        return 0;
      }

      return int.tryParse(segments[index]) ?? 0;
    });
  }

  String _normalizeVersion(String version) {
    return version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
  }
}