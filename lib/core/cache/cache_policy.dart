import 'package:musee/core/cache/cache_config.dart';
import 'package:musee/core/cache/models/cache_entity_type.dart';

class CachePolicy {
  CachePolicy._();

  static Duration ttlFor(CacheEntityType entityType) {
    switch (entityType) {
      case CacheEntityType.track:
        return CacheConfig.metadataMaxAge;
      case CacheEntityType.album:
      case CacheEntityType.playlist:
      case CacheEntityType.artist:
        return CacheConfig.detailPayloadMaxAge;
    }
  }

  static DateTime computeExpiry(
    CacheEntityType entityType,
    DateTime fetchedAt,
  ) {
    return fetchedAt.add(ttlFor(entityType));
  }

  static bool isStale({
    required DateTime expiresAt,
    required DateTime now,
    Duration staleWindow = const Duration(minutes: 15),
  }) {
    return now.isAfter(expiresAt.subtract(staleWindow));
  }

  static bool isExpired({required DateTime expiresAt, required DateTime now}) {
    return !now.isBefore(expiresAt);
  }
}
