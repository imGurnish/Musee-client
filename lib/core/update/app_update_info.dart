class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.isMandatory,
    this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseUrl;
  final bool isMandatory;
  final String? releaseNotes;
}