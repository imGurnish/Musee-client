/// Cache configuration constants
class CacheConfig {
  CacheConfig._();

  /// Maximum total size for audio cache in bytes (default: 500MB)
  static const int maxAudioCacheSizeBytes = 500 * 1024 * 1024;

  /// Maximum age for cached metadata before considered stale (30 days)
  static const Duration metadataMaxAge = Duration(days: 30);

  /// Maximum age for cached album/playlist detail payloads.
  static const Duration detailPayloadMaxAge = Duration(hours: 6);

  /// Maximum age for cached streaming URLs before refresh.
  static const Duration streamingUrlMaxAge = Duration(minutes: 20);

  /// Hive box names
  static const String trackBoxName = 'cached_tracks';
  static const String albumBoxName = 'cached_albums';
  static const String mediaDetailBoxName = 'cached_media_details';

  /// Box for centralized per-record cache freshness/sync metadata.
  static const String mediaMetaBoxName = 'media_cache_meta';
}
