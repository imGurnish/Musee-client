/// Cache configuration constants
class CacheConfig {
  CacheConfig._();

  /// Maximum total size for audio cache in bytes (default: 500MB)
  static const int maxAudioCacheSizeBytes = 500 * 1024 * 1024;

  /// Maximum age for cached metadata before considered stale (30 days)
  static const Duration metadataMaxAge = Duration(days: 30);

  /// Maximum age for cached streaming URLs (they may expire)
  static const Duration streamingUrlMaxAge = Duration(hours: 6);

  /// Hive box names
  static const String trackBoxName = 'cached_tracks';
  static const String albumBoxName = 'cached_albums';
}
